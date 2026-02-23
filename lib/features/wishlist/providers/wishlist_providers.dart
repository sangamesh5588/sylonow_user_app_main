import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sylonow_user/features/address/providers/address_providers.dart';
import 'package:sylonow_user/features/auth/providers/auth_providers.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';
import 'package:sylonow_user/features/wishlist/models/wishlist_model.dart';
import 'package:sylonow_user/features/wishlist/repositories/wishlist_repository.dart';

part 'wishlist_providers.g.dart';

@riverpod
Future<List<WishlistWithService>> userWishlist(UserWishlistRef ref) async {
  final currentUser = ref.watch(currentUserProvider);
  final selectedAddress = ref.watch(selectedAddressProvider);
  if (currentUser == null) {
    return [];
  }

  final repository = ref.watch(wishlistRepositoryProvider);
  final wishlist = await repository.getUserWishlist(currentUser.id);
  final userLat = selectedAddress?.latitude;
  final userLon = selectedAddress?.longitude;

  if (userLat == null || userLon == null) {
    return wishlist;
  }

  // Apply location-based pricing and filter by distance
  return wishlist
      .map(
        (item) => item.copyWith(
          service: item.service.copyWithLocationData(
            userLat: userLat,
            userLon: userLon,
          ),
        ),
      )
      // Filter services within 20km radius only
      .where((item) {
        if (item.service.distanceKm != null) {
          return item.service.distanceKm! <= 20.0;
        }
        return true; // Keep services without location data
      })
      .toList();
}

@riverpod
Future<bool> isServiceInWishlist(
  IsServiceInWishlistRef ref,
  String serviceId,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) {
    return false;
  }

  final repository = ref.watch(wishlistRepositoryProvider);
  return repository.isInWishlist(currentUser.id, serviceId);
}

@riverpod
Future<int> wishlistCount(WishlistCountRef ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) {
    return 0;
  }

  final repository = ref.watch(wishlistRepositoryProvider);
  return repository.getWishlistCount(currentUser.id);
}

@riverpod
class WishlistNotifier extends _$WishlistNotifier {
  @override
  FutureOr<List<WishlistWithService>> build() async {
    final currentUser = ref.watch(currentUserProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);
    if (currentUser == null) {
      return [];
    }

    final repository = ref.watch(wishlistRepositoryProvider);
    final wishlist = await repository.getUserWishlist(currentUser.id);
    final userLat = selectedAddress?.latitude;
    final userLon = selectedAddress?.longitude;

    if (userLat == null || userLon == null) {
      return wishlist;
    }

    // Apply location-based pricing and filter by distance
    return wishlist
        .map(
          (item) => item.copyWith(
            service: item.service.copyWithLocationData(
              userLat: userLat,
              userLon: userLon,
            ),
          ),
        )
        // Filter services within 20km radius only
        .where((item) {
          if (item.service.distanceKm != null) {
            return item.service.distanceKm! <= 20.0;
          }
          return true; // Keep services without location data
        })
        .toList();
  }

  Future<void> addToWishlist(String serviceId) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      state = const AsyncValue.loading();
      final repository = ref.read(wishlistRepositoryProvider);
      await repository.addToWishlist(currentUser.id, serviceId);

      // Refresh the wishlist
      ref.invalidateSelf();
      // Also invalidate the wishlist count
      ref.invalidate(wishlistCountProvider);
      // Invalidate specific service wishlist status
      ref.invalidate(isServiceInWishlistProvider(serviceId));
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  Future<void> removeFromWishlist(String serviceId) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      state = const AsyncValue.loading();
      final repository = ref.read(wishlistRepositoryProvider);
      await repository.removeFromWishlist(currentUser.id, serviceId);

      // Refresh the wishlist
      ref.invalidateSelf();
      // Also invalidate the wishlist count
      ref.invalidate(wishlistCountProvider);
      // Invalidate specific service wishlist status
      ref.invalidate(isServiceInWishlistProvider(serviceId));
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  Future<void> toggleWishlist(String serviceId) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final repository = ref.read(wishlistRepositoryProvider);
    final isInWishlist = await repository.isInWishlist(
      currentUser.id,
      serviceId,
    );

    if (isInWishlist) {
      await removeFromWishlist(serviceId);
    } else {
      await addToWishlist(serviceId);
    }
  }
}
