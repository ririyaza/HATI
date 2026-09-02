import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/screen/admin_inbox_screen.dart';
import '../dashboard/screen/dashboard_screen.dart';
import '../onboarding/consent_intro_screen.dart';
import '../onboarding/profile_setup_screen.dart';
import '../spinAssessment/screen/spin_assessment_screen.dart';
import '../spinAssessment/screen/low_score_exit_screen.dart';
import 'session_persistence.dart';

/// Decides which screen to show once a user is signed in and verified,
/// based on their onboarding progress stored in Firestore, and replaces
/// the current route with it.
///
/// Every call site represents a confirmed, active signed-in session — a
/// fresh login, a completed email verification, or [LoadingScreen]
/// resuming an already-signed-in user on app open — so this is also the
/// single place that refreshes the "stay logged in" timestamp
/// (see `session_persistence.dart`).
Future<void> navigateAfterAuth(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await recordLoginTimestamp();

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  final data = doc.data() ?? {};

  if (!context.mounted) return;

  if (data['role'] == 'admin') {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminInboxScreen()),
    );
    return;
  }

  if (data['accessBlocked'] == true) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LowScoreExitScreen(score: (data['initialSpinScore'] ?? 0) as int),
      ),
    );
    return;
  }

  final consentGiven = data['consentGiven'] == true;
  final profileCompleted = data['profileCompleted'] == true;
  final initialSpinCompleted = data['initialSpinCompleted'] == true;

  Widget next;
  if (!consentGiven) {
    next = const ConsentIntroScreen();
  } else if (!profileCompleted) {
    next = const ProfileSetupScreen();
  } else if (!initialSpinCompleted) {
    next = const SpinAssessmentScreen();
  } else {
    next = const DashboardScreen();
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => next),
  );
}
