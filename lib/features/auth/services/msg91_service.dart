import 'package:flutter/foundation.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import '../../../core/constants/app_constants.dart';

/// Thin wrapper around the MSG91 OTP Widget Flutter SDK.
/// Handles client-side OTP send/verify — no secrets in this class.
/// The full authkey lives only in the Supabase Edge Function.
class Msg91Service {
  static bool _initialized = false;
  String? _reqId;

  void _ensureInitialized() {
    if (!_initialized) {
      OTPWidget.initializeWidget(
        AppConstants.msg91WidgetId,
        AppConstants.msg91TokenAuth,
      );
      _initialized = true;
      if (kDebugMode) print('📱 MSG91 OTPWidget initialized');
    }
  }

  /// Sends OTP to [phoneNumber]. Stores reqId internally for verify/retry.
  /// [phoneNumber] must include country code without +, e.g. 919876543210
  Future<void> sendOtp(String phoneNumber) async {
    _ensureInitialized();

    // MSG91 expects country code + number without + prefix: 91XXXXXXXXXX
    final identifier = phoneNumber.startsWith('+')
        ? phoneNumber.substring(1)
        : phoneNumber;

    final response = await OTPWidget.sendOTP({'identifier': identifier});
    if (kDebugMode) print('📱 MSG91 sendOTP response: $response');

    final map = Map<String, dynamic>.from(response as Map);
    final type = (map['type'] as String? ?? '').toLowerCase();
    if (type != 'success') {
      throw Exception(map['message'] ?? 'Failed to send OTP via MSG91');
    }

    // MSG91 Widget SDK returns reqId in the 'message' field on success
    _reqId = map['reqId'] as String? ??
        map['req_id'] as String? ??
        map['message'] as String?;
    if (_reqId == null) throw Exception('MSG91 did not return a reqId');

    if (kDebugMode) print('📱 MSG91 reqId stored: $_reqId');
  }

  /// Verifies [otp] using the stored reqId.
  /// Returns the MSG91 JWT access-token on success.
  Future<String> verifyOtp(String otp) async {
    if (_reqId == null) {
      throw Exception('No active OTP session. Please request a new OTP.');
    }

    final response = await OTPWidget.verifyOTP({'reqId': _reqId, 'otp': otp});
    if (kDebugMode) print('📱 MSG91 verifyOTP response: $response');

    final map = Map<String, dynamic>.from(response as Map);
    final type = (map['type'] as String? ?? '').toLowerCase();
    if (type != 'success') {
      throw Exception(map['message'] ?? 'OTP verification failed');
    }

    // MSG91 Widget SDK returns the JWT access-token in the 'message' field on success
    final accessToken = map['access-token'] as String? ??
        map['access_token'] as String? ??
        map['message'] as String?;
    if (accessToken == null) throw Exception('MSG91 did not return access-token');

    return accessToken;
  }

  /// Retries OTP delivery using the existing reqId.
  Future<void> retryOtp() async {
    if (_reqId == null) throw Exception('No active OTP session.');
    final response = await OTPWidget.retryOTP({'reqId': _reqId});
    if (kDebugMode) print('📱 MSG91 retryOTP response: $response');
  }

  /// Clears the stored reqId after successful verification or on sign-out.
  void clearSession() {
    _reqId = null;
  }
}
