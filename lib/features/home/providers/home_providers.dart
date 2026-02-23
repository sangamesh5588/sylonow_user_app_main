import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/features/home/repositories/home_repository.dart';
import 'package:sylonow_user/features/home/repositories/quote_repository.dart';
import 'package:sylonow_user/features/home/models/quote_model.dart';
import 'package:sylonow_user/features/home/models/vendor_model.dart';
import 'package:sylonow_user/features/home/models/service_type_model.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';
import 'package:sylonow_user/features/home/models/category_model.dart';
import 'package:sylonow_user/features/address/providers/address_providers.dart';

/// MIGRATION NOTICE (2026-01):
/// - featuredServicesSimpleProvider → featuredMainServicesProvider (5km radius filtering)
/// - featuredServicesProvider (StateNotifier) → Use featuredMainServicesProvider or featuredCollageServicesProvider
/// - theaterScreensProvider → featuredTheaterScreensProvider (5km radius for featured theaters)
///
/// New providers use separate featured flags per section and apply 5km radius filtering.

/// Provider for Supabase client
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for home repository
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return HomeRepository(supabase);
});

/// Provider for quote repository
final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository();
});

/// Provider for daily quote
final dailyQuoteProvider = FutureProvider<QuoteModel?>((ref) async {
  final repository = ref.watch(quoteRepositoryProvider);
  return repository.getTrulyRandomQuote();
});

/// Provider for featured partners
final featuredPartnersProvider = FutureProvider<List<VendorModel>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getFeaturedPartners();
});

/// Provider for service categories
final serviceCategoriesProvider = FutureProvider<List<ServiceTypeModel>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getServiceCategories();
});

/// Provider for services with specific discount percentage or more
final servicesWithDiscountProvider = FutureProvider.family<List<ServiceListingModel>, int>((ref, minDiscountPercent) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getServicesWithDiscount(minDiscountPercent);
});

/// State for featured services pagination
class FeaturedServicesState {
  final List<ServiceListingModel> services;
  final bool hasMore;
  final int page;

  FeaturedServicesState({
    this.services = const [],
    this.hasMore = true,
    this.page = 0,
  });

  FeaturedServicesState copyWith({
    List<ServiceListingModel>? services,
    bool? hasMore,
    int? page,
  }) {
    return FeaturedServicesState(
      services: services ?? this.services,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }
}

/// Notifier for featured services
class FeaturedServicesNotifier extends StateNotifier<FeaturedServicesState> {
  final HomeRepository _repository;
  static const int _pageSize = 5;
  bool _isLoading = false;

  FeaturedServicesNotifier(this._repository) : super(FeaturedServicesState()) {
    fetchNextPage();
  }

  Future<void> fetchNextPage() async {
    if (!state.hasMore || _isLoading) return;

    _isLoading = true;

    try {
      final newServices = await _repository.getFeaturedServices(
        limit: _pageSize,
        offset: state.page * _pageSize,
      );

      if (newServices.length < _pageSize) {
        state = state.copyWith(hasMore: false);
      }

      state = state.copyWith(
        services: [...state.services, ...newServices],
        page: state.page + 1,
      );
    } catch (e) {
      // Handle error appropriately
    } finally {
      _isLoading = false;
    }
  }
}

/// Provider for featured services with pagination
/// @deprecated Use featuredMainServicesProvider or featuredCollageServicesProvider instead
/// This provider does not apply location-based filtering
@Deprecated('Use featuredMainServicesProvider or featuredCollageServicesProvider instead')
final featuredServicesProvider =
    StateNotifierProvider<FeaturedServicesNotifier, FeaturedServicesState>((ref) {
  final repository = ref.watch(homeRepositoryProvider);
  return FeaturedServicesNotifier(repository);
});

/// Provider for featured services with location-based pricing (simple version)
/// @deprecated Use featuredMainServicesProvider instead
/// This provider applies location pricing but NO distance filtering (shows all featured services globally)
@Deprecated('Use featuredMainServicesProvider for 5km radius filtering')
final featuredServicesSimpleProvider = FutureProvider.autoDispose<List<ServiceListingModel>>((ref) async {
  ref.keepAlive();

  final repository = ref.watch(homeRepositoryProvider);
  final selectedAddress = ref.watch(selectedAddressProvider);
  final userLat = selectedAddress?.latitude;
  final userLon = selectedAddress?.longitude;

  // Fetch featured services from database
  final featuredServices = await repository.getFeaturedServices(limit: 20);

  // If no location, return as-is
  if (userLat == null || userLon == null) {
    debugPrint('📍 Featured: No location, returning ${featuredServices.length} services without pricing');
    return featuredServices;
  }

  // Apply location-based pricing to each featured service
  final servicesWithLocation = featuredServices.map((service) {
    return service.copyWithLocationData(
      userLat: userLat,
      userLon: userLon,
    );
  }).toList();

  debugPrint('📍 Featured: Returning ${servicesWithLocation.length} services with location pricing');
  return servicesWithLocation;
});

/// Provider for private theater services
final privateTheaterServicesProvider = FutureProvider<List<ServiceListingModel>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getPrivateTheaterServices();
});

/// Provider for popular nearby services
/// Automatically filters by 20km radius from selected address coordinates
/// This provider automatically refreshes when the selected address changes
final popularNearbyServicesProvider = FutureProvider.autoDispose<List<ServiceListingModel>>((ref) async {
  // Keep the provider alive for 5 seconds after last use to prevent rapid disposal/recreation
  ref.keepAlive();

  final repository = ref.watch(homeRepositoryProvider);

  // Watch selected address - provider will refresh when address changes
  final selectedAddress = ref.watch(selectedAddressProvider);
  final userLat = selectedAddress?.latitude;
  final userLon = selectedAddress?.longitude;

  // Log location change for debugging
  debugPrint('📍 Popular Nearby Services: Fetching for location ($userLat, $userLon)');
  debugPrint('📍 Selected address: ${selectedAddress?.address}');

  final services = await repository.getPopularNearbyServices(
    userLat: userLat,
    userLon: userLon,
    radiusKm: 20.0, // 20km radius
    limit: 20, // Increased limit to show more services
  );

  debugPrint('📍 Found ${services.length} services for location');
  if (services.isNotEmpty) {
    for (var service in services) {
      debugPrint('  - ${service.name} (${service.distanceKm?.toStringAsFixed(1) ?? "N/A"} km)');
    }
  }
  return services;
});

/// Provider for all home screen data
final homeScreenDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getHomeScreenData();
});

/// Provider for categories
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getCategories();
});

/// Provider for services by category
final servicesByCategoryProvider = FutureProvider.family<List<ServiceListingModel>, String>((ref, categoryName) async {
  print('🔍 Provider: servicesByCategoryProvider called with category: $categoryName');
  final repository = ref.watch(homeRepositoryProvider);
  try {
    final result = await repository.getServicesByCategory(categoryName: categoryName);
    print('🔍 Provider: servicesByCategoryProvider returning ${result.length} services');
    return result;
  } catch (e) {
    print('🔍 Provider: servicesByCategoryProvider error: $e');
    rethrow;
  }
});

/// Provider for services by decoration type
final servicesByDecorationTypeProvider = FutureProvider.family<List<ServiceListingModel>, String>((ref, decorationType) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getServicesByDecorationType(decorationType: decorationType);
});

/// Provider for featured services by decoration type
final featuredServicesByDecorationTypeProvider = FutureProvider.family<List<ServiceListingModel>, String>((ref, decorationType) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getFeaturedServicesByDecorationType(decorationType: decorationType);
});

/// Provider for popular nearby services by decoration type
final popularNearbyServicesByDecorationTypeProvider = FutureProvider.family<List<ServiceListingModel>, String>((ref, decorationType) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getPopularNearbyServicesByDecorationType(decorationType: decorationType);
});

/// Provider for home screen data by decoration type
final homeScreenDataByDecorationTypeProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, decorationType) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getHomeScreenDataByDecorationType(decorationType);
});

/// Provider for services with location-based filtering and pricing
/// Params: {decorationType, userLat, userLon, radiusKm}
final servicesWithLocationProvider = FutureProvider.family<List<ServiceListingModel>, Map<String, dynamic>>((ref, params) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getServicesWithLocation(
    userLat: params['userLat'] as double,
    userLon: params['userLon'] as double,
    decorationType: params['decorationType'] as String?,
    radiusKm: params['radiusKm'] as double?,
  );
});

/// Provider for services by decoration type with location
/// Params: {decorationType, userLat, userLon, radiusKm}
final servicesByDecorationTypeWithLocationProvider = FutureProvider.family<List<ServiceListingModel>, Map<String, dynamic>>((ref, params) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getServicesByDecorationTypeWithLocation(
    decorationType: params['decorationType'] as String,
    userLat: params['userLat'] as double,
    userLon: params['userLon'] as double,
    radiusKm: params['radiusKm'] as double?,
  );
});

/// Provider for featured services with location
/// Params: {userLat, userLon, decorationType?, radiusKm?}
final featuredServicesWithLocationProvider = FutureProvider.family<List<ServiceListingModel>, Map<String, dynamic>>((ref, params) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getFeaturedServicesWithLocation(
    userLat: params['userLat'] as double,
    userLon: params['userLon'] as double,
    decorationType: params['decorationType'] as String?,
    radiusKm: params['radiusKm'] as double?,
  );
});

/// Provider for popular nearby services with actual location-based filtering
/// Params: {userLat, userLon, decorationType?, radiusKm?}
final popularNearbyServicesWithLocationProvider = FutureProvider.family<List<ServiceListingModel>, Map<String, dynamic>>((ref, params) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getPopularNearbyServicesWithLocation(
    userLat: params['userLat'] as double,
    userLon: params['userLon'] as double,
    decorationType: params['decorationType'] as String?,
    radiusKm: params['radiusKm'] as double? ?? 25.0,
  );
});

/// Provider for services by category and decoration type
/// Params: {category, decorationType}
final servicesByCategoryAndDecorationTypeProvider = FutureProvider.family<List<ServiceListingModel>, Map<String, String>>((ref, params) async {
  print('🔍 Provider: servicesByCategoryAndDecorationTypeProvider called with params: $params');
  final repository = ref.watch(homeRepositoryProvider);
  try {
    final result = await repository.getServicesByCategoryAndDecorationType(
      categoryName: params['category']!,
      decorationType: params['decorationType']!,
    );
    print('🔍 Provider: servicesByCategoryAndDecorationTypeProvider returning ${result.length} services');
    return result;
  } catch (e) {
    print('🔍 Provider: servicesByCategoryAndDecorationTypeProvider error: $e');
    rethrow;
  }
});

/// Provider for services by category and decoration type with location
/// Params: {category, decorationType, userLat, userLon, radiusKm?}
final servicesByCategoryAndDecorationTypeWithLocationProvider = FutureProvider.family<List<ServiceListingModel>, Map<String, dynamic>>((ref, params) async {
  print('🔍 Provider: servicesByCategoryAndDecorationTypeWithLocationProvider called with params: $params');
  final repository = ref.watch(homeRepositoryProvider);
  try {
    final result = await repository.getServicesByCategoryAndDecorationTypeWithLocation(
      categoryName: params['category'] as String,
      decorationType: params['decorationType'] as String,
      userLat: params['userLat'] as double,
      userLon: params['userLon'] as double,
      radiusKm: params['radiusKm'] as double?,
    );
    print('🔍 Provider: servicesByCategoryAndDecorationTypeWithLocationProvider returning ${result.length} services');
    return result;
  } catch (e) {
    print('🔍 Provider: servicesByCategoryAndDecorationTypeWithLocationProvider error: $e');
    rethrow;
  }
});

/// Provider for featured main services with 5km location-based filtering
/// Returns empty list if no services within 5km (section will hide)
final featuredMainServicesProvider = FutureProvider.autoDispose<List<ServiceListingModel>>((ref) async {
  ref.keepAlive();

  final repository = ref.watch(homeRepositoryProvider);
  final selectedAddress = ref.watch(selectedAddressProvider);
  final userLat = selectedAddress?.latitude;
  final userLon = selectedAddress?.longitude;

  // If no location, return empty list (section will hide)
  if (userLat == null || userLon == null) {
    debugPrint('📍 Featured Main: No location, hiding section');
    return [];
  }

  // Fetch featured services within 5km
  final services = await repository.getFeaturedMainServicesNearby(
    userLat: userLat,
    userLon: userLon,
    radiusKm: 5.0,
    limit: 20,
  );

  debugPrint('📍 Featured Main: Returning ${services.length} services within 5km');
  return services;
});

/// Provider for featured collage services with 5km location-based filtering
/// Returns empty list if no services within 5km (section will hide)
final featuredCollageServicesProvider = FutureProvider.autoDispose<List<ServiceListingModel>>((ref) async {
  ref.keepAlive();

  final repository = ref.watch(homeRepositoryProvider);
  final selectedAddress = ref.watch(selectedAddressProvider);
  final userLat = selectedAddress?.latitude;
  final userLon = selectedAddress?.longitude;

  // If no location, return empty list (section will hide)
  if (userLat == null || userLon == null) {
    debugPrint('📍 Featured Collage: No location, hiding section');
    return [];
  }

  // Fetch featured collage services within 5km
  final services = await repository.getFeaturedCollageServicesNearby(
    userLat: userLat,
    userLon: userLon,
    radiusKm: 5.0,
    limit: 4,
  );

  debugPrint('📍 Featured Collage: Returning ${services.length} services within 5km');
  return services;
}); 