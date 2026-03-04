# Sylonow User App

Sylonow User is a Flutter-based service marketplace app for discovering and booking decoration, theater, and event-related services with advance payment flow, live booking tracking, and address-aware checkout.

## Why This App

- Customer-first booking flow with service detail, add-ons, slot selection, and checkout.
- Multiple business domains in one app: inside services, outside services, and private theater booking.
- Supabase-backed architecture for auth, data, and edge functions.
- Razorpay-integrated payment flow with booking/payment status updates.

## Core Features

- Phone/OTP and social auth flows
- Service listing and detail with pricing logic
- Add-on selection with customizable add-on input support
- Booking date/time slot selection with notice/setup logic
- Address management and address-aware checkout
- Payment split display (advance vs remaining)
- Booking success screen with QR details
- Booking history with status timeline
- Notifications via Supabase Edge Functions

## Tech Stack

- Flutter (Dart)
- Riverpod (state management)
- GoRouter (routing)
- Supabase (auth, DB, functions)
- Razorpay (payments)
- Firebase Messaging + Local Notifications

## Project Structure

```text
lib/
  core/
    constants/      # global constants
    router/         # app routing
    theme/          # design tokens/theme
    utils/          # calculators/helpers
    widgets/        # reusable UI widgets
  features/
    auth/
    address/
    home/
    services/
    booking/
    outside/
    theater/
    profile/
    payment/
    ...
supabase/
  functions/        # edge functions
assets/             # images/svgs/animations/fonts
```

## Prerequisites

- Flutter SDK compatible with `sdk: ^3.8.1`
- Xcode (for iOS builds)
- Android Studio + Android SDK (for Android builds)
- Supabase project
- Razorpay account

## Quick Start

```bash
# 1) Install dependencies
flutter pub get

# 2) Generate code (freezed/json/riverpod)
dart run build_runner build --delete-conflicting-outputs

# 3) Run app
flutter run
```

## Environment and Configuration

### 1) Supabase

Current app-level constants are in:

- `lib/core/constants/app_constants.dart`

If you change project/ref keys, update this file accordingly.

### 2) Razorpay

Razorpay integration exists in:

- `lib/features/booking/services/razorpay_service.dart`
- `lib/features/outside/services/razorpay_payment_service.dart`
- `lib/features/theater/screens/theater_checkout_screen.dart`

If you switch keys/mode (test/live), update Razorpay key configuration before release.

### 3) Firebase

Make sure Firebase config files and notification setup are completed for each platform before production release.

## Supabase Edge Functions

Function source location:

- `supabase/functions/`

Current functions include:

- `notify-vendor-booking`
- `notify-vendor-order`
- `vendor-notification`
- `msg91-auth-user`
- `create-razorpay-order`
- `verify-razorpay-payment`

Deploy examples:

```bash
supabase functions deploy create-razorpay-order --project-ref <project-ref>
supabase functions deploy verify-razorpay-payment --project-ref <project-ref>
```

## Add-on Customization Schema Update

Add-on customization is now per add-on entry in `order_add_ons.customisation_input`.
Do not use `orders.customisation_input` for add-on-specific values.

Expected behavior in app:

- Show input UI for add-ons where `is_customizable = true`
- Respect `customization_input_type` (`text` or `number`)
- Save input into `order_add_ons.customisation_input` during order creation
- Show saved customization in checkout/order summary and details screens

## Useful Commands

```bash
# Static analysis
flutter analyze

# Run tests
flutter test

# iOS pods (if needed)
cd ios && pod install && cd ..
```

## Documentation Index

Key guides in this repo:

- `PRODUCTION_DEPLOYMENT_GUIDE.md`
- `API_KEYS_CONFIGURATION.md`
- `PAYMENT_FIRST_FLOW_IMPLEMENTATION.md`
- `THEATER_TAX_CALCULATION_BACKEND.md`
- `APP_UPDATE_TESTING_GUIDE.md`
- `GOOGLE_MAPS_SETUP.md`

## Release Notes

Current app version:

- `2.3.0+30`

Update version in `pubspec.yaml` for each release.

## Security Notes

- Never commit raw API secrets to Git.
- Keep payment secret keys server-side wherever possible.
- Rotate keys immediately if any secret was exposed.

## Ownership

This repository contains the user-facing mobile app for the Sylonow platform.
