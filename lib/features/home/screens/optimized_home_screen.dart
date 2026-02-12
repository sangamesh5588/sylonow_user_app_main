import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sylonow_user/features/home/widgets/categories/optimized_explore_categories_section.dart';
import 'package:sylonow_user/features/home/widgets/featured/featured_section.dart';
import 'package:sylonow_user/features/home/widgets/collage/image_collage_section.dart';
import 'package:sylonow_user/features/home/widgets/popular_nearby/popular_nearby_section.dart';
import 'package:sylonow_user/features/home/widgets/welcome/user_celebration_overlay.dart';
import 'package:sylonow_user/features/home/widgets/location/location_widgets.dart';
import 'package:sylonow_user/features/home/widgets/app_bar/custom_app_bar.dart';
import 'package:sylonow_user/features/home/widgets/theater/theater_section.dart';
import 'package:sylonow_user/features/outside/providers/theater_providers.dart';
import 'package:sylonow_user/core/providers/core_providers.dart';
import 'package:sylonow_user/core/providers/welcome_providers.dart';
import 'package:sylonow_user/features/home/providers/home_providers.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sylonow_user/features/address/providers/address_providers.dart';
import 'package:sylonow_user/features/address/models/address_model.dart';
import 'package:sylonow_user/features/auth/providers/auth_providers.dart';
import 'package:sylonow_user/features/profile/providers/profile_providers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import 'package:sylonow_user/core/services/app_update_service.dart';

/// Optimized home screen with performance improvements
class OptimizedHomeScreen extends ConsumerStatefulWidget {
  const OptimizedHomeScreen({super.key});

  @override
  ConsumerState<OptimizedHomeScreen> createState() =>
      _OptimizedHomeScreenState();
}

class _OptimizedHomeScreenState extends ConsumerState<OptimizedHomeScreen>
    with AutomaticKeepAliveClientMixin {
  // Performance optimization: Keep state alive to prevent rebuilds
  @override
  bool get wantKeepAlive => true;

  late final ScrollController _scrollController;
  late final ValueNotifier<double> _scrollOffsetNotifier;
  bool _isLocationEnabled = false;
  bool _isLocationLoading = true;
  bool _isLocationServiceDisabled = false;
  bool _isRefreshing = false;

  // Global keys for UI elements
  static final GlobalKey locationKey = GlobalKey();
  static final GlobalKey searchKey = GlobalKey();
  static final GlobalKey profileKey = GlobalKey();
  static final GlobalKey categoriesKey = GlobalKey();
  static final GlobalKey theaterKey = GlobalKey();
  
  // Welcome overlay state
  bool _showWelcomeOverlay = false;

  // App update service
  final _appUpdateService = AppUpdateService();
  var _hasCheckedForUpdate = false;

  // Memoized search texts - only create once
  static const List<String> _searchTexts = [
    'Birthday Decoration',
    'Anniversary Setup',
    'Wedding Decoration',
    'Baby Shower',
    'Corporate Events',
    'Theme Parties',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollOffsetNotifier = ValueNotifier(0.0);

    // Tutorial completion will be handled in the tutorial coach mark

    // Performance optimization: Use value notifier instead of setState for scroll
    _scrollController.addListener(_onScroll);

    // Performance optimization: Move location operations to next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermissionAsync();
      _checkAndShowWelcomeOverlay();
      _initializeFCMToken();
      _checkForAppUpdates();
    });
  }

  /// Check for app updates
  Future<void> _checkForAppUpdates() async {
    if (_hasCheckedForUpdate) return; // Only check once per session

    try {
      // Wait for screen to be fully built
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      //('🔄 Checking for app updates on home screen...');

      final updateInfo = await _appUpdateService.checkForUpdate();

      if (updateInfo != null && mounted) {
        //('🔄 Update available! Showing dialog...');
        _hasCheckedForUpdate = true;
        await _appUpdateService.showUpdateDialog(context, updateInfo);
      } else {
        //('🔄 No update needed');
      }
    } catch (e) {
      //('🔄 ❌ Error checking for updates: $e');
    }
  }

  Future<void> _checkAndShowWelcomeOverlay() async {
    try {
      //('🎯 OptimizedHomeScreen checking welcome overlay...');
      // Wait for UI to be fully built
      await Future.delayed(const Duration(milliseconds: 500));

      final welcomeService = ref.read(welcomePreferencesServiceProvider);
      final hasShownWelcome = await welcomeService.hasShownWelcome();

      if (!hasShownWelcome && mounted) {
        //('🎯 Showing welcome overlay for the first time...');
        setState(() {
          _showWelcomeOverlay = true;
        });
      } else {
        //('🎯 Welcome overlay already shown, skipping...');
      }
    } catch (e) {
      //('Welcome overlay check error: $e');
    }
  }

  Future<void> _markWelcomeCompleted() async {
    try {
      final welcomeService = ref.read(welcomePreferencesServiceProvider);
      await welcomeService.markWelcomeCompleted();
      
      setState(() {
        _showWelcomeOverlay = false;
      });
      
      //('🎯 Welcome overlay marked as completed');
    } catch (e) {
      //('Error marking welcome completed: $e');
    }
  }

  /// Initialize FCM token and update user profile
  Future<void> _initializeFCMToken() async {
    try {
      //('🔔 Initializing FCM token...');
      
      // Get current user
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        //('🔔 No authenticated user found, skipping FCM token initialization');
        return;
      }

      //('🔔 Current user found: ${currentUser.id}');

      // Request notification permissions
      final messaging = FirebaseMessaging.instance;
      
      // Check current permission status first
      NotificationSettings initialSettings = await messaging.getNotificationSettings();
      //('🔔 Current notification permission status: ${initialSettings.authorizationStatus}');
      
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      //('🔔 Notification permission after request: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        //('🔔 Notification permission granted, getting FCM token...');

        // Get FCM token with timeout
        final fcmToken = await messaging.getToken().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            //('🔔 FCM token request timed out');
            return null;
          },
        );

        if (fcmToken != null && fcmToken.isNotEmpty) {
          //('🔔 FCM token received: ${fcmToken.length > 20 ? fcmToken.substring(0, 20) : fcmToken}...');
          
          // Update user profile with FCM token
          await _updateUserFCMToken(currentUser.id, fcmToken);
        } else {
          //('🔔 Failed to get valid FCM token');
        }
      } else {
        //('🔔 Notification permission denied: ${settings.authorizationStatus}');
      }

      // Listen for token refresh (only set up once)
      messaging.onTokenRefresh.listen((newToken) {
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null && newToken.isNotEmpty) {
          //('🔔 FCM token refreshed: ${newToken.length > 20 ? newToken.substring(0, 20) : newToken}...');
          _updateUserFCMToken(currentUser.id, newToken);
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        //('🔔 Foreground message received: ${message.messageId}');
        //('🔔 Message title: ${message.notification?.title}');
        //('🔔 Message body: ${message.notification?.body}');
      });

    } catch (e, stackTrace) {
      //('🔔 Error initializing FCM token: $e');
      //('🔔 Stack trace: $stackTrace');
    }
  }

  /// Update user FCM token in the database
  Future<void> _updateUserFCMToken(String authUserId, String fcmToken) async {
    try {
      //('🔔 Updating FCM token in database for user: $authUserId');
      
      final profileRepository = ref.read(profileRepositoryProvider);
      await profileRepository.updateFcmToken(
        authUserId: authUserId,
        fcmToken: fcmToken,
      );
      
      //('🔔 ✅ FCM token successfully upserted in user_profiles table');
      
      // Verify the update by checking if profile exists
      final updatedProfile = await profileRepository.getUserProfile(authUserId);
      if (updatedProfile?.fcmToken == fcmToken) {
        //('🔔 ✅ FCM token verification successful');
      } else {
        //('🔔 ⚠️ FCM token verification failed - token may not have been saved correctly');
      }
      
    } catch (e, stackTrace) {
      //('🔔 ❌ Error updating FCM token in database: $e');
      //('🔔 Stack trace: $stackTrace');
      
      // Retry once after a delay
      try {
        await Future.delayed(const Duration(seconds: 2));
        //('🔔 Retrying FCM token update...');
        
        final profileRepository = ref.read(profileRepositoryProvider);
        await profileRepository.updateFcmToken(
          authUserId: authUserId,
          fcmToken: fcmToken,
        );
        
        //('🔔 ✅ FCM token updated successfully on retry');
      } catch (retryError) {
        //('🔔 ❌ Failed to update FCM token on retry: $retryError');
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  // Performance optimization: Use ValueNotifier instead of setState for scroll
  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollOffsetNotifier.value = _scrollController.offset;
    }
  }

  // Performance optimization: Run location operations asynchronously
  Future<void> _checkLocationPermissionAsync() async {
    try {
      //('🔍 Location permission check started...');
      setState(() {
        _isLocationLoading = true;
        _isLocationServiceDisabled = false; // Reset the service disabled flag
      });
      await _checkLocationPermission();
    } catch (e) {
      //('Location check error: $e');
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
          _isLocationEnabled = false;
        });
      }
    }
  }


  Future<void> _checkLocationPermission() async {
    final locationService = ref.read(locationServiceProvider);
    final permissionStatus = await locationService.getPermissionStatus();
    
    //('🔍 Current permission status: $permissionStatus');

    if (permissionStatus == LocationPermission.denied) {
      //('🔍 Permission denied, requesting permission...');
      // Request permission directly using system prompt
      final newStatus = await locationService.requestPermission();
      //('🔍 New permission status after request: $newStatus');
      
      if (newStatus == LocationPermission.whileInUse ||
          newStatus == LocationPermission.always) {
        //('🔍 Permission granted, checking location service...');
        _checkLocationService();
      } else {
        //('🔍 Permission still denied, showing blocked screen');
        setState(() {
          _isLocationLoading = false;
          _isLocationEnabled = false;
          _isLocationServiceDisabled = false; // This is a permission issue, not service
        });
      }
    } else if (permissionStatus == LocationPermission.whileInUse ||
        permissionStatus == LocationPermission.always) {
      //('🔍 Permission already granted, checking location service...');
      _checkLocationService();
    } else {
      // Permission denied forever or other states - show blocked screen
      //('🔍 Permission denied forever or other state, showing blocked screen');
      setState(() {
        _isLocationLoading = false;
        _isLocationEnabled = false;
        _isLocationServiceDisabled = false; // This is a permission issue, not service
      });
    }
  }

  Future<void> _checkLocationService() async {
    final locationService = ref.read(locationServiceProvider);
    //('🔍 Checking if location service is enabled...');
    final serviceEnabled = await locationService.isLocationServiceEnabled();
    //('🔍 Location service enabled: $serviceEnabled');

    if (!serviceEnabled) {
      // Location service is disabled - prompt user to enable it
      //('🔍 Location service disabled, prompting user to enable...');
      try {
        //('🔍 Opening native location settings dialog...');
        await locationService.openLocationSettings();
        
        // Wait a moment for the user to potentially enable location
        await Future.delayed(const Duration(milliseconds: 1500));
        
        // Check again if location service is now enabled
        //('🔍 Re-checking location service after settings dialog...');
        final newServiceEnabled = await locationService.isLocationServiceEnabled();
        //('🔍 Location service enabled after dialog: $newServiceEnabled');
        
        if (newServiceEnabled) {
          //('🔍 Location service now enabled, getting current location...');
          _getCurrentLocation();
        } else {
          //('🔍 Location service still disabled, showing blocked screen');
          setState(() {
            _isLocationLoading = false;
            _isLocationEnabled = false;
            _isLocationServiceDisabled = true;
          });
        }
      } catch (e) {
        //('🔍 Error opening location settings: $e');
        setState(() {
          _isLocationLoading = false;
          _isLocationEnabled = false;
          _isLocationServiceDisabled = true;
        });
      }
    } else {
      //('🔍 Location service enabled, getting current location...');
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      //('🔍 Getting current location...');
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentLocation().timeout(
        const Duration(seconds: 30),
      );
      
      //('🔍 Location result: ${position != null ? "Success (${position.latitude}, ${position.longitude})" : "Failed - null position"}');

      if (position != null && mounted) {
        //('🔍 Processing location data...');
        // Performance optimization: Run geocoding on background isolate
        _processLocationData(position);
      } else if (mounted) {
        //('🔍 Position is null, showing blocked screen');
        setState(() {
          _isLocationLoading = false;
          _isLocationEnabled = false;
        });
      }
    } catch (e) {
      //('🔍 Location error: $e');
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
          _isLocationEnabled = false;
        });
      }
    }
  }

  void _processLocationData(Position position) async {
    try {
      //('🔍 Processing location data for coordinates: (${position.latitude}, ${position.longitude})');
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      //('🔍 Geocoding result: ${placemarks.isNotEmpty ? "Success - ${placemarks.length} placemarks found" : "No placemarks found"}');

      if (mounted) {
        final placemark = placemarks.isNotEmpty ? placemarks.first : null;
        final currentAddress = Address(
          id: const Uuid().v4(),
          userId: ref.read(currentUserProvider)?.id ?? 'guest',
          addressFor: AddressType.home,
          address: placemark != null
              ? '${placemark.street ?? ''}, ${placemark.locality ?? 'Unknown Location'}'
              : 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}',
          area: placemark?.subLocality ?? placemark?.locality ?? 'Unknown Area',
          name: 'Current Location',
          // Save coordinates for location-based features
          latitude: position.latitude,
          longitude: position.longitude,
          // Save state and city for regional filtering
          state: placemark?.administrativeArea, // State (e.g., Maharashtra, Karnataka)
          city: placemark?.locality, // City (e.g., Mumbai, Bangalore)
        );

        //('🔍 Setting address: ${currentAddress.address}');
        //('🔍 With coordinates: (${currentAddress.latitude}, ${currentAddress.longitude})');
        ref.read(selectedAddressProvider.notifier).state = currentAddress;

        setState(() {
          _isLocationEnabled = true;
          _isLocationLoading = false;
        });
        //('🔍 ✅ Location setup completed successfully!');
      }
    } catch (e) {
      //('🔍 Geocoding error: $e');
      if (mounted) {
        setState(() {
          _isLocationEnabled = true;
          _isLocationLoading = false;
        });
        //('🔍 ✅ Location setup completed with geocoding error (using coordinates)');
      }
    }
  }

  /// Build empty state when no services are found nearby
  Widget _buildNoServicesState(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      // Make it full screen height to center properly
      height: screenHeight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_searching,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'We\'re not in your area yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  fontFamily: 'Okra',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We haven\'t launched our services in your location yet, but we\'re expanding soon!',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  fontFamily: 'Okra',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Check back later or try a different location.',
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
      ),
    );
  }

  /// Handle pull-to-refresh action
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      //('🔄 Starting refresh...');

      // Invalidate all providers to trigger refresh
      ref.invalidate(featuredServicesProvider);
      ref.invalidate(popularNearbyServicesProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(privateTheaterServicesProvider);

      // Wait for a moment to allow providers to refresh
      await Future.delayed(const Duration(milliseconds: 500));

      // DON'T refresh current location - preserve user's selected address
      // The nearby services will use the selected address coordinates
      // Only update GPS if no address is selected

      //('🔄 ✅ Refresh completed successfully!');
    } catch (e) {
      //('🔄 ❌ Refresh error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to refresh. Please try again.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLocationLoading) {
      return const LocationLoadingScreen();
    }

    if (!_isLocationEnabled) {
      return LocationBlockedScreen(
        onRetry: _checkLocationPermissionAsync,
        isServiceDisabled: _isLocationServiceDisabled,
      );
    }

    return Scaffold(
        backgroundColor: Colors.grey[100],
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Main scrollable content with pull-to-refresh
            RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Colors.pink,
              backgroundColor: Colors.white,
              displacement: 80, // Offset to account for custom app bar
              child: CustomScrollView(
                controller: _scrollController,
                // Performance optimization: Use const widgets where possible
                slivers: [
                  // Conditionally show advertisement section only if services are available
                  Consumer(
                    builder: (context, ref, child) {
                      final nearbyState = ref.watch(popularNearbyServicesProvider);
                      return nearbyState.when(
                        data: (services) {
                          if (services.isNotEmpty) {
                            return const SliverToBoxAdapter(child: AdvertisementSection());
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => const SliverToBoxAdapter(child: AdvertisementSection()),
                        error: (_, __) => const SliverToBoxAdapter(child: AdvertisementSection()),
                      );
                    },
                  ),
                  // Conditionally show spacing only if advertisement is shown
                  Consumer(
                    builder: (context, ref, child) {
                      final nearbyState = ref.watch(popularNearbyServicesProvider);
                      return nearbyState.when(
                        data: (services) {
                          if (services.isNotEmpty) {
                            return const SliverToBoxAdapter(child: SizedBox(height: 24));
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        error: (_, __) => const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      );
                    },
                  ),
                  // Conditionally show explore categories section only if services are available
                  Consumer(
                    builder: (context, ref, child) {
                      final nearbyState = ref.watch(popularNearbyServicesProvider);
                      return nearbyState.when(
                        data: (services) {
                          if (services.isNotEmpty) {
                            return SliverToBoxAdapter(
                              child: Container(
                                key: categoriesKey,
                                child: const OptimizedExploreCategoriesSection(),
                              ),
                            );
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => SliverToBoxAdapter(
                          child: Container(
                            key: categoriesKey,
                            child: const OptimizedExploreCategoriesSection(),
                          ),
                        ),
                        error: (_, __) => SliverToBoxAdapter(
                          child: Container(
                            key: categoriesKey,
                            child: const OptimizedExploreCategoriesSection(),
                          ),
                        ),
                      );
                    },
                  ),
                  // Conditionally show spacing only if categories section is shown
                  Consumer(
                    builder: (context, ref, child) {
                      final nearbyState = ref.watch(popularNearbyServicesProvider);
                      return nearbyState.when(
                        data: (services) {
                          if (services.isNotEmpty) {
                            return const SliverToBoxAdapter(child: SizedBox(height: 24));
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        error: (_, __) => const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      );
                    },
                  ),
                  // Show nice empty state message when no services are found
                  Consumer(
                    builder: (context, ref, child) {
                      final nearbyState = ref.watch(popularNearbyServicesProvider);
                      return nearbyState.when(
                        data: (services) {
                          if (services.isEmpty) {
                            return SliverToBoxAdapter(
                              child: _buildNoServicesState(context),
                            );
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                        error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      );
                    },
                  ),
                  // Featured section title
                  // Consumer(
                  //   builder: (context, ref, child) {
                  //     final featuredState = ref.watch(featuredServicesProvider);
                  //     if (featuredState.services.isNotEmpty || featuredState.hasMore) {
                  //       return SliverToBoxAdapter(
                  //         child: Padding(
                  //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  //           // child: Text(
                  //           //   'Best Services',
                  //           //   style: const TextStyle(
                  //           //     fontSize: 20,
                  //           //     fontWeight: FontWeight.w700,
                  //           //     fontFamily: 'Okra',
                  //           //     color: Colors.black87,
                  //           //   ),
                  //           // ),
                  //         ),
                  //       );
                  //     }
                  //     return const SliverToBoxAdapter(child: SizedBox.shrink());
                  //   },
                  // ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  // Conditionally show featured section
                  Consumer(
                    builder: (context, ref, child) {
                      final featuredAsync = ref.watch(featuredMainServicesProvider);
                      return featuredAsync.when(
                        data: (services) {
                          if (services.isNotEmpty) {
                            return const SliverToBoxAdapter(child: FeaturedSection());
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => const SliverToBoxAdapter(child: FeaturedSection()),
                        error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      );
                    },
                  ),
                  // Conditionally show spacing only if featured section is shown
                  Consumer(
                    builder: (context, ref, child) {
                      final featuredAsync = ref.watch(featuredMainServicesProvider);
                      return featuredAsync.when(
                        data: (services) {
                          if (services.isNotEmpty) {
                            return const SliverToBoxAdapter(child: SizedBox(height: 24));
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      );
                    },
                  ),
                  // Theater section with conditional rendering
                  Consumer(
                    builder: (context, ref, child) {
                      final theaterAsync = ref.watch(featuredTheaterScreensProvider);
                      return theaterAsync.when(
                        data: (screens) {
                          if (screens.isNotEmpty) {
                            return SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Text(
                                      'Private Theaters',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Okra',
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    key: theaterKey,
                                    child: const TheaterSection(),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            );
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  'Private Theaters',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Okra',
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                key: theaterKey,
                                child: const TheaterSection(),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                        error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      );
                    },
                  ),
                  // Conditionally show image collage section
                  Consumer(
                    builder: (context, ref, child) {
                      final collageAsync = ref.watch(featuredCollageServicesProvider);
                      return collageAsync.when(
                        data: (services) {
                          if (services.isNotEmpty) {
                            return const SliverToBoxAdapter(child: ImageCollageSection());
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => const SliverToBoxAdapter(child: ImageCollageSection()),
                        error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  // Conditionally show popular nearby section only if services are available
                  Consumer(
                    builder: (context, ref, child) {
                      final nearbyState = ref.watch(popularNearbyServicesProvider);
                      return nearbyState.when(
                        data: (services) {
                          if (services.isNotEmpty) {
                            return const SliverToBoxAdapter(child: PopularNearbySection());
                          }
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        },
                        loading: () => const SliverToBoxAdapter(child: PopularNearbySection()),
                        error: (_, __) => const SliverToBoxAdapter(child: PopularNearbySection()),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Custom App Bar as an overlay
            ValueListenableBuilder<double>(
              valueListenable: _scrollOffsetNotifier,
              builder: (context, scrollOffset, child) {
                return CustomAppBarOverlay(
                  scrollOffset: scrollOffset,
                  isLocationEnabled: _isLocationEnabled,
                  profileKey: profileKey,
                  locationKey: locationKey,
                  searchKey: searchKey,
                );
              },
            ),
            // User celebration overlay
            if (_showWelcomeOverlay)
              UserCelebrationOverlay(
                onContinue: _markWelcomeCompleted,
              ),
          ],
        ),

    );
  }

}
