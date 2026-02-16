import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';

/// Non-dismissible modal for converting guest users to registered users
/// Shows phone number input and OTP verification
class GuestConversionModal extends ConsumerStatefulWidget {
  const GuestConversionModal({
    super.key,
    this.onConversionComplete,
    this.feature = 'this feature',
  });

  final VoidCallback? onConversionComplete;
  final String feature;

  @override
  ConsumerState<GuestConversionModal> createState() =>
      _GuestConversionModalState();
}

class _GuestConversionModalState extends ConsumerState<GuestConversionModal> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoadingOtp = false;
  bool _isVerifying = false;
  bool _showOtpField = false;
  String? _errorMessage;
  int _resendTimer = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendTimer--;
        });
        return _resendTimer > 0;
      }
      return false;
    });
  }

  Future<void> _sendOtp() async {
    // Manual validation
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }
    if (phone.length != 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit number';
      });
      return;
    }

    setState(() {
      _isLoadingOtp = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final phoneNumber = '+91$phone';

      await authService.signInWithPhone(phoneNumber);

      if (mounted) {
        setState(() {
          _isLoadingOtp = false;
          _showOtpField = true;
        });
        _startResendTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOtp = false;
          _errorMessage = e.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final phoneNumber = '+91${_phoneController.text.trim()}';

      final response = await authService.verifyPhoneOtpAndSignIn(
        phoneNumber: phoneNumber,
        otp: _otpController.text.trim(),
      );

      if (response.user != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Small delay for user to see success message and for auth state to propagate
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          // Invalidate auth providers to force refresh
          ref.invalidate(isAuthenticatedProvider);
          ref.invalidate(currentUserProvider);
          ref.invalidate(isGuestUserProvider);
          ref.invalidate(currentUserProfileProvider);

          // Force providers to rebuild by reading them
          // This ensures fresh data is loaded before we close the modal
          try {
            await ref.read(isAuthenticatedProvider.future);
            await ref.read(isGuestUserProvider.future);
          } catch (e) {
            // Ignore errors during provider refresh
          }

          // Call completion callback if provided
          widget.onConversionComplete?.call();

          // Close the modal - providers have fresh data now
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Invalid OTP. Please try again.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      // Prevent dismissal by back button
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomPanelHeight = constraints.maxHeight * 0.62;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 92,
                    left: 24,
                    right: 24,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 82,
                          height: 82,
                          child: Image.asset(
                            'assets/images/Background.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Book celebrations in minutes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.2,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Okra',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      height: bottomPanelHeight,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(38),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          26,
                          24,
                          24 + viewInsets + bottomSafeInset,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                child: SizedBox(
                                  width: 44,
                                  child: Divider(
                                    thickness: 4,
                                    color: Color(0xFFD9D9D9),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _showOtpField ? 'Verify OTP' : 'Login',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                  fontFamily: 'Okra',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _showOtpField
                                    ? 'Enter OTP sent to +91${_phoneController.text}'
                                    : 'Enter your phone number',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontFamily: 'Okra',
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (!_showOtpField) ...[
                                Container(
                                  width: double.infinity,
                                  height: 58,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: const Color(0xFF0B4164),
                                      width: 1.8,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        '🇮🇳',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        '+91',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF212529),
                                          fontFamily: 'Okra',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 1.5,
                                        height: 26,
                                        color: const Color(0xFFD1D5DB),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          autofillHints: const <String>[],
                                          enableSuggestions: false,
                                          autocorrect: false,
                                          enableInteractiveSelection: true,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          maxLength: 10,
                                          cursorColor: const Color(0xFF0B4164),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF212529),
                                            fontFamily: 'Okra',
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: '9876543210',
                                            hintStyle: TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFFA8B2BC),
                                              fontWeight: FontWeight.w400,
                                              fontFamily: 'Okra',
                                            ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            errorBorder: InputBorder.none,
                                            focusedErrorBorder: InputBorder.none,
                                            counterText: '',
                                            contentPadding: EdgeInsets.zero,
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    onPressed: _isLoadingOtp ? null : _sendOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(32),
                                      ),
                                    ),
                                    child: _isLoadingOtp
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'CONTINUE',
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                  fontFamily: 'Okra',
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                              if (_showOtpField) ...[
                                Center(
                                  child: Pinput(
                                    controller: _otpController,
                                    length: 6,
                                    autofocus: true,
                                    onCompleted: (_) => _verifyOtp(),
                                    defaultPinTheme: PinTheme(
                                      width: 46,
                                      height: 52,
                                      textStyle: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[350]!,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    focusedPinTheme: PinTheme(
                                      width: 46,
                                      height: 52,
                                      textStyle: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppTheme.primaryColor,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: _resendTimer > 0
                                      ? Text(
                                          'Resend OTP in $_resendTimer seconds',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                            fontFamily: 'Okra',
                                          ),
                                        )
                                      : TextButton(
                                          onPressed: _sendOtp,
                                          child: const Text(
                                            'Resend OTP',
                                            style: TextStyle(
                                              fontFamily: 'Okra',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isVerifying ? null : _verifyOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isVerifying
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'VERIFY & CONTINUE',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'Okra',
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showOtpField = false;
                                        _otpController.clear();
                                        _errorMessage = null;
                                      });
                                    },
                                    child: const Text(
                                      'Change Phone Number',
                                      style: TextStyle(fontFamily: 'Okra'),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                      fontFamily: 'Okra',
                                      height: 1.45,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text:
                                            'By continuing, you agree to our\n',
                                      ),
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 12,
                                      fontFamily: 'Okra',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
