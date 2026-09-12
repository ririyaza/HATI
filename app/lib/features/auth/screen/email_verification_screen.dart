import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth_navigation.dart';
import 'login_screen.dart';

/// Shown right after signup, or after a login attempt with an unverified
/// email. Polls Firebase for verification status and lets the user resend
/// the verification email.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, this.returnToLoginOnVerified = false});

  /// When true (the fresh-signup path), a successful verification signs the
  /// user back out and sends them to [LoginScreen] to log in with their new
  /// credentials, instead of continuing straight into onboarding — signup
  /// creates a session, but shouldn't count as the user's first real login.
  final bool returnToLoginOnVerified;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _resendCooldown = 0;
  bool _isChecking = false;
  bool _isResending = false;

  // Slow breathing ring behind the mail icon — a quiet visual cue that the
  // screen is alive and watching for verification in the background, since
  // the actual poll (below) deliberately makes no UI noise of its own.
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerified(manual: false),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// [manual] distinguishes a user-initiated tap (which should show a
  /// spinner on the button and a snackbar if still unverified) from the
  /// silent background poll — toggling `_isChecking` on every 3-second poll
  /// tick made the button flash a spinner in and out continuously, which is
  /// the flicker this parameter avoids.
  Future<void> _checkVerified({bool manual = true}) async {
    if (manual) {
      if (_isChecking) return;
      setState(() => _isChecking = true);
    }

    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      if (user.emailVerified) {
        _pollTimer?.cancel();
        if (!mounted) return;
        if (widget.returnToLoginOnVerified) {
          await _confirmVerifiedThenReturnToLogin();
        } else {
          await navigateAfterAuth(context);
        }
        return;
      }

      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not verified yet.')),
        );
      }
    } finally {
      if (manual && mounted) setState(() => _isChecking = false);
    }
  }

  /// Confirms the fresh-signup verification, then signs out and returns to
  /// [LoginScreen] — this screen isn't watching a reactive auth-state
  /// stream, so `context` stays valid across the `await`s below.
  Future<void> _confirmVerifiedThenReturnToLogin() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => _EmailVerifiedDialog(
        onContinue: () => Navigator.pop(ctx),
      ),
    );
    if (!mounted) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _resendEmail() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() => _isResending = true);

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Check your inbox.'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'too-many-requests'
          ? 'Too many requests. Please wait a moment before trying again.'
          : e.message ?? 'Failed to send verification email.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown <= 1) {
          _resendCooldown = 0;
          timer.cancel();
        } else {
          _resendCooldown--;
        }
      });
    });
  }

  Future<void> _signOut() async {
    _pollTimer?.cancel();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      _PulsingMailIcon(controller: _pulseCtrl),
                      const SizedBox(height: 28),
                      Text(
                        'Verify your email',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text.rich(
                        TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(
                              text: 'We sent a verification link to\n',
                            ),
                            TextSpan(
                              text: email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const TextSpan(
                              text: '.\nClick the link, then continue below.',
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "This page updates on its own once you're "
                            'verified.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD966)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Color(0xFF8A6500),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Can't find the email? Check your spam or "
                                'junk folder.',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF8A6500),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 3),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0056FF),
                            disabledBackgroundColor: const Color(
                              0xFF0056FF,
                            ).withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isChecking
                              ? null
                              : () => _checkVerified(manual: true),
                          child: _isChecking
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "I've verified my email",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          onPressed: (_resendCooldown > 0 || _isResending)
                              ? null
                              : _resendEmail,
                          child: _isResending
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              : Text(
                                  _resendCooldown > 0
                                      ? 'Resend email (${_resendCooldown}s)'
                                      : 'Resend verification email',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _signOut,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                        ),
                        icon: const Icon(
                          Icons.switch_account_outlined,
                          size: 18,
                        ),
                        label: Text(
                          'Use a different account',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Mail icon in a soft circular badge with a slow breathing ring behind it —
/// purely decorative, signalling "still listening" without the flicker a
/// state-driven indicator (tied to the poll timer) would cause.
class _PulsingMailIcon extends StatelessWidget {
  const _PulsingMailIcon({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final t = controller.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96 + 24 * t,
                  height: 96 + 24 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0056FF).withOpacity(0.08 * (1 - t)),
                  ),
                ),
                child!,
              ],
            );
          },
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0056FF).withOpacity(0.08),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.mark_email_unread_outlined,
              size: 48,
              color: Color(0xFF0056FF),
            ),
          ),
        ),
      ),
    );
  }
}

/// Success dialog shown once the fresh-signup verification is confirmed —
/// styled to match [_ConsentSuccessDialog] in `consent_flow_screen.dart`
/// (the one shown right before profile setup): a rounded white card, a
/// tinted circular icon badge, a bold headline, and a single full-width
/// pill button, instead of a plain [AlertDialog].
class _EmailVerifiedDialog extends StatelessWidget {
  const _EmailVerifiedDialog({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0056FF).withOpacity(0.1),
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                color: Color(0xFF0056FF),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Email Verified',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0056FF),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your email has been verified. Please log in with your new '
              'credentials to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: onContinue,
                child: const Text(
                  'Continue to Login',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
