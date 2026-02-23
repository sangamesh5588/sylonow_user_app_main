import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/features/auth/providers/auth_providers.dart';
import 'package:sylonow_user/features/wishlist/models/wishlist_model.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';

part 'wishlist_repository.g.dart';

@riverpod
WishlistRepository wishlistRepository(Ref ref) {
  return WishlistRepository(ref.read(supabaseClientProvider));
}

class WishlistRepository {
  final SupabaseClient _supabase;

  WishlistRepository(this._supabase);

  Future<List<WishlistWithService>> getUserWishlist(String userId) async {
    try {
      final response = await _supabase
          .from('wishlist')
          .select('''
            *,
            service_listings!inner(
              id,
              title,
              description,
              original_price,
              offer_price,
              rating,
              reviews_count,
              cover_photo,
              photos,
              category,
              latitude,
              longitude,
              free_service_km,
              extra_charges_per_km,
              vendor_id,
              promotional_tag,
              is_featured,
              is_active,
              is_verified,
              created_at,
              updated_at,
              vendors!inner(
                id,
                business_name,
                is_verified,
                is_active,
                is_online
              )
            )
          ''')
          .eq('user_id', userId)
          .eq('service_listings.is_active', true)
          .eq('service_listings.is_verified', true)
          .eq('service_listings.vendors.is_verified', true)
          .eq('service_listings.vendors.is_active', true)
          .eq('service_listings.vendors.is_online', true)
          .order('created_at', ascending: false);

      return response.map((json) {
        final serviceData = json['service_listings'];
        return WishlistWithService(
          id: json['id'],
          userId: json['user_id'],
          serviceId: json['service_id'],
          createdAt: DateTime.parse(json['created_at']),
          updatedAt: DateTime.parse(json['updated_at']),
          service: ServiceListingModel.fromJson(serviceData),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch wishlist: $e');
    }
  }

  Future<bool> addToWishlist(String userId, String serviceId) async {
    try {
      await _supabase.from('wishlist').insert({
        'user_id': userId,
        'service_id': serviceId,
      });
      return true;
    } catch (e) {
      throw Exception('Failed to add to wishlist: $e');
    }
  }

  Future<bool> removeFromWishlist(String userId, String serviceId) async {
    try {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('user_id', userId)
          .eq('service_id', serviceId);
      return true;
    } catch (e) {
      throw Exception('Failed to remove from wishlist: $e');
    }
  }

  Future<bool> isInWishlist(String userId, String serviceId) async {
    try {
      final response = await _supabase
          .from('wishlist')
          .select('id')
          .eq('user_id', userId)
          .eq('service_id', serviceId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      throw Exception('Failed to check wishlist status: $e');
    }
  }

  Future<int> getWishlistCount(String userId) async {
    try {
      final response = await _supabase
          .from('wishlist')
          .select('id')
          .eq('user_id', userId);

      return response.length;
    } catch (e) {
      throw Exception('Failed to get wishlist count: $e');
    }
  }
}
