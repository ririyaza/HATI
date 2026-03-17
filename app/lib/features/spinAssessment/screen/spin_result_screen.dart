import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'triggers_and_coping_screen.dart';
import 'low_score_exit_screen.dart';

class SpinResultScreen extends StatelessWidget {
  final int score;

  const SpinResultScreen({super.key, required this.score});

  static const int severeThreshold = 40;

  String interpretation(int score) {
    if (score <= 19) {
      return "You report very few difficulties in social situations.";
    } else if (score <= 30) {
      return "You report some challenges in social situations.";
    } else if (score <= 40) {
      return "You report moderate challenges in social situations.";
    } else if (score <= 50) {
      return "You report significant challenges in social situations.";
    } else {
      return "You report very significant challenges in social situations.";
    }
  }

  bool get _isSevereOrHigher => score > severeThreshold;

  void _onContinue(BuildContext context) {
    _recordOutcomeAndNavigate(context);
  }

  Future<void> _recordOutcomeAndNavigate(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      try {
        await userRef.set(
          {
            if (!_isSevereOrHigher) 'accessBlocked': true,
          },
          SetOptions(merge: true),
        );
      } catch (_) {
        // Ignore write errors here.
      }
    }

    if (!_isSevereOrHigher) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LowScoreExitScreen(score: score),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TriggersAndCopingScreen(score: score),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE6F0FF),
                    border: Border.all(
                      color: const Color(0xFF007AFF),
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF007AFF),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Assessment Complete',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF007AFF),
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F3FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Your Score:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B2559),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2559),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  interpretation(score),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0056FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: () => _onContinue(context),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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
