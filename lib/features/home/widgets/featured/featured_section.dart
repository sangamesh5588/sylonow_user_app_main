import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/features/home/models/service_listing_model.dart';
import 'package:sylonow_user/features/home/providers/home_providers.dart';

class FeaturedSection extends ConsumerStatefulWidget {
  const FeaturedSection({super.key});

  @override
  ConsumerState<FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends ConsumerState<FeaturedSection> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _autoScrollTimer;
  bool _isAutoPlaying = true;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    // Defer auto-scroll start until after the first frame is rendered
    // This ensures PageController is attached to PageView before accessing it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAutoScroll();
      }
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _isAutoPlaying && !_isUserInteracting && _pageController.hasClients) {
        final featuredAsync = ref.read(featuredServicesSimpleProvider);
        featuredAsync.whenData((services) {
          final itemCount = services.length > 10 ? 10 : services.length;

          if (itemCount > 0) {
            final nextIndex = (_currentIndex + 1) % itemCount;
            _pageController.animateToPage(
              nextIndex,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOutCubic,
            );
          }
        });
      }
    });
  }

  void _handleUserInteraction() {
    setState(() {
      _isUserInteracting = true;
      _isAutoPlaying = false;
    });

    _autoScrollTimer?.cancel();

    // Resume auto-scroll after 3 seconds of no interaction
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
          _isAutoPlaying = true;
        });
        _startAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featuredAsync = ref.watch(featuredMainServicesProvider);

    return featuredAsync.when(
      loading: () => _buildLoadingCarousel(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (services) {
        if (services.isEmpty) {
          return const SizedBox.shrink();
        }

        final displayServices = services.length > 10 ? services.take(10).toList() : services;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header with "View all" link
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Featured this week',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Okra',
                      color: Colors.black87,
                    ),
                  ),
                  // TextButton(
                  //   onPressed: () {
                  //     // Navigate to view all featured services
                  //   },
                  //   style: TextButton.styleFrom(
                  //     padding: EdgeInsets.zero,
                  //     minimumSize: const Size(50, 30),
                  //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  //   ),
                  //   child: Row(
                  //     children: [
                  //       Text(
                  //         'View all',
                  //         style: TextStyle(
                  //           fontSize: 14,
                  //           fontWeight: FontWeight.w600,
                  //           fontFamily: 'Okra',
                  //           color: AppTheme.primaryColor,
                  //         ),
                  //       ),
                  //       const SizedBox(width: 4),
                  //       Icon(
                  //         Icons.arrow_forward,
                  //         size: 16,
                  //         color: AppTheme.primaryColor,
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Horizontal scrolling cards
            SizedBox(
              height: 305,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: displayServices.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (context, index) {
                  final service = displayServices[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildFeaturedCard(service),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedCard(ServiceListingModel service) {
    // Calculate discount percentage
    int? discountPercentage;
    if (service.displayOriginalPrice != null && service.displayOfferPrice != null) {
      final discount = ((service.displayOriginalPrice! - service.displayOfferPrice!) /
                        service.displayOriginalPrice! * 100);
      discountPercentage = discount.round();
    }

    return GestureDetector(
      onTap: () {
        _handleUserInteraction();
        context.push('/service/${service.id}');
      },
      child: Container(
        width: 280,
        height: 305,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: service.image ?? '',
                    width: double.infinity,
                    height: 145,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Service name
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Okra',
                      color: Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Description (1 line)
                  if (service.description != null && service.description!.isNotEmpty)
                    Text(
                      service.description!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Okra',
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  // Offer info and call to action section
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (discountPercentage != null && discountPercentage > 0) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.local_offer,
                                size: 12,
                                color: const Color.fromARGB(255, 253, 102, 64),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'More offers inside',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Okra',
                                  color: const Color.fromARGB(255, 255, 97, 35)
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 248, 221, 214),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Flat $discountPercentage% off on pre-booking',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Okra',
                                color: const Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Divider(height: 1, color: Colors.grey[300]),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 12,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to explore more',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Okra',
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Featured this week',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Okra',
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Okra',
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 305,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
