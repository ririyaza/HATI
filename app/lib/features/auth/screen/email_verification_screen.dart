import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth_navigation.dart';
import 'login_screen.dart';

/// Shown right after signup, or after a login attempt with an unverified
/// email. Polls Firebase for verification status and lets the user resend
/// the verification email.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _resendCooldown = 0;
  bool _isChecking = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified(showFeedback: false));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified({bool showFeedback = true}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

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
        await navigateAfterAuth(context);
        return;
      }

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not verified yet.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 72,
                color: const Color(0xFF0056FF),
              ),
              const SizedBox(height: 24),
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
              Text(
                'We sent a verification link to\n$email\nClick the link, then continue below.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0056FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isChecking ? null : () => _checkVerified(),
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
              const SizedBox(height: 16),
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
                  child: Text(
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
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _signOut,
                child: Text(
                  'Use a different account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
