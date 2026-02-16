# Guest User Conversion Flow

## Overview

This feature allows guest users to browse the app with limited functionality. When they attempt to access protected features (like booking, favorites, etc.), they are prompted with a **non-dismissible modal** to create an account via phone number verification.

## Features

✅ **Guest Detection** - Automatically detects if user is logged in as guest
✅ **Non-Dismissible Modal** - Users must complete registration or explicitly cancel
✅ **Phone + OTP Verification** - Secure phone number verification flow
✅ **Seamless Conversion** - Converts guest account to registered account
✅ **Easy Integration** - Simple helper functions to protect any action
✅ **Customizable Messages** - Show feature-specific messages

## Architecture

### Files Created

1. **`lib/features/auth/providers/auth_providers.dart`**
   - Added `isGuestUserProvider` - Checks if current user is a guest

2. **`lib/features/auth/widgets/guest_conversion_modal.dart`**
   - Non-dismissible modal with phone number and OTP verification
   - Handles the entire conversion flow

3. **`lib/core/utils/guest_user_helper.dart`**
   - Helper functions to check guest status and show conversion modal
   - Extension methods for easy integration

4. **`lib/features/auth/examples/guest_conversion_usage_example.dart`**
   - Complete examples of how to use the feature in different scenarios

## How It Works

### 1. Guest Login
When users tap "Continue as Guest" on the login screen:
- Anonymous authentication is performed via Supabase
- `isGuestKey` is set to `true` in SharedPreferences
- User can browse the app with limited functionality

### 2. Protected Action Attempt
When a guest user tries to access a protected feature:
- The app checks if user is a guest via `isGuestUserProvider`
- If guest, shows the conversion modal (non-dismissible)
- User must enter phone number and verify OTP to proceed

### 3. Conversion Flow
The modal guides the user through:
1. **Enter Phone Number** - 10-digit Indian phone number with +91 prefix
2. **Send OTP** - Sends OTP via Supabase Auth
3. **Verify OTP** - 6-digit PIN input with auto-complete
4. **Account Created** - Guest account is converted to full account
5. **Action Proceeds** - User can now complete the protected action

## Usage Examples

### Method 1: Using Extension (Recommended)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sylonow_user/core/utils/guest_user_helper.dart';

class BookButton extends ConsumerWidget {
  const BookButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        // Check if user can proceed (auto-shows modal if guest)
        final canProceed = await ref.requireRegistration(
          context,
          feature: 'booking services', // Shown in modal message
          onComplete: () {
            // Optional callback after successful conversion
            print('User converted!');
          },
        );

        if (canProceed) {
          // User is registered, proceed with booking
          _navigateToBooking(context);
        }
      },
      child: const Text('Book Now'),
    );
  }

  void _navigateToBooking(BuildContext context) {
    // Your booking logic here
  }
}
```

### Method 2: Using Helper Class

```dart
import 'package:sylonow_user/core/utils/guest_user_helper.dart';

ElevatedButton(
  onPressed: () async {
    final canProceed = await GuestUserHelper.requiresRegistration(
      context,
      ref,
      feature: 'adding to favorites',
    );

    if (canProceed) {
      // Add to favorites
    }
  },
  child: const Text('Add to Favorites'),
)
```

### Method 3: Manual Guest Check (for UI changes)

```dart
import 'package:sylonow_user/features/auth/providers/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuestAsync = ref.watch(isGuestUserProvider);

    return isGuestAsync.when(
      data: (isGuest) {
        if (isGuest) {
          // Show limited UI for guests
          return Column(
            children: [
              const Text('Create account to unlock features'),
              ElevatedButton(
                onPressed: () {
                  GuestUserHelper.showConversionModal(
                    context,
                    feature: 'accessing your profile',
                  );
                },
                child: const Text('Create Account'),
              ),
            ],
          );
        }

        // Show full profile for registered users
        return FullProfileContent();
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const ErrorWidget(),
    );
  }
}
```

## Where to Implement

Add guest protection to these features:

### High Priority (Must Require Registration)
- ✅ **Booking Services** - When user taps "Book Now"
- ✅ **Quote Requests** - When requesting quotes from vendors
- ✅ **Favorites/Saved Items** - When adding services to favorites
- ✅ **My Bookings** - Viewing booking history
- ✅ **My Quotes** - Viewing quote requests
- ✅ **Chat/Messages** - Contacting vendors
- ✅ **Reviews/Ratings** - Submitting reviews
- ✅ **Payment** - Making payments

### Medium Priority (Optional Protection)
- 🔸 **Search** - Allow guests to search (no restriction)
- 🔸 **Categories** - Allow guests to browse (no restriction)
- 🔸 **Service Details** - Allow guests to view (no restriction)
- 🔸 **Share** - Allow guests to share (no restriction)

## Implementation Checklist

To add guest protection to a feature:

1. **Import the helper**
   ```dart
   import 'package:sylonow_user/core/utils/guest_user_helper.dart';
   ```

2. **Make your widget a ConsumerWidget**
   ```dart
   class MyWidget extends ConsumerWidget {
     // Your code
   }
   ```

3. **Add the check before protected action**
   ```dart
   onPressed: () async {
     final canProceed = await ref.requireRegistration(
       context,
       feature: 'your feature name',
     );

     if (canProceed) {
       // Proceed with action
     }
   },
   ```

## Testing

### Test Scenario 1: Guest User Flow
1. Open the app
2. Tap "Continue as Guest"
3. Browse services
4. Tap "Book Now" on any service
5. **Expected**: Conversion modal appears
6. Enter phone number: `9876543210`
7. Receive OTP (check Supabase dashboard or phone)
8. Enter OTP
9. **Expected**: Modal closes, booking proceeds

### Test Scenario 2: Registered User Flow
1. Login with phone number
2. Browse services
3. Tap "Book Now"
4. **Expected**: No modal, proceeds directly to booking

### Test Scenario 3: Modal Cancellation
1. Login as guest
2. Try to book a service
3. In the modal, tap the close button (X)
4. **Expected**: Modal closes, booking does NOT proceed

### Test Scenario 4: Multiple Protected Actions
1. Login as guest
2. Try to add to favorites → Convert account
3. Try to book service → Proceeds directly (already registered)
4. **Expected**: Only asks for registration once

## Technical Details

### Modal Behavior
- **Non-dismissible**: Users cannot dismiss by tapping outside or pressing back
- **Close button**: Provides explicit "X" button to cancel
- **PopScope**: Uses `PopScope` (not deprecated `WillPopScope`) with `canPop: false`

### Phone Number Format
- Automatically adds +91 prefix
- Accepts 10-digit numbers
- Validates length before sending OTP

### OTP Verification
- 6-digit PIN input
- Auto-focuses on modal open
- Auto-submits when 6 digits entered
- Resend timer: 60 seconds

### State Management
- Uses Riverpod providers
- Automatically invalidates auth state after conversion
- Updates UI reactively

## Error Handling

The modal handles common errors:

1. **Invalid Phone Number**
   - Shows validation error below input
   - Prevents OTP send until valid

2. **OTP Send Failed**
   - Shows error message
   - Allows retry

3. **Invalid OTP**
   - Shows error message
   - Allows re-entry

4. **Network Issues**
   - Shows timeout error
   - Provides retry option

## Customization

### Change OTP Resend Timer
In `guest_conversion_modal.dart`:
```dart
_resendTimer = 60; // Change to desired seconds
```

### Change Phone Prefix
In `guest_conversion_modal.dart`:
```dart
prefixText: '+91 ', // Change to your country code
```

### Customize Modal Appearance
Modify colors, fonts, and styling in `guest_conversion_modal.dart`:
```dart
decoration: BoxDecoration(
  color: AppTheme.primaryColor.withValues(alpha: 0.1),
  // ... customize styling
),
```

## Future Enhancements

Potential improvements:

1. **Email Option** - Add email + password as alternative to phone
2. **Social Login** - Add "Sign in with Google/Apple" in modal
3. **Analytics** - Track conversion rate from guest to registered
4. **A/B Testing** - Test different modal designs for better conversion
5. **Rewards** - Offer incentive for converting ("Get ₹100 off on first booking")

## Troubleshooting

### Modal Not Showing
- Check that `isGuestUserProvider` is imported
- Verify user is actually logged in as guest
- Check console for errors

### OTP Not Received
- Verify Supabase phone auth is enabled
- Check phone number format (+91 prefix)
- Verify SMS provider is configured in Supabase

### Conversion Not Completing
- Check Supabase auth logs
- Verify network connectivity
- Check that auth providers are invalidated after conversion

## Support

For issues or questions:
1. Check console logs for errors
2. Verify Supabase configuration
3. Review example implementations
4. Test with Supabase dashboard

---

**Created**: February 2026
**Version**: 1.0.0
**Status**: ✅ Production Ready
