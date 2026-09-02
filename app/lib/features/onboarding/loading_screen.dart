import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/auth_navigation.dart';
import '../auth/screen/email_verification_screen.dart';
import '../auth/screen/login_screen.dart';
import '../auth/session_persistence.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _resolveStartDestination);
  }

  /// Decides where the splash sends the user: straight back to the
  /// dashboard (or wherever their onboarding left off) if they signed in
  /// within the last [sessionReloginInterval], otherwise the login screen.
  /// Firebase Auth itself would keep a user signed in indefinitely, so the
  /// monthly expiry is enforced here on top of that, via
  /// `session_persistence.dart`.
  Future<void> _resolveStartDestination() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _goTo(const LoginScreen());
      return;
    }

    // Anything below this point (local storage, Firestore) can fail for
    // reasons unrelated to whether the session is actually valid — a
    // storage-plugin hiccup shouldn't stroll this splash screen forever.
    // On any unexpected error, fail safe to the login screen rather than
    // leaving the user stuck with no way forward.
    try {
      final stillValid = await isLoginSessionStillValid();
      if (!mounted) return;

      if (!stillValid) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        _goTo(const LoginScreen());
        return;
      }

      if (user.emailVerified != true) {
        _goTo(const EmailVerificationScreen());
        return;
      }

      await navigateAfterAuth(context);
    } catch (_) {
      if (!mounted) return;
      _goTo(const LoginScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF0B28D9),
        child: const Center(
          child: Text(
            'HATI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
