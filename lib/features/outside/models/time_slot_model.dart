import 'package:sylonow_user/core/utils/price_rounding.dart';

class TimeSlotModel {
  final String id;
  final String theaterId;
  final String? screenId;
  final String slotName;
  final String startTime;
  final String endTime;
  final double basePrice;        // Rounded display price (X49/X99)
  final double rawBasePrice;     // Original DB price before rounding (for RPC calls)
  final double discountedPrice;
  final double? comparePrice; // Original/MRP price for strikethrough display
  final bool isActive;
  final bool isBooked;

  const TimeSlotModel({
    required this.id,
    required this.theaterId,
    this.screenId,
    required this.slotName,
    required this.startTime,
    required this.endTime,
    required this.basePrice,
    required this.rawBasePrice,
    required this.discountedPrice,
    this.comparePrice,
    this.isActive = true,
    this.isBooked = false,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    // Generate slot name from time range since slot_name doesn't exist in DB
    final startTime = json['start_time'] as String? ?? '00:00';
    final endTime = json['end_time'] as String? ?? '00:00';
    final generatedSlotName = '$startTime - $endTime';

    // Apply the same price rounding used in theater service to match card prices
    final dbBasePrice = (json['base_price'] as num?)?.toDouble() ?? 0.0;
    final dbRawBasePrice =
        (json['raw_base_price'] as num?)?.toDouble() ?? dbBasePrice;
    final dbDiscountedPrice = (json['discounted_price'] as num?)?.toDouble() ?? 0.0;
    final dbComparePrice = (json['compare_price'] as num?)?.toDouble();

    // Apply final rounding to match the prices shown in theater cards
    final roundedBasePrice = dbBasePrice > 0
        ? PriceRounding.applyFinalRounding(dbBasePrice)
        : 0.0;
    final roundedDiscountedPrice = dbDiscountedPrice > 0
        ? PriceRounding.applyFinalRounding(dbDiscountedPrice)
        : 0.0;
    final roundedComparePrice = dbComparePrice != null && dbComparePrice > 0
        ? PriceRounding.applyFinalRounding(dbComparePrice)
        : null;

    return TimeSlotModel(
      id: json['id'] as String,
      theaterId: json['theater_id'] as String,
      screenId: json['screen_id'] as String?,
      slotName: generatedSlotName,
      startTime: startTime,
      endTime: endTime,
      basePrice: roundedBasePrice,
      rawBasePrice: dbRawBasePrice,   // preserve original DB value for RPC/split math
      discountedPrice: roundedDiscountedPrice,
      comparePrice: roundedComparePrice,
      isActive: json['is_active'] as bool? ?? true,
      isBooked: json['is_booked'] as bool? ?? false,
    );
  }

  /// Get the effective price (discounted if available, otherwise base price)
  double get effectivePrice => discountedPrice > 0 ? discountedPrice : basePrice;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'theater_id': theaterId,
      'screen_id': screenId,
      'start_time': startTime,
      'end_time': endTime,
      'base_price': basePrice,
      'discounted_price': discountedPrice,
      'compare_price': comparePrice,
      'is_active': isActive,
      'is_booked': isBooked,
    };
  }

  TimeSlotModel copyWith({
    String? id,
    String? theaterId,
    String? screenId,
    String? slotName,
    String? startTime,
    String? endTime,
    double? basePrice,
    double? rawBasePrice,
    double? discountedPrice,
    double? comparePrice,
    bool? isActive,
    bool? isBooked,
  }) {
    return TimeSlotModel(
      id: id ?? this.id,
      theaterId: theaterId ?? this.theaterId,
      screenId: screenId ?? this.screenId,
      slotName: slotName ?? this.slotName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      basePrice: basePrice ?? this.basePrice,
      rawBasePrice: rawBasePrice ?? this.rawBasePrice,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      comparePrice: comparePrice ?? this.comparePrice,
      isActive: isActive ?? this.isActive,
      isBooked: isBooked ?? this.isBooked,
    );
  }

  String get formattedTimeRange {
    return '$startTime - $endTime';
  }

  Duration get duration {
    final start = DateTime.parse('2000-01-01 $startTime');
    final end = DateTime.parse('2000-01-01 $endTime');
    return end.difference(start);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeSlotModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TimeSlotModel(id: $id, slotName: $slotName, startTime: $startTime, endTime: $endTime, basePrice: $basePrice, discountedPrice: $discountedPrice, isBooked: $isBooked)';
  }
}
