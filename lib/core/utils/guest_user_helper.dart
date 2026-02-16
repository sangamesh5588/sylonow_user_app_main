import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/widgets/guest_conversion_modal.dart';

/// Helper class for handling guest user restrictions
class GuestUserHelper {
  static Route<bool> _buildConversionRoute({
    required String feature,
    VoidCallback? onConversionComplete,
  }) {
    return PageRouteBuilder<bool>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return GuestConversionModal(
          feature: feature,
          onConversionComplete: onConversionComplete,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Check if user is a guest and show conversion modal if needed
  /// Returns true if action can proceed, false if blocked by guest status
  static Future<bool> requiresRegistration(
    BuildContext context,
    WidgetRef ref, {
    String feature = 'this feature',
    VoidCallback? onConversionComplete,
  }) async {
    // Check if user is a guest
    final isGuestAsync = ref.read(isGuestUserProvider);

    return isGuestAsync.when(
      data: (isGuest) async {
        if (isGuest) {
          // User is a guest, show conversion modal
          final result = await Navigator.of(context, rootNavigator: true)
              .push<bool>(
                _buildConversionRoute(
                  feature: feature,
                  onConversionComplete: onConversionComplete,
                ),
              );

          // Return true only if conversion was successful
          return result == true;
        }

        // User is not a guest, allow action to proceed
        return true;
      },
      loading: () => false, // Block action while loading
      error: (_, __) => false, // Block action on error
    );
  }

  /// Show guest conversion modal directly
  static Future<bool> showConversionModal(
    BuildContext context, {
    String feature = 'this feature',
    VoidCallback? onConversionComplete,
  }) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      _buildConversionRoute(
        feature: feature,
        onConversionComplete: onConversionComplete,
      ),
    );

    return result == true;
  }
}

/// Extension on WidgetRef to make it easier to check guest status
extension GuestCheckExtension on WidgetRef {
  /// Check if user is a guest and show modal if needed
  /// Returns true if action can proceed
  Future<bool> requireRegistration(
    BuildContext context, {
    String feature = 'this feature',
    VoidCallback? onComplete,
  }) async {
    return GuestUserHelper.requiresRegistration(
      context,
      this,
      feature: feature,
      onConversionComplete: onComplete,
    );
  }
}
