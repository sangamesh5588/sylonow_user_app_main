import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sylonow_user/core/utils/price_rounding.dart';
import 'package:sylonow_user/features/auth/providers/auth_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../address/models/address_model.dart';
import '../../address/providers/address_providers.dart' as addr;
import '../../coupons/models/coupon_model.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../home/models/service_listing_model.dart';
import '../../profile/providers/profile_providers.dart';
import '../../theater/models/add_on_model.dart';
import '../../theater/models/selected_add_on_model.dart';
import '../../theater/models/theater_screen_model.dart';
import '../../../core/services/image_upload_service.dart';
import '../providers/booking_providers.dart';
import '../services/razorpay_service.dart';

/// Helper function to safely convert dynamic values to double
double _safeToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed ?? 0.0;
  }
  return 0.0;
}

/// Helper function to format phone number by removing country code prefix (91)
String _formatPhoneNumber(String? phone) {
  if (phone == null || phone.isEmpty) return '';

  // Remove any spaces, hyphens, or special characters
  String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  // Check if phone starts with +91 or 91
  if (cleanPhone.startsWith('+91')) {
    return cleanPhone.substring(3);
  } else if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
    return cleanPhone.substring(2);
  }

  return phone;
}

class CheckoutScreen extends ConsumerStatefulWidget {
  final ServiceListingModel service;
  final Map<String, dynamic>? customization;
  final String? selectedAddressId;
  final TheaterTimeSlotWithScreenModel?
  selectedTimeSlot; // Theater time slot data
  final TheaterScreenModel? selectedScreen; // Theater screen data
  final String? selectedDate; // Selected date for booking
  final Map<String, Map<String, dynamic>>?
  selectedAddOns; // Selected add-ons from service detail

  const CheckoutScreen({
    super.key,
    required this.service,
    this.customization,
    this.selectedAddressId,
    this.selectedTimeSlot,
    this.selectedScreen,
    this.selectedDate,
    this.selectedAddOns,
  });

  static const String routeName = '/checkout';

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? selectedAddressId;
  bool isProcessing = false;
  String couponCode = '';
  double couponDiscount = 0.0;
  bool isCouponApplied = false;
  bool isApplyingCoupon = false;
  bool isBillDetailsExpanded = false;
  CouponModel? appliedCoupon;

  // Editable addons state
  Map<String, Map<String, dynamic>>? editableAddOns;

  // Vendor GST status
  bool vendorHasGst = false;
  bool isLoadingVendorGst = false;

  // Advance payment calculation
  Map<String, dynamic>? advancePaymentData;
  bool isLoadingAdvancePayment = false;

  // Service instructions
  final TextEditingController _serviceInstructionsController = TextEditingController();
  String serviceInstructions = '';

  // Vendor online status monitoring
  bool isVendorOnline = true;
  String? vendorBusinessName;
  Timer? _vendorStatusCheckTimer;

  @override
  void initState() {
    super.initState();
    selectedAddressId = widget.selectedAddressId;

    // Initialize editable addons with a copy of the original data
    if (widget.selectedAddOns != null) {
      editableAddOns = Map<String, Map<String, dynamic>>.from(
        widget.selectedAddOns!.map(
          (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedAddressId == null) {
        ref.read(addr.addressesProvider).whenData((addresses) {
          if (addresses.isNotEmpty && mounted) {
            setState(() {
              selectedAddressId = addresses.first.id;
            });
          }
        });
      }

      // Load vendor GST status and then calculate advance payment
      _loadVendorGstStatus().then((_) {
        _calculateAdvancePayment();
      });

      // Start monitoring vendor online status every 5 seconds
      _startVendorStatusMonitoring();
    });
  }

  /// Monitor vendor online status every 5 seconds
  void _startVendorStatusMonitoring() {
    // Check immediately first
    _checkVendorOnlineStatus();

    // Then check every 5 seconds
    _vendorStatusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _checkVendorOnlineStatus();
      }
    });
  }

  /// Check if vendor is still online
  Future<void> _checkVendorOnlineStatus() async {
    if (widget.service.vendorId == null) return;

    try {
      final vendorData = await Supabase.instance.client
          .from('vendors')
          .select('is_online, business_name')
          .eq('id', widget.service.vendorId!)
          .maybeSingle();

      if (vendorData != null && mounted) {
        final wasOnline = isVendorOnline;
        final nowOnline = vendorData['is_online'] as bool? ?? false;

        setState(() {
          isVendorOnline = nowOnline;
          vendorBusinessName = vendorData['business_name'] as String?;
        });

        // If vendor just went offline, show warning
        if (wasOnline && !nowOnline) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ ${vendorBusinessName ?? 'This vendor'} has gone offline. You cannot proceed with booking.',
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Silently fail - don't disrupt user experience
      if (kDebugMode) {
        print('Error checking vendor status: $e');
      }
    }
  }

  @override
  void didUpdateWidget(CheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if any important parameters have changed and update the UI
    bool shouldUpdate = false;

    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.selectedTimeSlot != widget.selectedTimeSlot ||
        oldWidget.selectedScreen != widget.selectedScreen ||
        oldWidget.selectedAddressId != widget.selectedAddressId) {
      shouldUpdate = true;
    }

    if (shouldUpdate) {
    

      // Update selected address if it changed
      if (oldWidget.selectedAddressId != widget.selectedAddressId) {
        selectedAddressId = widget.selectedAddressId;
      }

      // Force a rebuild by calling setState
      if (mounted) {
        setState(() {
          // Force rebuild with new parameters
        });
      }
    }
  }

  /// Check if the current service has any available coupons
  Future<bool> _hasAvailableCoupons() async {
    try {
      final servicePrice = _getServicePrice();
      final couponRepository = ref.read(couponRepositoryProvider);
      final coupons = await couponRepository.getAvailableCouponsForService(
        serviceId: widget.service.id,
        orderAmount: servicePrice,
      );
      return coupons.isNotEmpty;
    } catch (e) {
      // If there's an error fetching coupons, don't show the coupon section
      //('Error checking available coupons: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAddresses = ref.watch(addr.addressesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              _buildOrderSummary(),
              const SizedBox(height: 12),
              _buildAddressSection(userAddresses),
              const SizedBox(height: 12),
              _buildBillDetails(),
              const SizedBox(height: 12),
              _buildCancellationPolicy(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildCheckoutButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black.withOpacity(0.1),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: AppTheme.textPrimaryColor,
          size: 24,
        ),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Checkout',
        style: TextStyle(
          fontFamily: 'Okra',
          fontWeight: FontWeight.w600,
          color: AppTheme.headingColor,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.successColor.withOpacity(0.4),
                ),
              ),
              child: Text(
                'SECURE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successColor,
                  fontFamily: 'Okra',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.selectedTimeSlot != null
                      ? Icons.movie
                      : Icons.receipt_long,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${1 + (editableAddOns?.length ?? 0)} item${(1 + (editableAddOns?.length ?? 0)) > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                    fontFamily: 'Okra',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildServiceImage(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.service.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Okra',
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (widget.service.description != null) ...[
                      Text(
                        widget.service.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                          fontFamily: 'Okra',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Show service booking information for all services
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getSelectedDate(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                            fontFamily: 'Okra',
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getSelectedTimeRange(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Show screen information only for theater services
                    if (widget.selectedScreen != null ||
                        (widget.selectedTimeSlot != null &&
                            widget.selectedTimeSlot!.screenName != null)) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.movie,
                            size: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getScreenName(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    // Show service category and location information
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.selectedTimeSlot != null
                              ? 'Theater Service'
                              : 'Home Service',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${_formatPrice(_getServicePrice())}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                            fontFamily: 'Okra',
                          ),
                        ),
                        if (_getOriginalServicePriceForDisplay() >
                            _getServicePrice()) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${_formatPrice(_getOriginalServicePriceForDisplay())}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryColor,
                              decoration: TextDecoration.lineThrough,
                              fontFamily: 'Okra',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_calculateDiscount()}% OFF',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.successColor,
                                fontFamily: 'Okra',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Show editable add-ons if any
          if (editableAddOns != null && editableAddOns!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppTheme.backgroundColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Your Add-ons',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${editableAddOns!.length} item${editableAddOns!.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                    fontFamily: 'Okra',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...editableAddOns!.entries.map((entry) {
              final addOnKey = entry.key;
              final addOnData = entry.value;
              final addOnName = addOnData['name'] as String;
              final addOnPrice = _safeToDouble(addOnData['price']);
              final isCustomizable =
                  addOnData['isCustomizable'] as bool? ?? false;
              final customText =
                  addOnData['customText']?.toString() ??
                  addOnData['customisation_input']?.toString();
              final characterCount = addOnData['characterCount'] as int?;
              final hasEditableCustomData =
                  (customText?.trim().isNotEmpty ?? false) ||
                  ((characterCount ?? 0) > 1);
              final canEditCustomization =
                  isCustomizable || hasEditableCustomData;
              final hasCustomText = customText != null && customText.trim().isNotEmpty;
              final totalPrice = _safeToDouble(
                addOnData['totalPrice'] ?? addOnPrice,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildEditableAddOnImage(addOnData),
                          const SizedBox(width: 12),
                          // Addon details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addOnName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Okra',
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${_formatAddonPrice(totalPrice)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Okra',
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                if (hasCustomText) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '"${customText.trim()}"',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppTheme.textSecondaryColor,
                                      fontFamily: 'Okra',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canEditCustomization) ...[
                                GestureDetector(
                                  onTap: () =>
                                      _showEditableAddonCustomizationDialog(
                                        addOnKey,
                                      ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.22),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              GestureDetector(
                                onTap: () =>
                                    _confirmRemoveAddOn(addOnKey, addOnName),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Text(
                                    'Remove',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Okra',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Customization details
                      if (isCustomizable &&
                          customText != null &&
                          customText.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.edit_note,
                                    size: 14,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Custom Message:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                      fontFamily: 'Okra',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '"$customText"',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textSecondaryColor,
                                  fontFamily: 'Okra',
                                ),
                              ),
                              if (characterCount != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '$characterCount characters',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade600,
                                    fontFamily: 'Okra',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      _showEditableAddonCustomizationDialog(
                                        addOnKey,
                                      ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Okra',
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  int _calculateDiscount() {
    final originalPrice = _getOriginalServicePriceForDisplay();
    final offerPrice = _getServicePrice();

    if (originalPrice > 0 && offerPrice > 0 && originalPrice > offerPrice) {
      final discount = ((originalPrice - offerPrice) / originalPrice) * 100;
      return discount.round();
    }
    return 0;
  }

  double _calculateSelectedAddOnsTotal() {
    if (editableAddOns == null || editableAddOns!.isEmpty) {
      return 0.0;
    }

    double total = 0.0;
    //('=== ADD-ON CALCULATION DEBUG ===');
    for (final entry in editableAddOns!.entries) {
      final addOnId = entry.key;
      final addOnData = entry.value;
      final storedTotalPrice = _safeToDouble(addOnData['totalPrice']);
      final rawPrice = _safeToDouble(addOnData['price']);
      final name = addOnData['name'] as String?;

      //('Add-on: $name (ID: $addOnId)');
      //('  - Stored totalPrice: $storedTotalPrice');
      //('  - Raw price: $rawPrice');

      if (storedTotalPrice > 0) {
        total += storedTotalPrice;
        //('  - Using stored totalPrice: ₹$storedTotalPrice');
      } else if (rawPrice > 0) {
        final priceWithFeesRaw = rawPrice + (rawPrice * 0.0354);
        // Apply rounding to ensure add-on prices end with 49 or 99
        final priceWithFees = PriceRounding.applyFinalRounding(priceWithFeesRaw);
        total += priceWithFees;
        //('  - Calculated with fees: ₹$priceWithFees');
      }
    }
    //('Selected add-ons total (with fees): ₹$total');
    //('=== END ADD-ON CALCULATION DEBUG ===');
    return total;
  }

  double _calculateSelectedAddOnsRawTotal() {
    if (editableAddOns == null || editableAddOns!.isEmpty) {
      return 0.0;
    }

    double total = 0.0;
    //('=== RAW ADD-ON CALCULATION DEBUG ===');
    for (final entry in editableAddOns!.entries) {
      final addOnId = entry.key;
      final addOnData = entry.value;
      final storedTotalPrice = _safeToDouble(addOnData['totalPrice']);
      final characterCount = addOnData['characterCount'] as int? ?? 1;
      final perUnitPrice = _safeToDouble(addOnData['price']);
      final name = addOnData['name'] as String?;

      //('Raw Add-on: $name (ID: $addOnId)');
      //('  - Stored totalPrice: $storedTotalPrice');
      //('  - Per-unit price: $perUnitPrice');
      //('  - Character count: $characterCount');

      if (storedTotalPrice > 0) {
        // Calculate raw total by removing the transaction fee from stored totalPrice
        final rawTotal = storedTotalPrice / 1.0354;
        total += rawTotal;
        //('  - Raw total (totalPrice / 1.0354): ₹$rawTotal');
      } else if (perUnitPrice > 0) {
        // Fallback: calculate raw total from per-unit price * quantity
        final rawTotal = perUnitPrice * characterCount;
        total += rawTotal;
        //('  - Raw total (per-unit * count): ₹$rawTotal');
      }
    }
    //('Selected add-ons raw total (before fees): ₹$total');
    //('=== END RAW ADD-ON CALCULATION DEBUG ===');
    return total;
  }

  void _removeAddOn(String addOnKey) {
    setState(() {
      editableAddOns?.remove(addOnKey);
    });
    // Recalculate advance payment when add-ons change
    _calculateAdvancePayment();
  }

  Future<void> _confirmRemoveAddOn(String addOnKey, String addOnName) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Remove add-on?',
          style: TextStyle(fontFamily: 'Okra'),
        ),
        content: Text(
          'Remove "$addOnName" from your add-ons?',
          style: const TextStyle(fontFamily: 'Okra'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Okra'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Okra',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      _removeAddOn(addOnKey);
    }
  }

  Widget _buildEditableAddOnImage(Map<String, dynamic> addOnData) {
    final imageUrl = _extractEditableAddOnImageUrl(addOnData);
    final imageBox = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: imageUrl == null
          ? Icon(Icons.extension, color: AppTheme.primaryColor, size: 20)
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Icon(Icons.extension, color: AppTheme.primaryColor, size: 20),
              ),
            ),
    );

    if (imageUrl == null) return imageBox;
    return GestureDetector(
      onTap: () => _showNetworkImagePreview(imageUrl),
      child: imageBox,
    );
  }

  String? _extractEditableAddOnImageUrl(Map<String, dynamic> addOnData) {
    final imageUrl = addOnData['imageUrl'] as String?;
    if (_isValidImageUrl(imageUrl)) return imageUrl;
    final imageUrlSnake = addOnData['image_url'] as String?;
    if (_isValidImageUrl(imageUrlSnake)) return imageUrlSnake;
    final images = addOnData['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first?.toString();
      if (_isValidImageUrl(first)) return first;
    }

    final addonObj = addOnData['addon'];
    if (addonObj is AddOnModel &&
        addonObj.imageUrl != null &&
        addonObj.imageUrl!.isNotEmpty) {
      return addonObj.imageUrl;
    }
    try {
      final dynamic dynamicAddon = addonObj;
      final String? dynUrl = dynamicAddon?.imageUrl?.toString();
      if (_isValidImageUrl(dynUrl)) return dynUrl;
    } catch (_) {}
    if (addonObj is Map<String, dynamic>) {
      final mapImage = addonObj['imageUrl']?.toString();
      if (_isValidImageUrl(mapImage)) return mapImage;
      final mapImageSnake = addonObj['image_url']?.toString();
      if (_isValidImageUrl(mapImageSnake)) return mapImageSnake;
      final mapImages = addonObj['images'];
      if (mapImages is List && mapImages.isNotEmpty) {
        final first = mapImages.first?.toString();
        if (_isValidImageUrl(first)) return first;
      }
    }
    return null;
  }

  bool _isValidImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final v = value.trim();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  void _showNetworkImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => Container(
                  color: Colors.black87,
                  height: 240,
                  child: const Icon(Icons.broken_image, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditableAddonCustomizationDialog(String addOnKey) {
    if (editableAddOns == null || !editableAddOns!.containsKey(addOnKey)) return;

    final addOnData = editableAddOns![addOnKey]!;
    final addOnName = addOnData['name']?.toString() ?? 'Add-on';
    final isCustomizable = addOnData['isCustomizable'] as bool? ?? false;
    final existingCustomText = addOnData['customText']?.toString().trim() ?? '';
    final existingCount = addOnData['characterCount'] as int? ?? 0;
    final hasExistingCustomData =
        existingCustomText.isNotEmpty || existingCount > 1;
    if (!isCustomizable && !hasExistingCustomData) return;

    final controller = TextEditingController(
      text: addOnData['customText']?.toString() ?? '',
    );
    final addonObj = addOnData['addon'];
    String? type;
    final dataType =
        addOnData['customizationInputType']?.toString().toLowerCase() ??
        addOnData['inputType']?.toString().toLowerCase();
    if (dataType != null && dataType.isNotEmpty) {
      type = dataType;
    } else if (addonObj is Map<String, dynamic>) {
      type =
          addonObj['customizationInputType']?.toString().toLowerCase() ??
          addonObj['inputType']?.toString().toLowerCase();
    }
    final existingText = existingCustomText;
    final isNumberType =
        type == 'number' ||
        (type == null &&
            existingText != null &&
            existingText.isNotEmpty &&
            int.tryParse(existingText) != null);
    final unitPrice = _safeToDouble(addOnData['price']);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final inputValue = controller.text.trim();
          final multiplier = isNumberType
              ? (int.tryParse(inputValue) ?? 0)
              : inputValue.length;
          final totalRaw = (unitPrice * multiplier) * 1.0354;
          final totalPrice = _roundAddonPriceToNearest9(totalRaw).toDouble();

          return AlertDialog(
            title: Text(
              'Edit $addOnName',
              style: const TextStyle(fontFamily: 'Okra'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType:
                      isNumberType ? TextInputType.number : TextInputType.text,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: isNumberType ? 'Enter quantity' : 'Enter custom text',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Updated price: ₹${_formatAddonPrice(totalPrice)}',
                    style: const TextStyle(
                      fontFamily: 'Okra',
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Okra')),
              ),
              TextButton(
                onPressed: inputValue.isEmpty || multiplier <= 0
                    ? null
                    : () {
                        setState(() {
                          addOnData['customText'] = inputValue;
                          addOnData['characterCount'] = multiplier;
                          addOnData['totalPrice'] = totalPrice;
                        });
                        _calculateAdvancePayment();
                        Navigator.pop(context);
                      },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontFamily: 'Okra',
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServiceImage() {
    String imageUrl = '';
    if (widget.service.photos?.isNotEmpty == true) {
      imageUrl = widget.service.photos!.first;
    } else if (widget.service.image?.isNotEmpty ?? false) {
      imageUrl = widget.service.image!;
    }

    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.celebration, color: AppTheme.primaryColor, size: 28),
      );
    }

    return GestureDetector(
      onTap: () => _showNetworkImagePreview(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.celebration,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSection(AsyncValue<List<Address>> userAddresses) {
    final selectedAddressFromState = ref.watch(addr.selectedAddressProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service timing section (like Zomato's delivery timing)
          _buildServiceTimingSection(),

          const SizedBox(height: 20),

          // Delivery address section
          userAddresses.when(
            data: (addresses) {
              if (addresses.isEmpty) {
                return _buildAddAddressButton();
              }

              // Resolve selected address from shared provider first, then local state.
              String resolvedAddressId;
              if (selectedAddressFromState != null &&
                  addresses.any((a) => a.id == selectedAddressFromState.id)) {
                resolvedAddressId = selectedAddressFromState.id;
              } else if (selectedAddressId != null &&
                  addresses.any((a) => a.id == selectedAddressId)) {
                resolvedAddressId = selectedAddressId!;
              } else {
                resolvedAddressId = addresses.first.id;
              }

              if (selectedAddressId != resolvedAddressId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    selectedAddressId = resolvedAddressId;
                  });
                });
              }

              final selectedAddress = addresses.firstWhere(
                (addr) => addr.id == resolvedAddressId,
                orElse: () => addresses.first,
              );

              return _buildZomatoStyleAddressCard(
                selectedAddress,
                userAddresses,
              );
            },
            loading: () => _buildLoadingAddressCard(),
            error: (error, stack) => _buildAddAddressButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTimingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Service delivery timing
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.access_time, color: Colors.grey[600], size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Service in 2-3 hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontFamily: 'Okra',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildZomatoStyleAddressCard(
    Address address,
    AsyncValue<List<Address>> userAddresses,
  ) {
    final currentUser = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Delivery at Home section
        Row(
          children: [
            Icon(Icons.location_on, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            const Text(
              'Service at Home',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Okra',
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _showAddressSelector(userAddresses),
              child: Icon(
                Icons.keyboard_arrow_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Address details
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            address.address,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: 'Okra',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(height: 16),

        // Add instructions section (like Zomato's delivery instructions)
        GestureDetector(
          onTap: () {
            // TODO: Implement delivery instructions
            _showDeliveryInstructions();
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              'Add instructions for service provider',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
                fontFamily: 'Okra',
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Customer details section (like Zomato's contact info)
        Row(
          children: [
            Icon(Icons.call, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser?.userMetadata?['name'] ?? 'Customer',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Okra',
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentUser?.phone != null
                        ? _formatPhoneNumber(currentUser!.phone!)
                        : currentUser?.email ?? 'Contact info',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontFamily: 'Okra',
                    ),
                  ),
                  const SizedBox(height: 8),
                  // GestureDetector(
                  //   onTap: _showAddAlternateNumberDialog,
                  //   child: Text(
                  //     'Add alternate number',
                  //     style: TextStyle(
                  //       fontSize: 14,
                  //       color: AppTheme.primaryColor,
                  //       fontWeight: FontWeight.w500,
                  //       fontFamily: 'Okra',
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
            // GestureDetector(
            //   onTap: () {
            //     // TODO: Edit contact details
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       const SnackBar(
            //         content: Text('Edit contact feature coming soon!'),
            //       ),
            //     );
            //   },
            //   child: Icon(
            //     Icons.keyboard_arrow_right,
            //     color: Colors.grey[400],
            //     size: 20,
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  void _showDeliveryInstructions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Service Instructions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _serviceInstructionsController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Add any special instructions for the service provider...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontFamily: 'Okra',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
                style: const TextStyle(fontFamily: 'Okra', fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      serviceInstructions = _serviceInstructionsController.text;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Instructions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                    ),
                  ),
                ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAlternateNumberDialog() async {
    final phoneController = TextEditingController();
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Add Alternate Number',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Okra',
          ),
        ),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'Enter alternate phone number',
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontFamily: 'Okra',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
            prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
          ),
          style: const TextStyle(fontFamily: 'Okra', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontFamily: 'Okra',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a phone number')),
                );
                return;
              }

              try {
                // Get current user profile
                final profileService = ref.read(profileServiceProvider);
                final profile = await profileService.getCurrentUserProfile();

                if (profile != null) {
                  // Update profile with alternate phone
                  final updatedProfile = profile.copyWith(alternatePhone: phone);
                  await profileService.updateProfile(updatedProfile);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Alternate number added successfully!'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                    setState(() {}); // Refresh to show the new number
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add number: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Okra',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAddressCard(Address address) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getAddressTypeIcon(address.addressFor),
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        address.addressFor
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          fontFamily: 'Okra',
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  address.address,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                    fontFamily: 'Okra',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address.area != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    address.area!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                      fontFamily: 'Okra',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingAddressCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.backgroundColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAddressTypeIcon(AddressType addressFor) {
    switch (addressFor) {
      case AddressType.home:
        return Icons.home;
      case AddressType.work:
        return Icons.work;
      default:
        return Icons.location_on;
    }
  }

  Widget _buildAddAddressButton() {
    return GestureDetector(
      onTap: () {
        context.push('/profile/addresses/add');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Add Address',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontFamily: 'Okra',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeServiceSection() {
    final selectedAddOns = ref.watch(selectedAddOnsProvider);
    final serviceAddOns = ref.watch(serviceAddOnsProvider(widget.service.id));

    return serviceAddOns.when(
      data: (addOns) {
        if (addOns.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon section similar to Zomato's grid icon
                  Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.apps,
                      color: AppTheme.textPrimaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Complete your service with',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                  if (selectedAddOns.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${selectedAddOns.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Okra',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Horizontal list of add-ons (show first 4) - Zomato style
              SizedBox(
                height:
                    MediaQuery.of(context).size.width *
                    0.45, // Increased height for better card proportions
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 4),
                  itemCount: addOns.take(4).length,
                  itemBuilder: (context, index) {
                    final addOn = addOns[index];
                    final selectedQuantity = ref
                        .watch(selectedAddOnsProvider.notifier)
                        .getItemQuantity(addOn.id);

                    return Container(
                      width:
                          MediaQuery.of(context).size.width *
                          0.42, // Slightly wider for better content fit
                      margin: EdgeInsets.only(right: index < 3 ? 12 : 0),
                      child: _buildAddOnCard(addOn, selectedQuantity),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Add-ons starting price indicator (Zomato style)
              if (addOns.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Add-ons starting @ ₹${_formatPrice(addOns.map((a) => a.price).reduce((min, price) => price < min ? price : min))} only applied!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                          fontFamily: 'Okra',
                        ),
                      ),
                      const Spacer(),
                      if (selectedAddOns.isNotEmpty)
                        Text(
                          '- ₹${_formatPrice(ref.read(selectedAddOnsProvider.notifier).getTotalAmount())}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                            fontFamily: 'Okra',
                          ),
                        ),
                    ],
                  ),
                ),

              // View More button and selected add-ons summary
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _navigateToAddOnsListing(addOns),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: Text('View More (${addOns.length})'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (selectedAddOns.isNotEmpty)
                    Text(
                      '₹${_formatPrice(ref.read(selectedAddOnsProvider.notifier).getTotalAmount())}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Okra',
                      ),
                    ),
                ],
              ),

              // Selected add-ons list (if any)
              if (selectedAddOns.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Selected Add-ons',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...selectedAddOns.map(
                        (selectedAddOn) =>
                            _buildSelectedAddOnItem(selectedAddOn),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 120,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildAddOnCard(AddOnModel addOn, int selectedQuantity) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: selectedQuantity > 0
            ? Border.all(color: AppTheme.primaryColor, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section with vegetarian indicator
          Stack(
            children: [
              Container(
                height: MediaQuery.of(context).size.width * 0.25,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  color: Colors.grey[100],
                ),
                child: addOn.imageUrl != null && addOn.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: addOn.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.image,
                                color: Colors.grey[400],
                                size: 24,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[100],
                            child: Center(
                              child: Icon(
                                Icons.restaurant_menu,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(
                            Icons.restaurant_menu,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                      ),
              ),
              // Vegetarian indicator (like Zomato)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add-on name
                  Text(
                    addOn.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                      fontFamily: 'Okra',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Price and add button section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Price section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${_formatPrice(addOn.price)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor,
                                fontFamily: 'Okra',
                              ),
                            ),
                            if (addOn.description != null &&
                                addOn.description!.isNotEmpty)
                              Text(
                                'customisable',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontFamily: 'Okra',
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Add/Remove button (Zomato style)
                      selectedQuantity > 0
                          ? Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => ref
                                        .read(selectedAddOnsProvider.notifier)
                                        .removeAddOn(addOn.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.remove,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '$selectedQuantity',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Okra',
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => ref
                                        .read(selectedAddOnsProvider.notifier)
                                        .addAddOn(addOn),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: () => ref
                                  .read(selectedAddOnsProvider.notifier)
                                  .addAddOn(addOn),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.primaryColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'ADD',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Okra',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.add,
                                      color: AppTheme.primaryColor,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAddOnItem(SelectedAddOnModel selectedAddOn) {
    final customData = editableAddOns?[selectedAddOn.id];
    final customText = customData?['customText']?.toString();
    final charCount = customData?['characterCount'] as int?;
    final hasCustomText = customText != null && customText.trim().isNotEmpty;
    final isCustomizable = customData?['isCustomizable'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selectedAddOn.name} x${selectedAddOn.quantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                  ),
                ),
                if (hasCustomText) ...[
                  const SizedBox(height: 2),
                  Text(
                    '"${customText.trim()}"',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondaryColor,
                      fontFamily: 'Okra',
                    ),
                  ),
                ],
                if (charCount != null && charCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$charCount ${_isNumericCustomValue(customText) ? 'units' : 'characters'}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondaryColor,
                      fontFamily: 'Okra',
                    ),
                  ),
                ],
                if (isCustomizable) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () =>
                        _showEditableAddonCustomizationDialog(selectedAddOn.id),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => ref
                    .read(selectedAddOnsProvider.notifier)
                    .removeAddOn(selectedAddOn.id),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, size: 12, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '₹${_formatPrice(selectedAddOn.totalPrice)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
              fontFamily: 'Okra',
            ),
          ),
        ],
      ),
    );
  }

  bool _isNumericCustomValue(String? value) {
    if (value == null) return false;
    return int.tryParse(value.trim()) != null;
  }

  void _navigateToAddOnsListing(List<AddOnModel> addOns) {
    // For now, we'll create a simple bottom sheet
    // Later this can be a dedicated page
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Service Add-ons',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: addOns.length,
                itemBuilder: (context, index) {
                  final addOn = addOns[index];
                  final selectedQuantity = ref
                      .watch(selectedAddOnsProvider.notifier)
                      .getItemQuantity(addOn.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selectedQuantity > 0
                          ? AppTheme.primaryColor.withOpacity(0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedQuantity > 0
                            ? AppTheme.primaryColor
                            : AppTheme.backgroundColor,
                        width: selectedQuantity > 0 ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              addOn.imageUrl != null &&
                                  addOn.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: addOn.imageUrl!,
                                    fit: BoxFit.cover,
                                    width: 60,
                                    height: 60,
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.add_box,
                                      color: AppTheme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.add_box,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                addOn.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: selectedQuantity > 0
                                      ? AppTheme.primaryColor
                                      : AppTheme.textPrimaryColor,
                                  fontFamily: 'Okra',
                                ),
                              ),
                              if (addOn.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  addOn.description!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor,
                                    fontFamily: 'Okra',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                '₹${_formatPrice(addOn.price)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                  fontFamily: 'Okra',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selectedQuantity > 0) ...[
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => ref
                                    .read(selectedAddOnsProvider.notifier)
                                    .removeAddOn(addOn.id),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$selectedQuantity',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Okra',
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => ref
                                    .read(selectedAddOnsProvider.notifier)
                                    .addAddOn(addOn),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          GestureDetector(
                            onTap: () => ref
                                .read(selectedAddOnsProvider.notifier)
                                .addAddOn(addOn),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontFamily: 'Okra',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final selectedAddOns = ref.watch(
                            selectedAddOnsProvider,
                          );
                          final totalAmount = ref
                              .read(selectedAddOnsProvider.notifier)
                              .getTotalAmount();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectedAddOns.isNotEmpty) ...[
                                Text(
                                  '${selectedAddOns.length} item(s) selected',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor,
                                    fontFamily: 'Okra',
                                  ),
                                ),
                                Text(
                                  '₹${_formatPrice(totalAmount)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                    fontFamily: 'Okra',
                                  ),
                                ),
                              ] else
                                const Text(
                                  'No items selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondaryColor,
                                    fontFamily: 'Okra',
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizationSummary() {
    if (widget.customization == null) return const SizedBox.shrink();

    final customization = widget.customization!;
    final hasCustomizations = _hasValidCustomizations(customization);

    if (!hasCustomizations) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Preferences',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_buildCustomizationItems(customization)),
        ],
      ),
    );
  }

  bool _hasValidCustomizations(Map<String, dynamic> customization) {
    return (customization['theme'] != null &&
            customization['theme'] != 'Option') ||
        (customization['venueType'] != null &&
            customization['venueType'] != 'Option') ||
        (customization['serviceEnvironment'] != null &&
            customization['serviceEnvironment'] != 'Option') ||
        (customization['addOns'] != null &&
            customization['addOns'] is List &&
            (customization['addOns'] as List).isNotEmpty) ||
        (customization['placeImage'] != null);
  }

  List<Widget> _buildCustomizationItems(Map<String, dynamic> customization) {
    final items = <Widget>[];

    if (customization['theme'] != null && customization['theme'] != 'Option') {
      items.add(_buildCustomizationItem('Theme', customization['theme']));
    }
    if (customization['venueType'] != null &&
        customization['venueType'] != 'Option') {
      items.add(
        _buildCustomizationItem('Venue Type', customization['venueType']),
      );
    }
    if (customization['serviceEnvironment'] != null &&
        customization['serviceEnvironment'] != 'Option') {
      items.add(
        _buildCustomizationItem(
          'Environment',
          customization['serviceEnvironment'],
        ),
      );
    }
    if (customization['addOns'] != null &&
        customization['addOns'] is List &&
        (customization['addOns'] as List).isNotEmpty) {
      items.add(
        _buildCustomizationItem(
          'Add-ons',
          (customization['addOns'] as List).join(', '),
        ),
      );
    }

    // Add place image if provided
    if (customization['placeImage'] != null &&
        customization['placeImage'] is XFile) {
      items.add(_buildPlaceImageItem(customization['placeImage'] as XFile));
    }

    return items;
  }

  Widget _buildCustomizationItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
                fontFamily: 'Okra',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Okra',
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceImageItem(XFile imageFile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image, color: AppTheme.primaryColor, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Place Image',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Okra',
                ),
              ),
              const Spacer(),
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(imageFile.path),
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Image will be uploaded during booking',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontFamily: 'Okra',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_offer,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Apply Coupon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Spacer(),
              if (isCouponApplied)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.successColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Applied',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successColor,
                          fontFamily: 'Okra',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  onChanged: (value) => couponCode = value.toUpperCase(),
                  enabled: !isCouponApplied,
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    hintStyle: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                      fontFamily: 'Okra',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.backgroundColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isCouponApplied
                            ? AppTheme.successColor
                            : AppTheme.backgroundColor,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppTheme.successColor.withOpacity(0.3),
                      ),
                    ),
                    filled: true,
                    fillColor: isCouponApplied
                        ? AppTheme.successColor.withOpacity(0.05)
                        : AppTheme.backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.local_offer_outlined,
                      color: isCouponApplied
                          ? AppTheme.successColor
                          : AppTheme.textSecondaryColor,
                      size: 20,
                    ),
                  ),
                  style: TextStyle(
                    fontFamily: 'Okra',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCouponApplied
                        ? AppTheme.successColor
                        : AppTheme.textPrimaryColor,
                  ),
                  initialValue: isCouponApplied ? couponCode : '',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isCouponApplied
                      ? _removeCoupon
                      : (isApplyingCoupon ? null : _applyCoupon),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCouponApplied
                        ? Colors.red.shade400
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: isApplyingCoupon
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          isCouponApplied ? 'Remove' : 'Apply',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (isCouponApplied && couponDiscount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.successColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.celebration,
                    color: AppTheme.successColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Congratulations! You saved ₹${_formatPrice(couponDiscount)} with coupon $couponCode',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.successColor,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAvailableCoupons() {
    final servicePrice = _getServicePrice();
    final serviceCouponsAsync = ref.watch(
      serviceCouponsProvider(
        ServiceCouponParams(
          serviceId: widget.service.id,
          orderAmount: servicePrice,
        ),
      ),
    );

    return serviceCouponsAsync.when(
      data: (coupons) {
        if (coupons.isEmpty) {
          return [
            Text(
              'No coupons available for this service',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade600,
                fontFamily: 'Okra',
              ),
            ),
          ];
        }

        return coupons.take(3).map((coupon) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  couponCode = coupon.code;
                });
                _applyCoupon();
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      coupon.code,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      coupon.description ?? coupon.displayDiscount,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: Colors.blue.shade600,
                  ),
                ],
              ),
            ),
          );
        }).toList();
      },
      loading: () => [const CircularProgressIndicator(strokeWidth: 2)],
      error: (error, stack) => [
        Text(
          'Unable to load offers at the moment',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontFamily: 'Okra',
          ),
        ),
      ],
    );
  }

  void _applyCoupon() async {
    if (couponCode.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a coupon code'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() {
      isApplyingCoupon = true;
    });

    try {
      final servicePrice = _getServicePrice();
      final couponRepository = ref.read(couponRepositoryProvider);

      final validatedCoupon = await couponRepository.validateCoupon(
        couponCode: couponCode.trim(),
        serviceId: widget.service.id,
        orderAmount: servicePrice,
      );

      setState(() {
        isApplyingCoupon = false;
        if (validatedCoupon != null) {
          isCouponApplied = true;
          appliedCoupon = validatedCoupon;
          couponDiscount = validatedCoupon.calculateDiscount(servicePrice);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Coupon applied! You saved ₹${_formatPrice(couponDiscount)}',
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Invalid coupon code or not applicable for this service',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        isApplyingCoupon = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating coupon: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _removeCoupon() {
    setState(() {
      isCouponApplied = false;
      couponDiscount = 0.0;
      couponCode = '';
      appliedCoupon = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coupon removed'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildBillDetails() {
    final servicePrice = _getServicePrice();
    final addOnsTotal = _calculateSelectedAddOnsTotal();

    // FIX: Service price from displayOfferPrice/calculatedPrice ALREADY includes all fees (₹19 + 3.54%)
    // Do NOT add fees again to avoid double charging
    // The RPC function calculate_service_listing_price includes: base_price + distance + ₹19 + 3.54%
    final servicePriceWithFeesRaw = servicePrice; // Already includes all fees
    // Apply rounding to ensure prices end with 49 or 99
    final servicePriceWithFees = PriceRounding.applyFinalRounding(servicePriceWithFeesRaw);

    // Calculate original price with fees (for display purposes)
    final originalPrice = widget.service.displayOriginalPrice ?? widget.service.originalPrice ?? servicePrice;
    final originalPriceWithFeesRaw = originalPrice; // Already includes fees from RPC
    final originalPriceWithFees = PriceRounding.applyFinalRounding(originalPriceWithFeesRaw);

    // Add-ons totalPrice already includes transaction fee from service detail screen
    final addOnsPriceWithFees =
        addOnsTotal; // No additional fee calculation needed
    // Total is the exact sum of already-rounded prices — no further rounding
    final totalAmount = servicePriceWithFees + addOnsPriceWithFees - couponDiscount;

    final paymentSplit = _calculateAdvanceAndRemaining(totalAmount);
    final payableAmount = paymentSplit['payableAmount'] ?? 0.0;

    

   
    if (advancePaymentData != null) {
      //('RPC Data: $advancePaymentData');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E7EB), // Figma stroke color
          width: 1,
        ),
      ),
      child: Column(
        spacing: 16,
        children: [
          // Header with summary
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 18, 17, 0),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFF0F0F0), // Light grey border
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_outlined, // Bill icon from Figma
                    color: Colors.black,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Bill Summary section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Okra',
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Incl.all taxes & charges',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Okra',
                          color: Color(0x99000000), // 60% opacity black
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 32),

                // Price section with crossed out original price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        // Crossed out original price
                        if (servicePriceWithFees + addOnsPriceWithFees !=
                            totalAmount)
                          Text(
                            '₹${_formatPrice(servicePriceWithFees + addOnsPriceWithFees)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Okra',
                              color: Color(0x80000000), // 50% opacity black
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Final price
                        Text(
                          '₹${_formatPriceExact(totalAmount)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Savings text
                    if (servicePriceWithFees + addOnsPriceWithFees !=
                        totalAmount)
                      Text(
                        '₹${_formatPrice((servicePriceWithFees + addOnsPriceWithFees) - totalAmount)} Saved',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Okra',
                          color: Color(0xFF569456), // Green color from Figma
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 17),
            child: Divider(
              color: Color(0xFFECEFEE), // Light grey divider
              thickness: 2,
              height: 2,
            ),
          ),

          // Bill breakdown rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Column(
              spacing: 16,
              children: [
                // Item Total row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Item Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Okra',
                        color: Color(0xA6000000), // 65% opacity black
                      ),
                    ),
                    Row(
                      children: [
                        // Crossed out original price
                        if (originalPriceWithFees > servicePriceWithFees) ...[
                          Text(
                            '₹${_formatPrice(originalPriceWithFees)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Okra',
                              color: Color(0x80000000), // 50% opacity black
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Discounted price
                        Text(
                          '₹${_formatPrice(servicePriceWithFees)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Add-ons row
                if (addOnsTotal > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add-ons',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Okra',
                          color: Color(0xA6000000), // 65% opacity black
                        ),
                      ),
                      Row(
                        children: [
                          // Crossed out original add-ons price
                          Text(
                            '₹${_formatPrice(addOnsTotal * 1.2)}', // Assume 20% markup
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Okra',
                              color: Color(0x80000000), // 50% opacity black
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Final add-ons price
                          Text(
                            '₹${_formatAddonPrice(addOnsPriceWithFees)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Okra',
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                // Convenience Fee row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Convenince Fee',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Okra',
                        color: Color(0xA6000000), // 65% opacity black
                      ),
                    ),
                    Row(
                      children: [
                        // Crossed out convenience fee
                        const Text(
                          '₹19',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Okra',
                            color: Color(0x80000000), // 50% opacity black
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Free convenience fee
                        const Text(
                          '₹0',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider before total
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 17),
            child: Divider(
              color: Color(0xFFECEFEE), // Light grey divider
              thickness: 2,
              height: 2,
            ),
          ),

          // To Pay - Advance row
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'To Pay - Advance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: Color(0xFF212427), // Dark grey from Figma
                  ),
                ),
                Text(
                  '₹${_formatPriceExact(payableAmount)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Total Savings container
          Container(
            margin: const EdgeInsets.fromLTRB(17, 0, 17, 18),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(37, 31, 212, 197), // 15% opacity blue background
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Savings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Okra',
                    color: Color(0xFF011B2F), // Dark blue from Figma
                  ),
                ),
                Text(
                  '₹${_formatPrice(_calculateTotalSavings(originalPriceWithFees, servicePriceWithFees, addOnsPriceWithFees, totalAmount))}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: Color(0xFF011B2F), // Dark blue from Figma
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isFree = false,
    bool isDiscount = false,
    double? originalPrice,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
              fontFamily: 'Okra',
              color: isTotal
                  ? AppTheme.textPrimaryColor
                  : AppTheme.textSecondaryColor,
            ),
          ),
          Row(
            children: [
              if (isFree && originalPrice != null) ...[
                Text(
                  '₹${originalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                    decoration: TextDecoration.lineThrough,
                    fontFamily: 'Okra',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'FREE',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                isFree
                    ? '₹0'
                    : (isDiscount
                          ? '-₹${_formatPrice(amount.abs())}'
                          : '₹${_formatPrice(amount)}'),
                style: TextStyle(
                  fontSize: isTotal ? 15 : 14,
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                  color: isTotal
                      ? AppTheme.primaryColor
                      : isDiscount
                      ? AppTheme.successColor
                      : AppTheme.textPrimaryColor,
                  fontFamily: 'Okra',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton() {
    final totalAmount = _getTotalAmount();

    final paymentSplit = _calculateAdvanceAndRemaining(totalAmount);
    final payableAmount = paymentSplit['payableAmount'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show booking details for theater bookings
            if (widget.selectedTimeSlot != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Booking Summary',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                        fontFamily: 'Okra',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Date: ${_getSelectedDate()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                            fontFamily: 'Okra',
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Time: ${_getSelectedTimeRange()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ],
                    ),
                    if (widget.selectedScreen != null ||
                        (widget.selectedTimeSlot != null &&
                            widget.selectedTimeSlot!.screenName != null)) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.movie,
                            size: 14,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Screen: ${_getScreenName()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Payment note
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPaymentInfoText(payableAmount, totalAmount),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CustomButton(
              width: double.infinity,
              text: !isVendorOnline
                  ? 'Vendor Offline - Cannot Proceed'
                  : isProcessing
                  ? 'Processing...'
                  : isLoadingAdvancePayment
                  ? 'Calculating...'
                  : 'Pay ₹${_formatPriceExact(payableAmount)}',
              onPressed: (!isVendorOnline || isProcessing || isLoadingAdvancePayment)
                  ? () {}
                  : _proceedToRazorpay,
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate the total amount using the display prices (same as _buildBillDetails)
  double _getTotalAmount() {
    final servicePrice = _getServicePrice();
    final addOnsTotal = _calculateSelectedAddOnsTotal();
    final servicePriceWithFees = PriceRounding.applyFinalRounding(servicePrice);
    return servicePriceWithFees + addOnsTotal - couponDiscount;
  }

  /// Remaining (after service) = 40% of raw base prices (service offer + addons, before taxes/fees)
  /// e.g. service=3300, addons=75 → (3300+75) × 40% = ₹1,350
  double _calculateRemainingAmount() {
    // Use raw offer price directly — no fee-stripping to avoid rounding error
    final rawServiceBase = widget.service.offerPrice ?? 0.0;

    // Sum raw addon prices from 'price' field (before 3.54% tax was applied)
    double rawAddonsBase = 0.0;
    if (editableAddOns != null) {
      for (final entry in editableAddOns!.entries) {
        final rawPrice = _safeToDouble(entry.value['price']);
        final charCount = entry.value['characterCount'] as int? ?? 1;
        rawAddonsBase += rawPrice * charCount;
      }
    }

    return (rawServiceBase + rawAddonsBase) * 0.40;
  }

  /// Format price with Indian number system WITHOUT rounding (for exact amounts like remaining payment)
  String _formatPriceExact(double price) {
    // Round to nearest integer (no X99 rounding)
    int basePrice = price.round();

    // Format with Indian number system (last 3 digits, then groups of 2)
    String priceStr = basePrice.toString();

    if (priceStr.length <= 3) {
      return priceStr; // No formatting needed for numbers < 1000
    }

    // Split into last 3 digits and the rest
    String lastThree = priceStr.substring(priceStr.length - 3);
    String remaining = priceStr.substring(0, priceStr.length - 3);

    // Add commas every 2 digits from right to left in remaining part
    String formatted = '';
    for (int i = remaining.length - 1; i >= 0; i--) {
      formatted = remaining[i] + formatted;
      if ((remaining.length - i) % 2 == 0 && i > 0) {
        formatted = ',' + formatted;
      }
    }

    return formatted + ',' + lastThree;
  }

  /// Get payment info text for checkout button
  String _getPaymentInfoText(double payableAmount, double totalAmount) {
    // Calculate remaining based on the adjusted payable amount
    // This ensures advance + remaining = total (accounting for waived ₹19 fee)
    final remainingAmount = totalAmount - payableAmount;
    return 'Pay ₹${_formatPriceExact(payableAmount)} now, remaining ₹${_formatPriceExact(remainingAmount)} after service completion';
  }

  Map<String, double> _calculateAdvanceAndRemaining(double totalAmount) {
    // Required business logic: remaining is 40% of raw base values,
    // advance is the rest from displayed total.
    final remainingAmount = _calculateRemainingAmount();
    final payableAmount = totalAmount - remainingAmount;
    return {
      'payableAmount': payableAmount > 0 ? payableAmount : 0.0,
      'remainingAmount': remainingAmount > 0 ? remainingAmount : 0.0,
    };
  }

  /// Creates a JSON-safe copy of selected add-ons for payment metadata.
  /// Runtime-only objects (like `ServiceAddon`) are removed.
  Map<String, Map<String, dynamic>> _serializeSelectedAddOnsForMetadata() {
    if (editableAddOns == null || editableAddOns!.isEmpty) {
      return <String, Map<String, dynamic>>{};
    }

    return editableAddOns!.map((key, value) {
      final sanitized = Map<String, dynamic>.from(value)
        ..remove('addon');
      return MapEntry(key, sanitized);
    });
  }

  /// Get the service price from theater time slot if available, otherwise from service listing
  double _getServicePrice() {
    // If we have theater time slot data, use the slot price
    if (widget.selectedTimeSlot != null) {
      try {
        return widget.selectedTimeSlot!.basePrice;
      } catch (e) {
        //('❌ Error accessing theater time slot basePrice: $e');
        //('❌ Falling back to service listing price');
      }
    }

    // Fallback to service listing prices with safe conversion
    // Use displayOfferPrice which includes calculated distance-based pricing
    double? offerPrice;
    double? originalPrice;

    try {
      // Use displayOfferPrice to get calculated price if available
      offerPrice = widget.service.displayOfferPrice ?? widget.service.offerPrice;
      //('💰 Using display offer price: $offerPrice (calculated: ${widget.service.calculatedPrice}, base: ${widget.service.offerPrice})');
    } catch (e) {
      //('⚠️ Error accessing service offerPrice: $e');
      offerPrice = null;
    }

    try {
      originalPrice = widget.service.displayOriginalPrice ?? widget.service.originalPrice;
    } catch (e) {
      //('⚠️ Error accessing service originalPrice: $e');
      originalPrice = null;
    }

    final price = offerPrice ?? originalPrice ?? 0.0;
    if (price <= 0) return 0.0;
    if (_usesPrecalculatedServicePrices()) return price;

    // For non-precalculated values: apply listing pricing formula
    // (base + 3.54% + 19), then final rounding.
    final withFees = price + 19.0 + (price * 0.0354);
    return PriceRounding.applyFinalRounding(withFees);
  }

  double _getOriginalServicePriceForDisplay() {
    final originalPrice =
        widget.service.displayOriginalPrice ?? widget.service.originalPrice;
    if (originalPrice == null || originalPrice <= 0) return 0.0;
    if (_usesPrecalculatedServicePrices()) return originalPrice;

    final withFees = originalPrice + 19.0 + (originalPrice * 0.0354);
    return PriceRounding.applyFinalRounding(withFees);
  }

  bool _usesPrecalculatedServicePrices() {
    return widget.service.calculatedPrice != null ||
        widget.service.isPriceAdjusted == true;
  }

  /// Calculate total savings based on original price with fees vs current discounted price with fees
  double _calculateTotalSavings(double originalPriceWithFees, double servicePriceWithFees, double addOnsPriceWithFees, double totalAmount) {
    // Calculate convenience fee that was waived (₹19 + 3.54% tax on ₹19)
    final convenienceFee = 19.0;
    final convenienceFeeWithTax = convenienceFee + (convenienceFee * 0.0354);

    // If there's no discount (original price equals current price), show coupon savings + convenience fee waived
    if (originalPriceWithFees <= servicePriceWithFees) {
      return couponDiscount + convenienceFeeWithTax; // Coupon savings + convenience fee waived
    }

    // Total savings = (original price - discounted price) + coupon discount + convenience fee waived
    // This shows savings from the original price to the current discounted price
    final priceDiscount = originalPriceWithFees - servicePriceWithFees;
    final totalSavings = priceDiscount + couponDiscount + convenienceFeeWithTax;

    return totalSavings > 0 ? totalSavings : 0;
  }

  /// Get the selected date for display
  String _getSelectedDate() {
    // Try widget.selectedDate first
    String? dateToUse = widget.selectedDate;

    // If not available, try customization data
    if ((dateToUse!.isEmpty) &&
        widget.customization != null &&
        widget.customization!['date'] != null) {
      final customDate = widget.customization!['date'] as String;
      if (customDate != 'Select Date') {
        dateToUse = customDate;
      }
    }

    if (dateToUse.isNotEmpty) {
      // Parse and format the date nicely
      try {
        DateTime date;

        // Handle different date formats
        if (dateToUse.contains('-')) {
          // ISO format or yyyy-MM-dd format
          date = DateTime.parse(dateToUse);
        } else if (dateToUse.contains('/')) {
          // dd/MM/yyyy or MM/dd/yyyy format
          final parts = dateToUse.split('/');
          if (parts.length == 3) {
            // Assume dd/MM/yyyy format
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            date = DateTime(year, month, day);
          } else {
            throw FormatException('Invalid date format');
          }
        } else {
          throw FormatException('Unknown date format');
        }

        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        return '$day/$month/${date.year}';
      } catch (e) {
        //('❌ Error parsing date "$dateToUse": $e');
        // Return the original string if parsing fails
        return dateToUse;
      }
    }

    // Fallback to tomorrow's date for service booking
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final day = tomorrow.day.toString().padLeft(2, '0');
    final month = tomorrow.month.toString().padLeft(2, '0');
    return '$day/$month/${tomorrow.year}';
  }

  /// Get the selected time range for display
  String _getSelectedTimeRange() {
    // Check theater time slot first
    if (widget.selectedTimeSlot != null) {
      return '${widget.selectedTimeSlot!.startTime} - ${widget.selectedTimeSlot!.endTime}';
    }

    // Check customization data for regular services
    if (widget.customization != null && widget.customization!['time'] != null) {
      final selectedTime = widget.customization!['time'] as String;
      if (selectedTime != 'Select Time') {
        return selectedTime;
      }
    }

    // For regular services, show a more appropriate default time
    return 'Morning (9:00 AM - 12:00 PM)';
  }

  /// Get the screen name for display
  String _getScreenName() {
    if (widget.selectedScreen != null) {
      return widget.selectedScreen!.screenName;
    } else if (widget.selectedTimeSlot != null &&
        widget.selectedTimeSlot!.screenName != null) {
      return widget.selectedTimeSlot!.screenName!;
    }

    // Fallback to generic screen
    return 'Screen';
  }

  String _formatPrice(double price) {
    // Handle edge cases
    if (price <= 0) {
      return '0';
    }

    // Round to nearest integer first
    int basePrice = price.round();

    // Get last two digits
    int lastTwoDigits = basePrice % 100;

    // Apply "ending with 99" logic (matches PriceRounding.applyFinalRounding)
    if (lastTwoDigits == 99) {
      // Already ends with 99, keep it
    } else {
      // Always round UP to next X99
      int currentHundred = basePrice ~/ 100;
      basePrice = (currentHundred + 1) * 100 - 1;
    }

    // Format with Indian number system (last 3 digits, then groups of 2)
    String priceStr = basePrice.toString();

    if (priceStr.length <= 3) {
      return priceStr; // No formatting needed for numbers < 1000
    }

    // Split into last 3 digits and the rest
    String lastThree = priceStr.substring(priceStr.length - 3);
    String remaining = priceStr.substring(0, priceStr.length - 3);

    // Add commas every 2 digits from right to left in remaining part
    String formatted = '';
    for (int i = remaining.length - 1; i >= 0; i--) {
      formatted = remaining[i] + formatted;
      if ((remaining.length - i) % 2 == 0 && i > 0) {
        formatted = ',' + formatted;
      }
    }

    return formatted + ',' + lastThree;
  }

  /// Format add-on price with nearest X9 rounding (e.g. ₹77.66 → 79)
  String _formatAddonPrice(double price) {
    if (price <= 0) return '0';

    // Round to nearest value ending in 9
    int base = price.round();
    if (base % 10 != 9) {
      final nLower = (base + 1) ~/ 10;
      final lower = nLower * 10 - 1;
      final upper = (nLower + 1) * 10 - 1;
      base = (base - lower).abs() < (base - upper).abs() ? lower : upper;
    }

    // Format with Indian number system
    String priceStr = base.toString();
    if (priceStr.length <= 3) return priceStr;

    String lastThree = priceStr.substring(priceStr.length - 3);
    String remaining = priceStr.substring(0, priceStr.length - 3);
    String formatted = '';
    for (int i = remaining.length - 1; i >= 0; i--) {
      formatted = '${remaining[i]}$formatted';
      if ((remaining.length - i) % 2 == 0 && i > 0) {
        formatted = ',$formatted';
      }
    }
    return '$formatted,$lastThree';
  }

  int _roundAddonPriceToNearest9(double price) {
    if (price <= 0) return 0;
    int base = price.round();
    if (base % 10 == 9) return base;
    final nLower = (base + 1) ~/ 10;
    final lower = nLower * 10 - 1;
    final upper = (nLower + 1) * 10 - 1;
    return (base - lower).abs() < (base - upper).abs() ? lower : upper;
  }

  void _showAddressSelector(AsyncValue<List<Address>> userAddresses) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Okra',
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      context.pop();
                      context.push('/profile/addresses/add').then((_) {
                        ref.invalidate(addr.addressesProvider);
                      });
                    },
                    icon: Icon(
                      Icons.add,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                    label: Text(
                      'Add New',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: userAddresses.when(
                data: (addresses) {
                  if (addresses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 48,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No addresses found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondaryColor,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: addresses.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      final isSelected = selectedAddressId == address.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedAddressId = address.id;
                          });
                          ref.read(addr.selectedAddressProvider.notifier).state =
                              address;
                          context.pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.05)
                                : AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.backgroundColor,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            address.addressFor
                                                .toString()
                                                .split('.')
                                                .last
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryColor,
                                              fontFamily: 'Okra',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      address.address,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Okra',
                                        color: isSelected
                                            ? AppTheme.textPrimaryColor
                                            : AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                    if (address.area != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        address.area!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondaryColor,
                                          fontFamily: 'Okra',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Error loading addresses',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                          fontFamily: 'Okra',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _proceedToRazorpay() async {
    if (selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select an address'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // Check if user is guest before proceeding to payment
    final isGuest = await ref.read(isGuestUserProvider.future);
    if (isGuest) {
      // Navigate to login screen for guest users
      if (!mounted) return;
      context.go(AppConstants.loginRoute);
      return;
    }

    setState(() {
      isProcessing = true;
    });

    // Check if running on iOS Simulator (Razorpay doesn't work on iOS Simulator)
    if (Platform.isIOS && !kReleaseMode) {
      // In debug/profile mode on iOS, show warning about simulator limitation
      //('⚠️ WARNING: You are running on iOS Simulator. Razorpay payment UI may not appear.');
      //('⚠️ For testing Razorpay, please use:');
      //('   1. A real iOS device (iPhone/iPad)');
      //('   2. An Android emulator');
      //('   3. A real Android device');
    }

    try {
      // Get current user
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Verify the selected address exists
      final userAddresses = await ref.read(addr.addressesProvider.future);
      final addressExists = userAddresses.any(
        (addr) => addr.id == selectedAddressId,
      );
      if (!addressExists) {
        throw Exception('Selected address not found');
      }

      // Get customer details from user profile/auth with safe fallbacks
      final userProfile = ref.read(currentUserProfileProvider).asData?.value;
      final customerName =
          (userProfile?.fullName ?? '').trim().isNotEmpty
          ? (userProfile!.fullName ?? '').trim()
          : ((currentUser.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
                ? (currentUser.userMetadata?['full_name'] as String).trim()
                : ((currentUser.userMetadata?['name'] as String?)?.trim().isNotEmpty == true
                      ? (currentUser.userMetadata?['name'] as String).trim()
                      : ((currentUser.email ?? '').trim().isNotEmpty
                            ? (currentUser.email!.split('@').first)
                            : 'Customer')));
      final customerPhone = userProfile?.phoneNumber ?? '';
      final customerEmail =
          (userProfile?.email ?? '').trim().isNotEmpty
          ? (userProfile!.email!).trim()
          : ((currentUser.email ?? '').trim().isNotEmpty
                ? currentUser.email!.trim()
                : ((currentUser.userMetadata?['email'] as String?)?.trim().isNotEmpty == true
                      ? (currentUser.userMetadata?['email'] as String).trim()
                      : '${currentUser.id}@sylonow.local'));

      if (customerPhone.isEmpty) {
        setState(() {
          isProcessing = false;
        });
        // Show dialog to add phone number
        await _showAddPhoneNumberDialog();
        return;
      }

      // Calculate total amount
      final totalAmount = _getTotalAmount();
      // Determine booking date and time based on theater data if available
      DateTime bookingDate;
      String? selectedDateStr;
      String? selectedTimeSlotStr;

      if (widget.selectedTimeSlot != null && widget.selectedDate != null) {
        // Use theater-specific date
        bookingDate = DateTime.parse(widget.selectedDate!);
        selectedDateStr = widget.selectedDate;
        selectedTimeSlotStr =
            '${widget.selectedTimeSlot!.startTime} - ${widget.selectedTimeSlot!.endTime}';
      } else {
        // Extract date from customization data first
        if (widget.customization != null &&
            widget.customization!['date'] != null) {
          final customDate = widget.customization!['date'] as String;
          if (customDate != 'Select Date' && customDate.isNotEmpty) {
            try {
              // Parse date from dd/MM/yyyy format
              final parts = customDate.split('/');
              if (parts.length == 3) {
                bookingDate = DateTime(
                  int.parse(parts[2]), // year
                  int.parse(parts[1]), // month
                  int.parse(parts[0]), // day
                );
                selectedDateStr = customDate;
              } else {
                throw FormatException('Invalid date format');
              }
            } catch (e) {
              // Fallback to tomorrow
              bookingDate = DateTime.now().add(const Duration(days: 1));
              selectedDateStr =
                  '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';
            }
          } else {
            // Fallback to tomorrow if no valid date selected
            bookingDate = DateTime.now().add(const Duration(days: 1));
            selectedDateStr =
                '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';
          }
        } else {
          // Fallback to tomorrow if no customization data
          bookingDate = DateTime.now().add(const Duration(days: 1));
          selectedDateStr =
              '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';
        }

        // Extract time from customization data
        if (widget.customization != null &&
            widget.customization!['time'] != null) {
          final selectedTime = widget.customization!['time'] as String;
          if (selectedTime != 'Select Time' && selectedTime.isNotEmpty) {
            selectedTimeSlotStr = selectedTime;
          } else {
            selectedTimeSlotStr = 'TBD';
          }
        } else {
          selectedTimeSlotStr = 'TBD';
        }
      }

      // Determine if this is a theater booking or regular service booking
      if (widget.selectedTimeSlot != null) {
        throw Exception(
          'Theater bookings should be handled through theater booking flow, not service orders',
        );
      }

      // VENDOR ONLINE VALIDATION: Check if vendor is still online before payment
      // This prevents bookings when vendor goes offline during the booking flow
      final vendorOnlineCheck = await Supabase.instance.client
          .from('vendors')
          .select('is_online, business_name')
          .eq('id', widget.service.vendorId ?? '')
          .maybeSingle();

      if (vendorOnlineCheck == null) {
        throw Exception('Vendor not found. Please try again later.');
      }

      final isVendorOnline = vendorOnlineCheck['is_online'] as bool? ?? false;
      if (!isVendorOnline) {
        if (!mounted) return;
        setState(() {
          isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${vendorOnlineCheck['business_name'] ?? 'This Screen'} is currently offline. Please try another service.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        return;
      }

      // Calculate payment amounts exactly as shown in bill summary.
      final paymentSplit = _calculateAdvanceAndRemaining(totalAmount);
      final payableAmount = paymentSplit['payableAmount'] ?? 0.0;
      final remainingAmount = paymentSplit['remainingAmount'] ?? 0.0;
      final metadataAddOns = _serializeSelectedAddOnsForMetadata();

      // Extract customer details from customization data
      final customization = widget.customization ?? <String, dynamic>{};
      final customerAge = customization['customerAge'] as int?;
      final occasion = customization['occasion'] as String?;
      final orderCustomerName =
          customization['customerName'] as String? ??
          customerName;

      // PAYMENT FIRST APPROACH: Initialize Razorpay and process payment BEFORE creating order
      //('💳 Initiating payment: ₹$payableAmount');

      // Initialize Razorpay service
      final paymentRepository = ref.read(paymentRepositoryProvider);
      final orderRepository = ref.read(orderRepositoryProvider);
      final razorpayService = RazorpayService(
        paymentRepository,
        orderRepository,
      );

      // Create a temporary booking reference ID for payment tracking
      final tempBookingRef = 'TEMP_${DateTime.now().millisecondsSinceEpoch}';

      // Process payment WITHOUT an order ID (will create order after payment success)
      final paymentResult = await razorpayService.processPaymentWithCallback(
        userId: currentUser.id,
        vendorId: widget.service.vendorId ?? '',
        amount: payableAmount,
        customerName: orderCustomerName,
        customerEmail: customerEmail,
        customerPhone:
            currentUser.userMetadata?['phone'] ?? currentUser.phone ?? '',
        metadata: {
          'temp_booking_ref': tempBookingRef,
          'service_id': widget.service.id,
          'service_name': widget.service.name,
          'total_amount': totalAmount,
          'advance_amount': payableAmount,
          'remaining_amount': remainingAmount,
          'booking_date': selectedDateStr,
          'booking_time': selectedTimeSlotStr,
          'address_id': selectedAddressId,
          'coupon_code': isCouponApplied ? couponCode : null,
          'coupon_discount': couponDiscount,
          'place_image': widget.customization?['placeImage'] != null
              ? 'pending_upload'
              : null,
          'selected_addons': metadataAddOns,
          'customer_age': customerAge,
          'occasion': occasion,
        },
        onPaymentSuccess: (paymentTransactionId, razorpayPaymentId) async {
          // Payment succeeded! Now create the order
          //('✅ Payment completed: $razorpayPaymentId');

          try {
            // Get order creation notifier
            final orderCreationNotifier = ref.read(orderCreationProvider.notifier);

            // Upload place image and banner image if provided
            final imageUploadService = ImageUploadService();
            final customization = widget.customization ?? <String, dynamic>{};

            String? placeImageUrl;
            final placeImageFile = customization['placeImage'] as XFile?;
            if (placeImageFile != null) {
              placeImageUrl = await imageUploadService.uploadPlaceImage(
                imageFile: placeImageFile,
                userId: currentUser.id,
              );
            }

            String? bannerImageUrl;
            final bannerImageFile = customization['bannerImage'] as XFile?;
            if (bannerImageFile != null) {
              bannerImageUrl = await imageUploadService.uploadPlaceImage(
                imageFile: bannerImageFile,
                userId: currentUser.id,
              );
            }

            final bannerText = customization['bannerText'] as String?;

            // Create the order NOW that payment is confirmed
            // Build addOns from editableAddOns so customisation_input is included
            final addOnsData = editableAddOns?.entries.map((entry) {
              final addonId = entry.key;
              final data = entry.value;
              final charCount = data['characterCount'] as int? ?? 1;
              final unitPrice = _safeToDouble(data['price']);
              final customText = data['customText'] as String?;
              return {
                'add_on_id': addonId,
                'quantity': 1,
                'price_at_booking': unitPrice * charCount,
                if (customText != null && customText.isNotEmpty)
                  'customisation_input': customText,
              };
            }).toList() ?? [];

            final order = await orderCreationNotifier.createOrder(
              userId: currentUser.id,
              vendorId: widget.service.vendorId ?? '',
              customerName: orderCustomerName,
              serviceListingId: widget.service.id,
              serviceTitle: widget.service.name,
              bookingDate: bookingDate,
              totalAmount: totalAmount,
              advanceAmount: payableAmount,
              remainingAmount: remainingAmount,
              customerPhone: currentUser.userMetadata?['phone'] ?? currentUser.phone,
              customerEmail: currentUser.email,
              serviceDescription: widget.service.description,
              bookingTime: selectedTimeSlotStr,
              specialRequirements: serviceInstructions.isNotEmpty ? serviceInstructions : null,
              addressId: selectedAddressId,
              placeImageUrl: placeImageUrl,
              bannerImage: bannerImageUrl,
              age: customerAge,
              occasion: occasion,
              addOns: addOnsData.isNotEmpty ? addOnsData : null,
              customisationInput: bannerText?.isNotEmpty == true ? bannerText : null,
            );

            //('✅ Order created: ${order.id}');

            // Link payment transaction to the created order
            final paymentRepository = ref.read(paymentRepositoryProvider);
            await paymentRepository.updatePaymentStatus(
              paymentId: paymentTransactionId,
              status: 'completed', // Already completed, just adding order ID
              orderId: order.id,
            );

            // Update order payment status
            final orderRepository = ref.read(orderRepositoryProvider);
            await orderRepository.updateOrderPayment(
              orderId: order.id,
              paymentStatus: 'advance_paid',
            );

            // Navigate to booking confirmation or success screen
            if (mounted) {
              context.go(
                '/booking-success/${order.id}',
                extra: {
                  'service': widget.service,
                  'advanceAmount': order.advanceAmount,
                  'remainingAmount': order.remainingAmount,
                  'orderId': order.id,
                  'selectedDate': widget.selectedDate,
                  'selectedTimeSlot': widget.selectedTimeSlot != null
                      ? '${widget.selectedTimeSlot!.startTime} - ${widget.selectedTimeSlot!.endTime}'
                      : null,
                },
              );
            }
          } catch (e) {
            //('❌ Error creating order: $e');

            // Check if error is due to vendor being offline
            final errorMessage = e.toString().toLowerCase();
            final isVendorOfflineError = errorMessage.contains('vendor') &&
                                        (errorMessage.contains('offline') ||
                                         errorMessage.contains('not accepting') ||
                                         errorMessage.contains('currently offline'));

            if (mounted) {
              if (isVendorOfflineError) {
                // Show specific vendor offline dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Booking Failed')),
                      ],
                    ),
                    content: const Text(
                      'The vendor has gone offline and cannot accept new bookings.\n\nYour payment was successful and will be refunded within 5-7 business days.\n\nPlease try booking with another vendor.',
                      style: TextStyle(fontSize: 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          context.pop(); // Go back to previous screen
                        },
                        child: const Text('OK', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                );
              } else {
                // Generic order creation error
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Payment successful but booking could not be completed. Please contact support.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 10),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            }
          }
        },
        onPaymentFailure: (error) {
          // Payment failed - no order created
          //('❌ Payment failed: $error');

          // Reset processing state
          if (mounted) {
            setState(() {
              isProcessing = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment failed: $error'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        },
      );

      // NOTE: Do NOT set isProcessing to false here!
      // Payment is async - it will be handled by callbacks
      // isProcessing will be set to false in the callbacks

      if (!paymentResult.isSuccess) {
        // Only set to false if payment failed to initiate
        setState(() {
          isProcessing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to initiate payment: ${paymentResult.message}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        //('💳 Razorpay payment gateway opened - waiting for user action');
      }
    } catch (e) {
      //('❌ [CHECKOUT] ERROR: Failed to initiate payment');
      //('❌ [CHECKOUT] Error type: ${e.runtimeType}');
      //('❌ [CHECKOUT] Error message: $e');
      //('❌ [CHECKOUT] Full error details: ${e.toString()}');

      if (mounted) {
        setState(() {
          isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate payment: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Widget _buildCancellationPolicy() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancellation Policy',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showCancellationPolicyDialog(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
            child: Text(
              'View Cancellation & Refund Policy',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                fontFamily: 'Okra',
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancellationPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cancellation & Refund Policy',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Okra',
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Refunds are subject to the time of cancellation before the scheduled service:',
                  style: TextStyle(
                    fontFamily: 'Okra',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRefundTable(),
                const SizedBox(height: 16),
                const Text(
                  'Additional Terms:',
                  style: TextStyle(
                    fontFamily: 'Okra',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRefundTerms(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontFamily: 'Okra',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRefundTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Time Before Service',
                    style: TextStyle(
                      fontFamily: 'Okra',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Refund Amount',
                    style: TextStyle(
                      fontFamily: 'Okra',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildTableRow('More than 24 Hours', '50%'),
          _buildTableRow('24 to 12 Hours', '30%'),
          _buildTableRow('12 to 6 Hours', '17%'),
          _buildTableRow('Less than 6 Hours', 'No Refund'),
        ],
      ),
    );
  }

  Widget _buildTableRow(String time, String refundAmount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              time,
              style: const TextStyle(fontFamily: 'Okra', fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              refundAmount,
              style: const TextStyle(fontFamily: 'Okra', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundTerms() {
    const terms = [
      '• Refunds will be processed within 5-7 working days.',
      '• Refund will be credited to the original payment method used during booking.',
      '• Service charges and transaction fees are non-refundable.',
      '• In case of any disputes, the decision of Sylonow management will be final.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: terms
          .map(
            (term) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                term,
                style: const TextStyle(
                  fontFamily: 'Okra',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /// Show dialog to add phone number to user profile
  Future<void> _showAddPhoneNumberDialog() async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.phone, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Text(
                'Add Phone Number',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Okra',
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please add your phone number to continue with the booking.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                    fontFamily: 'Okra',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter 10-digit mobile number',
                    prefixIcon: const Icon(Icons.phone_android),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.length != 10) {
                      return 'Phone number must be 10 digits';
                    }
                    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                      return 'Please enter only numbers';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontFamily: 'Okra',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontFamily: 'Okra'),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // Save phone number to Supabase
      final phoneNumber = phoneController.text.trim();
      await _savePhoneNumberToProfile(phoneNumber);
    }
  }

  /// Save phone number to user profile in Supabase
  Future<void> _savePhoneNumberToProfile(String phoneNumber) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Update user profile in Supabase
      await Supabase.instance.client
          .from('user_profiles')
          .update({'phone_number': phoneNumber})
          .eq('auth_user_id', user.id);

      // Refresh the user profile provider
      ref.invalidate(currentUserProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Phone number added successfully!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

      //('✅ Phone number saved to profile: $phoneNumber');
    } catch (e) {
      //('❌ Error saving phone number: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to save phone number. Please try again.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  /// Fetch vendor GST status from vendor_private_details table
  Future<void> _loadVendorGstStatus() async {
    if (widget.service.vendorId == null) return;

    setState(() {
      isLoadingVendorGst = true;
    });

    try {
      // Fetch vendor GST details from vendor_private_details table
      final response = await Supabase.instance.client
          .from('vendor_private_details')
          .select('gst_number')
          .eq('vendor_id', widget.service.vendorId!)
          .maybeSingle();

      if (mounted) {
        setState(() {
          // Vendor has GST if gst_number is not null and not empty
          vendorHasGst =
              response != null &&
              response['gst_number'] != null &&
              response['gst_number'].toString().trim().isNotEmpty;
          isLoadingVendorGst = false;
        });
      }
    } catch (e) {
      // If there's an error or no GST data found, assume no GST
      if (mounted) {
        setState(() {
          vendorHasGst = false;
          isLoadingVendorGst = false;
        });
      }
      //('Error loading vendor GST status: $e');
    }
  }

  /// Calculate advance payment using Supabase RPC function
  Future<void> _calculateAdvancePayment() async {
    if (widget.service.vendorId == null) return;

    setState(() {
      isLoadingAdvancePayment = true;
    });

    try {
      final servicePrice = _getServicePrice();
      final addOnsTotal =
          _calculateSelectedAddOnsRawTotal(); // Use raw total for RPC

      // Extract base service price (without fees) for RPC
      // displayOfferPrice includes: base + ₹19 + (base * 0.0354)
      // So: servicePrice = base * 1.0354 + 19
      // Therefore: base = (servicePrice - 19) / 1.0354
      final baseServicePrice = (servicePrice - 19.0) / 1.0354;

      // Call the Supabase RPC function with base price (RPC will add fees)
      final response = await Supabase.instance.client.rpc(
        'calculate_advance_payment',
        params: {
          'p_vendor_id': widget.service.vendorId!,
          'p_service_discounted_price': baseServicePrice,
          'p_addons_discounted_price': addOnsTotal,
        },
      );

      if (mounted) {
        setState(() {
          advancePaymentData = response as Map<String, dynamic>;
          isLoadingAdvancePayment = false;
        });
       
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          advancePaymentData = null;
          isLoadingAdvancePayment = false;
        });
      }
      //('Error calculating advance payment: $e');
    }
  }

  @override
  void dispose() {
    _serviceInstructionsController.dispose();
    _vendorStatusCheckTimer?.cancel();
    super.dispose();
  }
}
