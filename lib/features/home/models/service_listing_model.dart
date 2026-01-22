import 'dart:math' as math;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sylonow_user/core/utils/price_rounding.dart';
import 'package:sylonow_user/features/home/models/vendor_model.dart';

part 'service_listing_model.freezed.dart';
part 'service_listing_model.g.dart';

/// Helper function to safely convert nullable numeric values to double
double? _safeNullableDoubleFromJson(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed;
  }
  return null;
}

@freezed
class ServiceListingModel with _$ServiceListingModel {
  const factory ServiceListingModel({
    required String id,
    @JsonKey(name: 'vendor_id') required String? vendorId,
    @JsonKey(name: 'title') required String name,
    @JsonKey(name: 'cover_photo') String? image,
    String? description,
    double? rating,
    @JsonKey(name: 'reviews_count') int? reviewsCount,
    @JsonKey(name: 'offers_count') int? offersCount,
    VendorModel? vendor,
    @JsonKey(name: 'promotional_tag') String? promotionalTag,
    List<String>? inclusions,
    List<String>? exclusions,
    @JsonKey(name: 'original_price', fromJson: _safeNullableDoubleFromJson) double? originalPrice,
    @JsonKey(name: 'offer_price', fromJson: _safeNullableDoubleFromJson) double? offerPrice,
    @JsonKey(name: 'is_featured') bool? isFeatured,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'is_active') bool? isActive,
    List<String>? photos, // Array of service images
    String? category, // Service category for finding related services
    // Enhanced booking fields from database
    @JsonKey(name: 'venue_types') List<String>? venueTypes,
    @JsonKey(name: 'theme_tags') List<String>? themeTags,
    @JsonKey(name: 'add_ons') List<Map<String, dynamic>>? addOns,
    @JsonKey(name: 'setup_time') String? setupTime,
    @JsonKey(name: 'booking_notice') String? bookingNotice,
    @JsonKey(name: 'customization_available') bool? customizationAvailable,
    @JsonKey(name: 'customization_note') String? customizationNote,
    @JsonKey(name: 'service_environment') List<String>? serviceEnvironment,
    @JsonKey(name: 'video_url') String? videoUrl,
    @JsonKey(name: 'decoration_type') String? decorationType, // 'inside', 'outside', or 'both'
    // Banner fields
    @JsonKey(name: 'provides_banner') bool? providesBanner,
    @JsonKey(name: 'banner_text') String? bannerText,
    // Location fields
    @JsonKey(fromJson: _safeNullableDoubleFromJson) double? latitude,
    @JsonKey(fromJson: _safeNullableDoubleFromJson) double? longitude,
    // Distance-based pricing fields (from database)
    @JsonKey(name: 'free_service_km', fromJson: _safeNullableDoubleFromJson) double? freeServiceKm,
    @JsonKey(name: 'extra_charges_per_km', fromJson: _safeNullableDoubleFromJson) double? extraChargesPerKm,
    // Calculated fields (from RPC function or client-side calculation)
    @JsonKey(name: 'distance_km', fromJson: _safeNullableDoubleFromJson) double? distanceKm,
    @JsonKey(name: 'calculated_price', fromJson: _safeNullableDoubleFromJson) double? calculatedPrice,
    // Legacy calculated fields (kept for backward compatibility)
    @JsonKey(includeFromJson: false, includeToJson: false) double? adjustedOfferPrice,
    @JsonKey(includeFromJson: false, includeToJson: false) double? adjustedOriginalPrice,
    @JsonKey(includeFromJson: false, includeToJson: false) bool? isPriceAdjusted,
  }) = _ServiceListingModel;

  factory ServiceListingModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceListingModelFromJson(json);
}

extension ServiceListingModelExtensions on ServiceListingModel {
  /// Check if service has valid location coordinates
  bool get hasValidLocation {
    final lat = latitude;
    final lng = longitude;
    return lat != null && 
           lng != null && 
           lat >= -90.0 && lat <= 90.0 &&
           lng >= -180.0 && lng <= 180.0;
  }

  /// Get display price (calculated from RPC if available, otherwise adjusted/offer price)
  double? get displayOfferPrice {
    return calculatedPrice ?? adjustedOfferPrice ?? offerPrice;
  }

  /// Get display original price (adjusted if available, otherwise original price)
  /// RPC functions return simple prices without extra fees, so use them directly
  double? get displayOriginalPrice {
    // Simply return the original price - RPC functions handle any distance surcharges
    // The 15% surcharge for >10km distance is already applied by RPC to offer_price
    return adjustedOriginalPrice ?? originalPrice;
  }

  /// Copy service with location-based calculations
  ServiceListingModel copyWithLocationData({
    required double? userLat,
    required double? userLon,
  }) {
    if (!hasValidLocation || userLat == null || userLon == null) {
      return this;
    }

    // Calculate distance using Haversine formula
    const earthRadius = 6371.0; // Earth's radius in kilometers
    final lat1Rad = userLat * (3.14159265359 / 180.0);
    final lon1Rad = userLon * (3.14159265359 / 180.0);
    final serviceLat = latitude ?? 0.0;
    final serviceLng = longitude ?? 0.0;
    final lat2Rad = serviceLat * (3.14159265359 / 180.0);
    final lon2Rad = serviceLng * (3.14159265359 / 180.0);

    final dLat = lat2Rad - lat1Rad;
    final dLon = lon2Rad - lon1Rad;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadius * c;

    // Calculate dynamic price using Canvas formula (same as RPC)
    // Formula: base + distance_charges + convenience_fee (₹19) + transaction_fee (3.54%)
    // Then apply rounding to ensure prices end with 49 or 99
    double? dynamicPrice;

    final basePrice = offerPrice ?? originalPrice;
    if (basePrice != null && freeServiceKm != null && extraChargesPerKm != null) {
      // Step 1: Calculate base price with distance charges
      final extraDistance = math.max(0.0, distance - freeServiceKm!);
      final locationCharges = extraDistance * extraChargesPerKm!;
      final baseWithDistance = basePrice + locationCharges;

      // Step 2: Add convenience fee and transaction fee (Canvas formula)
      const convenienceFee = 19.00;
      const transactionFeeRate = 0.0354; // 3.54%
      final transactionFee = baseWithDistance * transactionFeeRate;

      final priceBeforeRounding = baseWithDistance + convenienceFee + transactionFee;

      // Step 3: Apply rounding to ensure price ends with 49 or 99
      dynamicPrice = PriceRounding.applyFinalRounding(priceBeforeRounding);
    } else if (basePrice != null) {
      // No location-based pricing: base + convenience_fee + transaction_fee
      const convenienceFee = 19.00;
      const transactionFeeRate = 0.0354;
      final transactionFee = basePrice * transactionFeeRate;

      final priceBeforeRounding = basePrice + convenienceFee + transactionFee;

      // Apply rounding to ensure price ends with 49 or 99
      dynamicPrice = PriceRounding.applyFinalRounding(priceBeforeRounding);
    }

    return copyWith(
      distanceKm: double.parse(distance.toStringAsFixed(2)),
      calculatedPrice: dynamicPrice,
      adjustedOfferPrice: dynamicPrice,
      adjustedOriginalPrice: originalPrice != null ? PriceRounding.applyFinalRounding(originalPrice!) : null,
      isPriceAdjusted: dynamicPrice != null && dynamicPrice > (offerPrice ?? originalPrice ?? 0.0),
    );
  }
} 