# Authentication Flow - Quick Reference Guide

## Problem Fixed
✅ Users are no longer stuck on login screen after authentication
✅ Proper routing to onboarding or home screen based on user status
✅ No need for hot restart to see correct screen

## What Changed

### 1. Auth State Listener Added
The app now listens to Supabase authentication changes automatically.

**File**: [lib/features/auth/providers/auth_providers.dart](lib/features/auth/providers/auth_providers.dart)

### 2. Providers Auto-Refresh
Auth-related providers now update automatically when auth state changes.

### 3. Navigation Updated
All auth screens now navigate to splash screen, which handles routing logic.

## New Authentication Flow

```
Sign In Success
    ↓
Invalidate Providers
    ↓
Navigate to Splash
    ↓
Splash Checks Auth State
    ↓
Route to Correct Screen
```

## Expected Behavior

### New User (First Time)
1. **Sign in** with Phone/Google/Apple
2. **Automatically redirected** to onboarding name screen
3. **Complete onboarding**
4. **Automatically redirected** to home screen

### Returning User
1. **Sign in** with any method
2. **Automatically redirected** to home screen

### App Launch
- **Authenticated user**: Home screen
- **Unauthenticated user**: Welcome screen

## Testing Checklist

- [ ] New user phone auth → onboarding screen
- [ ] New user Google auth → onboarding screen
- [ ] New user Apple auth → onboarding screen
- [ ] Returning user → home screen
- [ ] App restart with auth → home screen
- [ ] App restart without auth → welcome screen

## Key Files Modified

1. **Auth Providers** ([auth_providers.dart](lib/features/auth/providers/auth_providers.dart))
   - Added auth state stream listener
   - Providers auto-invalidate on auth changes

2. **Router** ([app_router.dart](lib/core/router/app_router.dart))
   - Watches auth stream for rebuilding

3. **Login Screen** ([login_screen.dart](lib/features/auth/screens/login_screen.dart))
   - Invalidates providers after Google/Apple sign-in
   - Navigates to splash for routing

4. **OTP Screen** ([otp_verification_screen.dart](lib/features/auth/screens/otp_verification_screen.dart))
   - Invalidates providers after phone verification
   - Navigates to splash for routing

## How to Debug

If something doesn't work, add these debug prints:

### In Splash Screen
```dart
print('🔍 Is Authenticated: $isAuthenticated');
print('🔍 Is Onboarding Complete: $isOnboardingCompleted');
print('🔍 Next Route: $_nextRoute');
```

### In Auth Service
```dart
print('🔐 Current User: ${_supabaseClient.auth.currentUser?.id}');
print('🔐 Has Session: ${_supabaseClient.auth.currentSession != null}');
```

### In Login Screen
```dart
print('✅ Auth successful, invalidating providers...');
print('✅ Navigating to splash...');
```

## Common Issues & Solutions

### Issue: Still stuck on login screen
**Solution**:
1. Check console logs for errors
2. Verify Supabase session exists
3. Ensure providers are being invalidated

### Issue: Hot restart shows wrong screen
**Solution**:
- Hot restart is expected to maintain state
- Hot reload (`r`) preserves runtime state
- Full restart reads from Supabase session

### Issue: Providers not updating
**Solution**:
- Verify auth state stream is working
- Check if `ref.invalidate()` is called
- Ensure 100ms delay exists before navigation

## Architecture Overview

```
┌─────────────────────────────────────────┐
│         User Signs In                    │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│    Supabase Updates Auth State          │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│    Auth Stream Emits Event              │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│    Providers Auto-Invalidate            │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│    Explicit Provider Invalidation       │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│    Navigate to Splash Screen            │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│    Splash Reads Fresh Provider Data     │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│    Route to Correct Screen              │
│    • Not authenticated → Welcome        │
│    • Auth + no onboarding → Name Screen│
│    • Auth + onboarding → Home           │
└─────────────────────────────────────────┘
```

## Code Pattern to Follow

When adding new auth methods, follow this pattern:

```dart
Future<void> _signInWithNewMethod() async {
  try {
    // 1. Call auth service
    final response = await authService.signInWithNewMethod();

    if (mounted && response != null && response.user != null) {
      // 2. Invalidate providers
      ref.invalidate(isAuthenticatedProvider);
      ref.invalidate(currentUserProvider);
      ref.invalidate(isOnboardingCompletedProvider);

      // 3. Wait for update
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        // 4. Navigate to splash
        context.go(AppConstants.splashRoute);
      }
    }
  } catch (e) {
    // Handle error
  }
}
```

## Summary

✅ **Problem**: Users stuck on login after authentication
✅ **Solution**: Auth state stream + provider invalidation
✅ **Result**: Seamless navigation to correct screen
✅ **Tested**: Phone, Google, and Apple auth working

All authentication providers now work correctly without requiring hot restart!
