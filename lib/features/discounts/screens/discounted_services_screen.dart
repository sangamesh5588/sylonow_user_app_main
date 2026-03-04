import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/price_calculator.dart';
import '../../home/models/service_listing_model.dart';
import '../../home/providers/home_providers.dart';

class DiscountedServicesScreen extends ConsumerWidget {
  const DiscountedServicesScreen({super.key});

  static const String routeName = '/discounted-services';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredServicesState = ref.watch(featuredServicesProvider);

    // Debug logging
    print('🔍 Discounted Services Screen - Build called');
    print('🔍 Services count: ${featuredServicesState.services.length}');
    print('🔍 Has more: ${featuredServicesState.hasMore}');
    print('🔍 Current page: ${featuredServicesState.page}');

    // Log each service
    for (var i = 0; i < featuredServicesState.services.length; i++) {
      final service = featuredServicesState.services[i];
      print('🔍 Service $i: ${service.name}');
      print('   - Original: ${service.displayOriginalPrice}');
      print('   - Offer: ${service.displayOfferPrice}');
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Super Saver Deals',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Okra',
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'DEALS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Okra',
              ),
            ),
          ),
        ],
      ),
      body: featuredServicesState.services.isEmpty
          ? _buildLoadingState()
          : _buildDiscountedServicesList(featuredServicesState.services),
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscountedServicesList(List<ServiceListingModel> allServices) {
    print('🔍 _buildDiscountedServicesList called with ${allServices.length} services');

    // Filter services with ANY discount (not just 50%+)
    final discountedServices = allServices.where((service) {
      print('🔍 Checking service: ${service.name}');
      print('   - displayOfferPrice: ${service.displayOfferPrice}');
      print('   - displayOriginalPrice: ${service.displayOriginalPrice}');

      if (service.displayOfferPrice == null || service.displayOriginalPrice == null) {
        print('   ❌ Skipped - missing price data');
        return false;
      }
      final discountPercentage = _calculateDiscountPercentage(service);
      print('   - Discount: ${discountPercentage.toStringAsFixed(1)}%');
      final hasDiscount = discountPercentage > 0;
      print('   ${hasDiscount ? "✅" : "❌"} Include: $hasDiscount');
      return hasDiscount; // Show any service with discount
    }).toList();

    print('🔍 Filtered to ${discountedServices.length} discounted services');

    if (discountedServices.isEmpty) {
      print('🔍 No discounted services - showing empty state');
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: discountedServices.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header with count
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${discountedServices.length} Amazing Deals Found!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Okra',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Limited time offers with amazing discounts',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Okra',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        } else {
          // Service cards
          final serviceIndex = index - 1;
          final service = discountedServices[serviceIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildDiscountedServiceCard(service),
          );
        }
      },
    );
  }

  Widget _buildDiscountedServiceCard(ServiceListingModel service) {
    final discountPercentage = _calculateDiscountPercentage(service);
    
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          context.push(
            '/service/${service.id}',
            extra: {
              'serviceName': service.name,
              'price': service.displayOfferPrice != null
                  ? PriceCalculator.formatPriceAsInt(
                      service.calculatedPrice != null ||
                              service.isPriceAdjusted == true
                          ? service.displayOfferPrice!
                          : PriceCalculator.calculateTotalPriceWithTaxes(
                              service.displayOfferPrice!,
                            ),
                    )
                  : service.displayOriginalPrice != null
                  ? PriceCalculator.formatPriceAsInt(
                      service.calculatedPrice != null ||
                              service.isPriceAdjusted == true
                          ? service.displayOriginalPrice!
                          : PriceCalculator.calculateTotalPriceWithTaxes(
                              service.displayOriginalPrice!,
                            ),
                    )
                  : null,
              'rating': (service.rating ?? 4.9).toStringAsFixed(1),
              'reviewCount': service.reviewsCount ?? 102,
            },
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Main content column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Large Service Image with discount overlay
                  Stack(
                    children: [
                      // Main Image
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: service.image ?? '',
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Discount overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                const Color.fromARGB(255, 8, 8, 8).withOpacity(0.7),
                                const Color.fromARGB(0, 236, 231, 231),
                              ],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                            decoration: BoxDecoration(
                              // color: const Color.fromARGB(103, 0, 0, 0).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Flat ${discountPercentage.round()}% OFF',
                              style: const TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Okra',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Service Details Section
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Service Name (no rating badge here anymore)
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Service Description
                        Text(
                          service.description ?? 'No description available',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Okra',
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Price Section with background highlight - show both discounted and original price
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.1), // Low opacity at top
                                Colors.white.withOpacity(0.8), // High opacity at bottom
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Original price (strikethrough) if different from discounted price
                                  if (service.displayOfferPrice != null && service.displayOriginalPrice != null && service.displayOfferPrice != service.displayOriginalPrice) ...[
                                    Text(
                                      PriceCalculator.formatPriceAsInt(
                                        service.calculatedPrice != null ||
                                                service.isPriceAdjusted == true
                                            ? service.displayOriginalPrice!
                                            : PriceCalculator.calculateTotalPriceWithTaxes(
                                                service.displayOriginalPrice!,
                                              ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        fontFamily: 'Okra',
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  // Discounted price (masked)
                                  Text(
                                    service.displayOfferPrice != null
                                        ? _maskPrice(
                                            service.calculatedPrice != null ||
                                                    service.isPriceAdjusted ==
                                                        true
                                                ? service.displayOfferPrice!
                                                : PriceCalculator.calculateTotalPriceWithTaxes(
                                                    service.displayOfferPrice!,
                                                  ),
                                          )
                                        : service.displayOriginalPrice != null
                                            ? _maskPrice(
                                                service.calculatedPrice !=
                                                            null ||
                                                        service
                                                                .isPriceAdjusted ==
                                                            true
                                                    ? service.displayOriginalPrice!
                                                    : PriceCalculator.calculateTotalPriceWithTaxes(
                                                        service.displayOriginalPrice!,
                                                      ),
                                              )
                                            : 'Price on request',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Okra',
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              // Small text indicating tap to reveal
                              Text(
                                'tap to reveal price',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Okra',
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Rating badge positioned at bottom-right corner
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (service.rating ?? 3.7).toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Okra',
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Deals Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontFamily: 'Okra',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for amazing discounts!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontFamily: 'Okra',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate discount percentage
  double _calculateDiscountPercentage(ServiceListingModel service) {
    if (service.displayOfferPrice == null || service.displayOriginalPrice == null) {
      return 0.0;
    }

    final originalPrice = service.displayOriginalPrice!;
    final offerPrice = service.displayOfferPrice!;

    if (originalPrice <= offerPrice) {
      return 0.0;
    }

    return ((originalPrice - offerPrice) / originalPrice) * 100;
  }

  /// Mask price to show first digits and mask last digits with X's
  String _maskPrice(double price) {
    final priceString = price.toStringAsFixed(0); // Convert to string without decimals
    final length = priceString.length;

    if (length <= 2) {
      return priceString; // Don't mask if 2 digits or less
    } else if (length == 3) {
      return '${priceString[0]}XX'; // Show first digit, mask last 2
    } else if (length == 4) {
      return '${priceString.substring(0, 2)}XX'; // Show first 2 digits, mask last 2
    } else {
      // For 5+ digits, show first digits and mask last 3
      final visibleDigits = length - 3;
      return '${priceString.substring(0, visibleDigits)}XXX';
    }
  }
}
