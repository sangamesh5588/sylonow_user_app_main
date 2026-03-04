import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/core/utils/price_calculator.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';
import 'package:sylonow_user/features/wishlist/models/wishlist_model.dart';
import 'package:sylonow_user/features/wishlist/providers/wishlist_providers.dart';

class WishlistScreen extends ConsumerWidget {
  static const String routeName = '/wishlist';

  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Wishlist',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Okra',
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: wishlistAsync.when(
        data: (wishlist) {
          if (wishlist.isEmpty) {
            return _buildEmptyWishlist(context);
          }
          return _buildWishlistList(wishlist, ref);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Failed to load wishlist',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: 'Okra',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontFamily: 'Okra',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(wishlistNotifierProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWishlist(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your wishlist is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding services to your wishlist by tapping the heart icon',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: 'Okra',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => GoRouter.of(context).go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Explore Services',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Okra',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistList(List<WishlistWithService> wishlist, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ListView.separated(
        itemCount: wishlist.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final wishlistItem = wishlist[index];
          return _buildWishlistCard(wishlistItem, ref, context);
        },
      ),
    );
  }

  Widget _buildWishlistCard(
    WishlistWithService wishlistItem,
    WidgetRef ref,
    BuildContext context,
  ) {
    final service = wishlistItem.service;

    return GestureDetector(
      onTap: () {
        GoRouter.of(context).push('/service/${service.id}');
      },
      child: Container(
        height: 152,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    image: (service.image?.isNotEmpty ?? false)
                        ? DecorationImage(
                            image: NetworkImage(service.image!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: (service.image?.isEmpty ?? true)
                        ? Colors.grey[300]
                        : null,
                  ),
                  child: (service.image?.isEmpty ?? true)
                      ? const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 30,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            service.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              fontFamily: 'Okra',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => ref
                              .read(wishlistNotifierProvider.notifier)
                              .removeFromWishlist(service.id),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (service.description?.trim().isNotEmpty ?? false)
                          ? service.description!.trim()
                          : 'No description available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontFamily: 'Okra',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildPriceSection(service),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          service.rating?.toStringAsFixed(1) ?? '0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'Okra',
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
      ),
    );
  }

  Widget _buildPriceSection(ServiceListingModel service) {
    final offerPrice = service.displayOfferPrice;
    final originalPrice = service.displayOriginalPrice;
    final usePrecalculatedPrices =
        service.calculatedPrice != null || service.isPriceAdjusted == true;

    if (offerPrice != null) {
      final finalOfferPrice = usePrecalculatedPrices
          ? offerPrice
          : PriceCalculator.calculateTotalPriceWithTaxes(offerPrice);
      final finalOriginalPriceForDiscount =
          originalPrice != null && originalPrice > offerPrice
          ? (usePrecalculatedPrices
                ? originalPrice
                : PriceCalculator.calculateTotalPriceWithTaxes(originalPrice))
          : null;
      return Row(
        children: [
          if (finalOriginalPriceForDiscount != null) ...[
            Text(
              PriceCalculator.formatPriceAsInt(finalOriginalPriceForDiscount),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Okra',
                color: Color(0xFF999999),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFF999999),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            PriceCalculator.formatPriceAsInt(finalOfferPrice),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
              fontFamily: 'Okra',
            ),
          ),
        ],
      );
    }

    if (originalPrice != null) {
      final finalOriginalPrice = usePrecalculatedPrices
          ? originalPrice
          : PriceCalculator.calculateTotalPriceWithTaxes(originalPrice);
      return Text(
        PriceCalculator.formatPriceAsInt(finalOriginalPrice),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
          fontFamily: 'Okra',
        ),
      );
    }

    return const Text(
      'Price on request',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF999999),
        fontFamily: 'Okra',
      ),
    );
  }
}
