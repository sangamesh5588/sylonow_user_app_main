# Sylonow User App

[![Flutter](https://img.shields.io/badge/Flutter-3.8.1-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase)](https://supabase.com)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-blue)](https://flutter.dev)

Sylonow is a modern service marketplace platform designed to help users discover, book, and manage various services (Theater, Cakes, Decorations, etc.) with a beautiful and intuitive user interface.

## 🚀 Features

- **Guest Login**: Explore the app without immediate registration.
- **Smart Onboarding**: Personalized experience based on your name, occasions, and celebration dates.
- **Service Discovery**: 
  - Browse categories (Inside, Outside, Cakes, etc.)
  - Nearby service providers with real-time location tracking.
  - Advanced search and filtering capabilities.
- **Seamless Booking**:
  - Detailed service views with packages and addons.
  - Integrated Razorpay payment gateway.
  - QR-based vendor verification.
- **Profile Management**:
  - Manage multiple addresses with a map-based picker.
  - View booking history and track current orders.
  - Notification system for real-time updates.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Backend**: [Supabase](https://supabase.com) (Auth, Database, Storage)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Payments**: [Razorpay](https://razorpay.com)
- **Maps**: [Google Maps SDK](https://pub.dev/packages/google_maps_flutter)
- **Code Generation**: [Freezed](https://pub.dev/packages/freezed), [Riverpod Generator](https://pub.dev/packages/riverpod_generator)

## 📦 Project Structure

```text
lib/
├── core/               # Shared constants, theme, and utility providers
├── features/           # Feature-based modular architecture
│   ├── auth/           # Authentication flow (Phone, Apple, Guest)
│   ├── booking/        # Service booking and payment logic
│   ├── home/           # Dashboard, discovery, and service listings
│   ├── onboarding/     # User personalization flow
│   ├── profile/        # User settings and history
│   └── ...             # Other modular features (Address, Search, etc.)
└── main.dart           # App entry point
```

## ⚙️ Setup Instructions

### Prerequisites
- Flutter SDK (^3.8.1)
- CocoaPods (for iOS)
- Android Studio / Xcode

### Configuration
1. **Supabase Setup**:
   Ensure your Supabase project is configured and update the keys in [app_constants.dart](file:///Users/arbazkudekar/Downloads/sylonow-user-app-main/lib/core/constants/app_constants.dart).
2. **Google Maps**:
   Add your API keys to:
   - Android: `android/app/src/main/AndroidManifest.xml`
   - iOS: `ios/Runner/AppDelegate.swift`
3. **Razorpay**:
   Update your Razorpay keys in the respective service files.

### Running the App
```bash
# Install dependencies
flutter pub get

# Generate code (freezed/riverpod)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

## 📱 Deployment

### iOS (App Store)
- **Bundle ID**: `com.sylonow.sylonowUser`
- **Version**: `2.2.1+25`
- Ensure "Sign In with Apple" and "Push Notifications" are enabled in the Apple Developer Console.

## 📄 License
This project is proprietary and confidential.
