import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:sylonow_user/core/theme/app_theme.dart';
import 'package:sylonow_user/features/outside/models/theater_screen_model.dart';
import 'package:sylonow_user/features/outside/providers/theater_providers.dart';

/// Enhanced theater section widget that displays theater screens with auto-scrolling images
class TheaterSection extends ConsumerStatefulWidget {
  const TheaterSection({super.key});

  @override
  ConsumerState<TheaterSection> createState() => _TheaterSectionState();
}

class _TheaterSectionState extends ConsumerState<TheaterSection>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _progressController;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  int _currentIndex = 0;
  bool _isAutoPlaying = true;
  bool _isUserInteracting = false;
  Timer? _carouselTimer;

  // Image auto-scroll management
  final Map<String, int> _currentImageIndex = {};
  final Map<String, Timer?> _imageTimers = {};

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: _currentIndex);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeIn),
    );

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Defer auto-play start until after the first frame is rendered
    // This ensures PageController is attached to PageView before accessing it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAutoPlay();
      }
    });
    _slideController.forward();
    _progressController.forward();
  }

  void _startAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _isAutoPlaying && !_isUserInteracting && _pageController.hasClients) {
        final screensAsync = ref.read(theaterScreensProvider);
        final screens = screensAsync.value ?? [];

        if (screens.isNotEmpty) {
          final nextIndex = (_currentIndex + 1) % screens.length;
          _pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  void _resetProgress() {
    _progressController.reset();
    _progressController.forward();
  }

  void _handleUserInteraction() {
    setState(() {
      _isUserInteracting = true;
      _isAutoPlaying = false;
    });

    _carouselTimer?.cancel();

    // Resume auto-play after user interaction
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
          _isAutoPlaying = true;
        });
        _startAutoPlay();
      }
    });
  }

  void _jumpToPage(int index) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
    _handleUserInteraction();
  }

  void _startImageAutoScroll(String screenId, int imageCount) {
    if (imageCount <= 1) return; // No need to scroll if only one image

    // Cancel existing timer for this screen if any
    _imageTimers[screenId]?.cancel();

    // Initialize current index if not exists
    if (!_currentImageIndex.containsKey(screenId)) {
      _currentImageIndex[screenId] = 0;
    }

    // Start new timer for auto-scrolling images every 3 seconds
    _imageTimers[screenId] = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex[screenId] =
              (_currentImageIndex[screenId]! + 1) % imageCount;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    _progressController.dispose();
    _shimmerController.dispose();
    _carouselTimer?.cancel();
    // Cancel all image timers
    for (final timer in _imageTimers.values) {
      timer?.cancel();
    }
    _imageTimers.clear();
    super.dispose();
  }

  void _preloadImages(List<TheaterScreen> screens) {
    if (screens.isEmpty) return;

    // Preload images for current and adjacent screens for smooth scrolling
    final indicesToPreload = <int>{};

    // Ensure _currentIndex is within bounds before using
    final safeCurrentIndex = _currentIndex.clamp(0, screens.length - 1);

    // Add current index
    indicesToPreload.add(safeCurrentIndex);

    // Add previous and next indices (with wrap-around)
    if (screens.length > 1) {
      indicesToPreload.add((safeCurrentIndex - 1 + screens.length) % screens.length);
      indicesToPreload.add((safeCurrentIndex + 1) % screens.length);
    }

    for (final index in indicesToPreload) {
      if (index >= 0 && index < screens.length) {
        final screen = screens[index];
        if (screen.images?.isNotEmpty == true) {
          for (final imageUrl in screen.images!) {
            if (imageUrl.isNotEmpty) {
              precacheImage(CachedNetworkImageProvider(imageUrl), context);
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screensAsync = ref.watch(featuredTheaterScreensProvider);

    return screensAsync.when(
      data: (screens) {
        if (screens.isEmpty) {
          return const SizedBox.shrink();
        }

        // Start image auto-scroll for visible screens
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (var screen in screens) {
            if (screen.images?.isNotEmpty == true) {
              _startImageAutoScroll(screen.id, screen.images!.length);
            }
          }
          // Preload images for smooth transitions
          _preloadImages(screens);
        });

        return SizedBox(
          height: 225,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: screens.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildDealCard(screens[index]),
              );
            },
          ),
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildDealCard(TheaterScreen screen) {
    final images = screen.images ?? [];
    final hasImages = images.isNotEmpty;
    final currentImageIndexForScreen = _currentImageIndex[screen.id] ?? 0;
    final currentImage = hasImages ? images[currentImageIndexForScreen] : null;

    // Calculate discount (example: 25% off)
    final discountPercent = 25;

    return GestureDetector(
      onTap: () {
        _handleUserInteraction();
        // Navigate to theater screen detail
        context.push(
          '/theater-screen-detail',
          extra: {
            'screen': screen,
          },
        );
      },
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: hasImages && currentImage != null
                    ? CachedNetworkImage(
                        imageUrl: currentImage,
                        fit: BoxFit.cover,
                        memCacheWidth: 600,
                        memCacheHeight: 400,
                        fadeInDuration: const Duration(milliseconds: 300),
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.movie, size: 48, color: Colors.grey),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 0.3),
                              AppTheme.primaryColor.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.movie, size: 48, color: Colors.grey),
                        ),
                      ),
              ),

              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Screen name
                      Text(
                        screen.screenName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Okra',
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Discount badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'UP TO $discountPercent% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Okra',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Rating badge (top right)
              if (screen.allowedCapacity != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '0.0',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Okra',
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 11,
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

  Widget _buildLoadingState() {
    return SizedBox(
      height: 225,
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
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
