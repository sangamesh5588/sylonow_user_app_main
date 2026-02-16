import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/guest_user_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';

/// Example of how to use the guest conversion flow in your app
///
/// USE CASE 1: In a booking button
class BookingButtonExample extends ConsumerWidget {
  const BookingButtonExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        // Check if user needs to register (is a guest)
        final canProceed = await ref.requireRegistration(
          context,
          feature: 'booking services',
          onComplete: () {
            // This callback runs after successful conversion
            // You can refresh data, update UI, etc.
            debugPrint('User successfully converted from guest to registered!');
          },
        );

        if (canProceed) {
          // User is registered, proceed with booking
          _proceedToBooking(context);
        }
        // If canProceed is false, user cancelled the modal
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      child: const Text('Book Now'),
    );
  }

  void _proceedToBooking(BuildContext context) {
    // Navigate to booking screen or show booking dialog
    debugPrint('Proceeding to booking...');
  }
}

/// USE CASE 2: In a service detail screen
class ServiceDetailActionExample extends ConsumerWidget {
  const ServiceDetailActionExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            final canBook = await GuestUserHelper.requiresRegistration(
              context,
              ref,
              feature: 'booking this service',
            );

            if (canBook) {
              // Navigate to booking page
              debugPrint('Navigate to booking');
            }
          },
          child: const Text('Book Service'),
        ),

        const SizedBox(height: 16),

        OutlinedButton(
          onPressed: () async {
            final canAddToFavorites = await ref.requireRegistration(
              context,
              feature: 'adding to favorites',
            );

            if (canAddToFavorites) {
              // Add to favorites
              debugPrint('Add to favorites');
            }
          },
          child: const Text('Add to Favorites'),
        ),
      ],
    );
  }
}

/// USE CASE 3: Protecting profile or account features
class ProfileActionExample extends ConsumerWidget {
  const ProfileActionExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.bookmark),
      title: const Text('My Bookings'),
      onTap: () async {
        final canAccess = await ref.requireRegistration(
          context,
          feature: 'viewing your bookings',
        );

        if (canAccess) {
          // Navigate to bookings screen
          debugPrint('Show bookings');
        }
      },
    );
  }
}

/// USE CASE 4: In a bottom sheet or dialog action
class BottomSheetActionExample extends ConsumerWidget {
  const BottomSheetActionExample({super.key});

  void _showServiceOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_add),
              title: const Text('Save Service'),
              onTap: () async {
                Navigator.pop(context); // Close bottom sheet

                final canSave = await ref.requireRegistration(
                  context,
                  feature: 'saving services',
                );

                if (canSave) {
                  debugPrint('Save service');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Service'),
              onTap: () {
                // Sharing might not require registration
                Navigator.pop(context);
                debugPrint('Share service');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () => _showServiceOptions(context, ref),
    );
  }
}

/// USE CASE 5: Manual check without showing modal immediately
class ManualGuestCheckExample extends ConsumerWidget {
  const ManualGuestCheckExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch guest status
    final isGuestAsync = ref.watch(isGuestUserProvider);

    return isGuestAsync.when(
      data: (isGuest) {
        if (isGuest) {
          // Show limited UI for guests
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Create an account to unlock all features'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      GuestUserHelper.showConversionModal(
                        context,
                        feature: 'unlocking all features',
                      );
                    },
                    child: const Text('Create Account'),
                  ),
                ],
              ),
            ),
          );
        }

        // Show full UI for registered users
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Full features available!'),
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Error checking user status'),
    );
  }
}
