// ─────────────────────────────────────────────
// HATI – Professor Signature Scenario Shell
// screens/scenario_shell.dart
//
// Ported from testing_env/lib/theme1_scenario_shell.dart minus its
// standalone MaterialApp/entry point: just the scene-swapping
// AnimatedSwitcher plus the resume-dialog wiring (mirroring
// scenario_game.dart's "Resume scenario?" AlertDialog pattern at
// scenario_game.dart:262-287).
//
// The dashboard scene's "Close" action (and this shell's resume "Start
// over" flow) call Navigator.pop(context) rather than popUntil, mirroring
// EmotionPage's exit behavior so this screen returns cleanly to whatever
// pushed it.
// ─────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'scene0_pre_setup.dart';
import 'scene1_office_pies.dart';
import 'scene2_preparation.dart';
import 'scene3_interaction.dart';
import 'scene4_debrief.dart';
import 'scene5_coping.dart';

class ScenarioShell extends StatefulWidget {
  const ScenarioShell({super.key});

  @override
  State<ScenarioShell> createState() => _ScenarioShellState();
}

class _ScenarioShellState extends State<ScenarioShell> {
  bool _resumeDialogHandled = false;

  Future<void> _maybeShowResumeDialog(ScenarioProvider provider) async {
    if (!provider.pendingResume || _resumeDialogHandled) return;
    _resumeDialogHandled = true;

    final chooseContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Resume scenario?"),
        content: const Text(
          "A previous scenario exists. Do you want to continue it or start over?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Start over"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Continue"),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (chooseContinue == true) {
      await provider.confirmResume();
    } else {
      await provider.discardResume();
    }
  }

  void _maybeShowError(ScenarioProvider provider) {
    final err = provider.errorMessage;
    if (err == null) return;
    provider.clearError();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowResumeDialog(provider);
      _maybeShowError(provider);
    });

    final scene = provider.currentScene;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: _buildScene(scene),
    );
  }

  Widget _buildScene(SceneId scene) {
    switch (scene) {
      case SceneId.preScene:
        return const Scene0PreSetup(key: ValueKey('scene0'));
      case SceneId.office:
        return const Scene1OfficePies(key: ValueKey('scene1'));
      case SceneId.preparation:
        return const Scene2Preparation(key: ValueKey('scene2'));
      case SceneId.interaction:
        return const Scene3Interaction(key: ValueKey('scene3'));
      case SceneId.debrief:
        return const Scene4Debrief(key: ValueKey('scene4'));
      case SceneId.coping:
        return const Scene5Coping(key: ValueKey('scene5'));
      case SceneId.closing:
        return const Scene6Closing(key: ValueKey('scene6'));
      case SceneId.dashboard:
        return const _ScenarioDashboardScene(key: ValueKey('dashboard'));
    }
  }
}

// ── Dashboard return screen ─────────────────────────────────────────────────
class _ScenarioDashboardScene extends StatelessWidget {
  const _ScenarioDashboardScene({super.key});

  Future<Map<String, int>> _loadEmotionCounts(String? sessionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || sessionId == null) return {};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scenarios')
        .doc(sessionId)
        .collection('emotionLogs')
        .get();

    final counts = <String, int>{};
    for (final doc in snapshot.docs) {
      final emotion = (doc.data()['emotion'] ?? '').toString().trim().toLowerCase();
      if (emotion.isEmpty) continue;
      counts[emotion] = (counts[emotion] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _showProgressDialog(BuildContext context, String? sessionId) async {
    final counts = await _loadEmotionCounts(sessionId);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emotion Summary'),
        content: sorted.isEmpty
            ? const Text('No emotion logs are available yet.')
            : SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sorted
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                e.key.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('${e.value}'),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final summary = joinMessageText(provider.messages, separator: ' ');

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🐸', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            const Text(
              'Great work!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                summary.isNotEmpty
                    ? summary
                    : "I've logged your emotions. Over time, you'll see patterns.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 40),
            for (final opt in provider.ui.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (opt == 'Close') {
                      // Pop immediately, client-side, without waiting on a
                      // network round trip — mirrors EmotionPage's exit.
                      Navigator.pop(context);
                      return;
                    }
                    if (opt == 'Open Progress') {
                      await _showProgressDialog(context, provider.sessionId);
                      if (context.mounted) {
                        await provider.submitText(opt);
                      }
                      return;
                    }
                    await provider.submitText(opt);
                  },
                  icon: Icon(opt == 'Close' ? Icons.close : Icons.bar_chart_rounded),
                  label: Text(opt),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
