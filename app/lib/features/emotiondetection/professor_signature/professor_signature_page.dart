// ─────────────────────────────────────────────
// HATI – Professor Signature: entry widget
// professor_signature_page.dart
//
// Used by modules_screen.dart in place of EmotionPage for
// scenarioKey == 'foa_supervisor'. Wraps ScenarioShell in a
// ChangeNotifierProvider<ScenarioProvider>, kicking off `start()` with the
// same Firestore displayName lookup pattern EmotionPage uses
// (scenario_game.dart's `_loadUserDisplayNameFromFirestore`).
// ─────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'scenario_provider.dart';
import 'scenario_shell.dart';

class ProfessorSignaturePage extends StatefulWidget {
  const ProfessorSignaturePage({super.key});

  @override
  State<ProfessorSignaturePage> createState() => _ProfessorSignaturePageState();
}

class _ProfessorSignaturePageState extends State<ProfessorSignaturePage> {
  late final ScenarioProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ScenarioProvider();
    _bootstrap();
  }

  Future<String?> _loadUserDisplayNameFromFirestore(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final raw = doc.data()?['displayName'];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    } catch (_) {}

    final authName = user.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      return authName;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    String? displayName;
    if (user != null) {
      displayName = await _loadUserDisplayNameFromFirestore(user);
    }
    await _provider.start(userId: user?.uid ?? '', userName: displayName);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScenarioProvider>.value(
      value: _provider,
      child: const ScenarioShell(),
    );
  }
}
