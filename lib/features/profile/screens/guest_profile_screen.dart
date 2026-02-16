import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/guest_user_helper.dart';
import '../../auth/providers/auth_providers.dart';
import '../../home/screens/main_screen.dart';
import '../providers/profile_providers.dart';

class GuestProfileScreen extends ConsumerWidget {
  const GuestProfileScreen({super.key});

  static const Color _primaryBase = Color(0xFF0B4164);
  static const Color _primaryShade = Color(0xFF155D8D);
  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [_primaryBase, _primaryShade],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Color _sheetBackground = Color(0xFFF5F5F7);

  void _handleBack(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    // Fallback for tab-root usage where no route stack exists to pop.
    ref.read(currentIndexProvider.notifier).state = 0;
    router.go(AppConstants.homeRoute);
  }

  Future<void> _handleOtpSignIn(BuildContext context, WidgetRef ref) async {
    final success = await GuestUserHelper.showConversionModal(
      context,
      feature: 'unlocking all features',
    );

    if (success && context.mounted) {
      if (kDebugMode) {
        print('✅ Guest conversion modal returned success');
      }

      // Wait a moment for auth state to propagate through Supabase
      await Future.delayed(const Duration(milliseconds: 300));

      if (!context.mounted) return;

      // Navigate to home screen after successful login
      // Real profile will be available when user taps profile tab
      ref.read(currentIndexProvider.notifier).state = 0;
      GoRouter.of(context).go(AppConstants.homeRoute);

      if (kDebugMode) {
        print('🔄 Navigated to home, real profile ready for profile tab');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = GoRouter.of(context).canPop();
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _sheetBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: _primaryGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(34),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, topInset + 22, 22, 108),
                child: Column(
                  children: [
                    if (canPop)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () => _handleBack(context, ref),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                    const SizedBox(height: 8),
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/Background.png',
                          width: 54,
                          height: 54,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'One app for decor,\nservices and more\nin minutes!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Okra',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -74),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 72,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: _primaryGradient,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _handleOtpSignIn(context, ref),
                                child: const Center(
                                  child: Text(
                                    'Login with OTP',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Okra',
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'By continuing, I accept the terms of service and privacy policy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 13,
                              height: 1.35,
                              fontFamily: 'Okra',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFF2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _GuestActionTile(
                      icon: Icons.info_outline,
                      title: 'About',
                      onTap: () => context.push('/profile/about'),
                    ),
                    const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: Color(0xFFD3D4D8),
                    ),
                    _GuestActionTile(
                      icon: Icons.chat_bubble_outline,
                      title: 'Feedback',
                      onTap: () => context.push('/profile/support'),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 34),
              child: Text(
                'App version ${AppConstants.appVersion}',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 14,
                  fontFamily: 'Okra',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestActionTile extends StatelessWidget {
  const _GuestActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: const Color(0xFF1B1B1D)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Okra',
                    color: Color(0xFF1B1B1D),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: Color(0xFF818186),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
