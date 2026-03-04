class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://txgszrxjyanazlrupaty.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4Z3N6cnhqeWFuYXpscnVwYXR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNzU4MjcsImV4cCI6MjA2NTg1MTgyN30.7MDiDGMCEa-E8c3HgIGxSpkOsH9kClD5i5LNSjzFul4';

  // App Information
  static const String appName = 'Sylonow';
  static const String appVersion = '2.2.2';

  // Shared Preferences Keys
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  static const String userPhoneKey = 'user_phone';
  static const String isLoggedInKey = 'is_logged_in';
  static const String isGuestKey = 'is_guest';

  // MSG91 OTP Widget
  static const String msg91WidgetId = '366274677442303433393835';
  // tokenAuth is widget-specific and safe to embed in client apps (not the full authkey)
  static const String msg91TokenAuth = '495150T9dnXSDMY69a09988P1';

  // Routes
  static const String splashRoute = '/';
  static const String welcomeRoute = '/welcome';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String otpVerificationRoute = '/otp-verification';
  static const String homeRoute = '/home';
  static const String profileRoute = '/profile';
}
