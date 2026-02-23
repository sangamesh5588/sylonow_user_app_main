import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';
import 'phone_input_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  bool _acceptTerms = false;

  @override
  void initState() {
    super.initState();
    // _checkAppleSignInAvailability(); // Commented out - Apple sign-in disabled
  }

  // Commented out - Apple sign-in disabled
  // Future<void> _checkAppleSignInAvailability() async {
  //   final authService = ref.read(authServiceProvider);
  //   final isAvailable = await authService.isAppleSignInAvailable();
  //   setState(() {
  //     _isAppleSignInAvailable = isAvailable;
  //   });
  // }

  void _continueWithPhone() {
    if (!_acceptTerms) {
      _showTermsError();
      return;
    }
    // Navigate to phone input screen
    context.push(PhoneInputScreen.routeName);
  }

  void _showTermsError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please accept the Terms and Privacy Policy to continue'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Commented out - Apple sign-in disabled
  // Future<void> _continueWithApple() async {
  //   if (!_acceptTerms) {
  //     _showTermsError();
  //     return;
  //   }

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     final authService = ref.read(authServiceProvider);

  //     // Sign in with Apple
  //     final response = await authService.signInWithApple();

  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });

  //       if (response != null && response.user != null) {
  //         // Invalidate auth providers to trigger updates
  //         ref.invalidate(isAuthenticatedProvider);
  //         ref.invalidate(currentUserProvider);
  //         ref.invalidate(isOnboardingCompletedProvider);

  //         // Wait a moment for providers to update
  //         await Future.delayed(const Duration(milliseconds: 100));

  //         if (mounted) {
  //           // Navigate to splash screen which will handle the routing based on auth state
  //           context.go(AppConstants.splashRoute);
  //         }
  //       }
  //       // If response is null, user canceled - no need to show a message
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Apple sign in failed: ${e.toString()}'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }

  Future<void> _continueWithGoogle() async {
    if (!_acceptTerms) {
      _showTermsError();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // Sign in with Google
      final response = await authService.signInWithGoogle();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response != null && response.user != null) {
          // Invalidate auth providers to trigger updates
          ref.invalidate(isAuthenticatedProvider);
          ref.invalidate(currentUserProvider);
          ref.invalidate(isOnboardingCompletedProvider);

          // Wait a moment for providers to update
          await Future.delayed(const Duration(milliseconds: 100));

          if (mounted) {
            // Navigate to splash screen which will handle the routing based on auth state
            context.go(AppConstants.splashRoute);
          }
        } else {
          // User canceled the sign-in
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sign in was canceled')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign in failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _continueAsGuest() async {
    if (!_acceptTerms) {
      _showTermsError();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authController = ref.read(authControllerProvider.notifier);
      await authController.signInAnonymously();

      if (mounted) {
        final state = ref.read(authControllerProvider);

        setState(() {
          _isLoading = false;
        });

        if (state is AsyncData) {
          // Invalidate auth providers to trigger updates
          ref.invalidate(isAuthenticatedProvider);
          ref.invalidate(currentUserProvider);
          ref.invalidate(isOnboardingCompletedProvider);

          // Wait a moment for providers to update
          await Future.delayed(const Duration(milliseconds: 100));

          if (mounted) {
            // Navigate to home screen for guest users
            context.go(AppConstants.homeRoute);
          }
        } else if (state is AsyncError) {
          final error = state.error;
          String errorMessage = 'Guest login failed';

          if (error is AuthApiException &&
              error.code == 'anonymous_provider_disabled') {
            errorMessage =
                'Anonymous login is disabled in Supabase. Please enable it in the Dashboard -> Authentication -> Providers.';
          } else {
            errorMessage = 'Guest login failed: $error';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Guest login failed: ${e.toString()}';
        if (e is AuthApiException && e.code == 'anonymous_provider_disabled') {
          errorMessage =
              'Anonymous login is disabled in Supabase. Please enable it in the Dashboard -> Authentication -> Providers.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Top Half - Blue section with logo
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  color: AppTheme.primaryColor,
                  padding: EdgeInsets.fromLTRB(24, topInset + 60, 24, 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      // Logo
                      SvgPicture.asset(
                        'assets/svgs/app_logo.svg',
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Book celebrations\nin minutes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.3,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Okra',
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),

              // Bottom Half - White section with rounded top
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Handle bar
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Continue with Phone Button
                      SizedBox(
                        height: 60,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _acceptTerms ? _continueWithPhone : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[400],
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_android_rounded, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Continue with Phone',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Okra',
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // OR Divider
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Okra',
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Continue with Google Button
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading || !_acceptTerms
                              ? null
                              : _continueWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1F2937),
                            disabledBackgroundColor: Colors.grey[200],
                            disabledForegroundColor: Colors.grey[400],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                              side: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.grey[600],
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      FontAwesomeIcons.google,
                                      size: 20,
                                      color: Color(0xFF4285F4),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Okra',
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Terms and Privacy Checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _acceptTerms,
                              onChanged: (value) {
                                setState(() {
                                  _acceptTerms = value ?? false;
                                });
                              },
                              activeColor: AppTheme.primaryColor,
                              checkColor: Colors.white,
                              side: BorderSide(
                                color: _acceptTerms
                                    ? AppTheme.primaryColor
                                    : const Color(0xFFD1D5DB),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                    height: 1.4,
                                    fontFamily: 'Okra',
                                  ),
                                  children: const [
                                    TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
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

          // Skip button in top-right corner
          Positioned(
            top: topInset + 16,
            right: 16,
            child: TextButton(
              onPressed: _isLoading ? null : _continueAsGuest,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Skip',
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
    );
  }
}
