import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sylonow_user/core/providers/core_providers.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';
import 'package:sylonow_user/features/address/providers/address_providers.dart';

/// Provider to fetch services by category name with location-based filtering
/// This provider fetches services within a 25km radius from the user's selected address
final categoryServicesProvider = FutureProvider.family<List<ServiceListingModel>, String>((ref, categoryName) async {
  final supabase = ref.watch(supabaseClientProvider);
  final selectedAddress = ref.watch(selectedAddressProvider);

  print('🔍🔍🔍 categoryServicesProvider CALLED for category: $categoryName');
  print('🔍 Selected Address in provider: ${selectedAddress?.address}');
  print('🔍 Address Coordinates in provider: lat=${selectedAddress?.latitude}, lon=${selectedAddress?.longitude}');

  try {
    // Get user location coordinates
    final userLat = selectedAddress?.latitude;
    final userLon = selectedAddress?.longitude;

    if (userLat == null || userLon == null) {
      print('🔍 NO LOCATION - Fetching all services without location filter');
      // If no location, fetch all services in the category
      final response = await supabase
          .from('service_listings')
          .select('''
            *,
            vendor:vendor_id(
              id,
              business_name,
              rating,
              total_reviews,
              profile_image_url,
              latitude,
              longitude
            )
          ''')
          .eq('category', categoryName)
          .eq('is_active', true)
          .eq('is_verified', true)
          .order('created_at', ascending: false);

      final services = (response as List)
          .map((json) => ServiceListingModel.fromJson(json as Map<String, dynamic>))
          .toList();

      print('🔍 Fetched ${services.length} services without location');
      return services;
    }

    // Fetch services with location-based filtering (25km radius)
    final radiusKm = 25.0;

    print('🔍 WITH LOCATION - Fetching services with RPC call');
    print('🔍 RPC params: category=$categoryName, lat=$userLat, lon=$userLon, radius=$radiusKm');

    // Use the same RPC as decoration card (get_nearby_services_with_price)
    // This RPC calculates location-based fees and returns display prices
    final response = await supabase.rpc('get_nearby_services_with_price', params: {
      'user_lat': userLat,
      'user_lon': userLon,
      'radius_km': radiusKm,
      'service_limit': 100, // Fetch more to filter by category client-side
    });

    print('🔍 RPC Response Type: ${response.runtimeType}');
    print('🔍 RPC Response Value: $response');

    if (response == null) {
      print('🔍 Response is null');
      return [];
    }

    // Handle the response - RPC returns JSONB which needs to be converted to List
    List<dynamic> servicesList;
    if (response is List) {
      print('🔍 Response is List with ${response.length} items');
      servicesList = response;
    } else {
      print('🔍 Response is not a List, type: ${response.runtimeType}');
      return [];
    }

    if (servicesList.isEmpty) {
      print('🔍 Services list is empty');
      return [];
    }

    print('🔍 Processing ${servicesList.length} services from RPC');
    final services = servicesList
        .map((json) => ServiceListingModel.fromJson(json as Map<String, dynamic>))
        .toList();

    // Filter by category (since RPC returns all nearby services)
    final categoryServices = services.where((service) =>
      service.category?.toLowerCase() == categoryName.toLowerCase()
    ).toList();

    print('🔍 Filtered to ${categoryServices.length} services for category: $categoryName');

    // Add location data to each service
    final servicesWithLocation = categoryServices.map((service) {
      return service.copyWithLocationData(
        userLat: userLat,
        userLon: userLon,
      );
    }).toList();

    print('🔍 Returning ${servicesWithLocation.length} services with location data');
    if (servicesWithLocation.isNotEmpty) {
      final firstService = servicesWithLocation.first;
      print('🔍 First service: ${firstService.name}');
      print('🔍 First service original price: ${firstService.displayOriginalPrice}');
      print('🔍 First service offer price: ${firstService.displayOfferPrice}');
      print('🔍 First service calculated price: ${firstService.calculatedPrice}');
      print('🔍 First service distance: ${firstService.distanceKm} km');
    }

    return servicesWithLocation;
  } catch (e) {
    print('❌ Error fetching category services: $e');
    rethrow;
  }
});

/// Provider for services by category only (no decoration type filter)
final servicesByCategoryProvider = FutureProvider.family<List<ServiceListingModel>, String>((ref, categoryName) async {
  final supabase = ref.watch(supabaseClientProvider);

  try {
    final response = await supabase
        .from('service_listings')
        .select('''
          *,
          vendor:vendor_id(
            id,
            business_name,
            rating,
            total_reviews,
            profile_image_url,
            latitude,
            longitude
          )
        ''')
        .eq('category', categoryName)
        .eq('is_active', true)
        .eq('is_verified', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ServiceListingModel.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    print('Error in servicesByCategoryProvider: $e');
    rethrow;
  }
});

/// Provider for services by category AND decoration type
final servicesByCategoryAndDecorationTypeProvider = FutureProvider.family<List<ServiceListingModel>, Map<String, String>>((ref, params) async {
  final supabase = ref.watch(supabaseClientProvider);
  final category = params['category']!;
  final decorationType = params['decorationType']!;

  try {
    final response = await supabase
        .from('service_listings')
        .select('''
          *,
          vendor:vendor_id(
            id,
            business_name,
            rating,
            total_reviews,
            profile_image_url,
            latitude,
            longitude
          )
        ''')
        .eq('category', category)
        .eq('decoration_type', decorationType)
        .eq('is_active', true)
        .eq('is_verified', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ServiceListingModel.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (e) {
    print('Error in servicesByCategoryAndDecorationTypeProvider: $e');
    rethrow;
  }
});

/// Provider for services by category AND decoration type WITH location filtering
final servicesByCategoryAndDecorationTypeWithLocationProvider = FutureProvider.family<List<ServiceListingModel>, Map<String, dynamic>>((ref, params) async {
  final supabase = ref.watch(supabaseClientProvider);
  final category = params['category'] as String;
  final decorationType = params['decorationType'] as String;
  final userLat = params['userLat'] as double;
  final userLon = params['userLon'] as double;
  final radiusKm = params['radiusKm'] as double;

  try {
    // Use RPC function for efficient location-based filtering
    final response = await supabase.rpc('get_services_by_category_decoration_and_location', params: {
      'p_category': category,
      'p_decoration_type': decorationType,
      'p_user_lat': userLat,
      'p_user_lon': userLon,
      'p_radius_km': radiusKm,
    });

    if (response == null) {
      return [];
    }

    // Handle the response - it's a List directly from RPC
    List<dynamic> servicesList;
    if (response is List) {
      servicesList = response;
    } else {
      return [];
    }

    if (servicesList.isEmpty) {
      return [];
    }

    final services = servicesList
        .map((json) => ServiceListingModel.fromJson(json as Map<String, dynamic>))
        .toList();

    // Add location data to each service
    return services.map((service) {
      return service.copyWithLocationData(
        userLat: userLat,
        userLon: userLon,
      );
    }).toList();
  } catch (e) {
    print('Error in servicesByCategoryAndDecorationTypeWithLocationProvider: $e');
    rethrow;
  }
});
