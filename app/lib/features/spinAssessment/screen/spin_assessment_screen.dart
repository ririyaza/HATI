import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/spin_questions.dart';
import '../../dashboard/screen/dashboard_screen.dart';
import 'low_score_exit_screen.dart';
import 'spin_result_screen.dart';

class SpinAssessmentScreen extends StatefulWidget {
  const SpinAssessmentScreen({super.key});

  @override
  State<SpinAssessmentScreen> createState() => _SpinAssessmentScreenState();
}

class _SpinAssessmentScreenState extends State<SpinAssessmentScreen> {
  bool _started = false;
  int currentIndex = 0;

  static const _options = [
    'Not at all',
    'A little bit',
    'Somewhat',
    'Very much',
    'Extremely',
  ];

  // Brand blue used throughout
  static const _blue = Color(0xFF0B28D9);

  @override
  void initState() {
    super.initState();
    _guardAgainstRetake();
  }

  Future<void> _guardAgainstRetake() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      if (!mounted) return;
      if (data['accessBlocked'] == true) {
        final raw = data['initialSpinScore'];
        final score = raw is num ? raw.toInt() : 0;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LowScoreExitScreen(score: score)),
        );
        return;
      }
      if (data['initialSpinCompleted'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (_) {}
  }

  void _nextQuestion() {
    if (currentIndex < spinQuestions.length - 1) {
      setState(() => currentIndex++);
    } else {
      final total = spinQuestions.fold(
        0,
        (sum, q) => sum + (q.selectedScore ?? 0),
      );
      _recordAndNavigate(total);
    }
  }

  void _previousQuestion() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    } else {
      setState(() => _started = false);
    }
  }

  Future<void> _handleDoThisLater() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _DoThisLaterDialog(),
    );
    if (shouldExit == true && mounted) {
      SystemNavigator.pop();
    }
  }

  Future<void> _recordAndNavigate(int totalScore) async {
    final themeRawScores = <String, int>{};
    final themeAverages = <String, double>{};

    for (final question in spinQuestions) {
      final theme = question.theme;
      final score = question.selectedScore ?? 0;
      themeRawScores[theme] = (themeRawScores[theme] ?? 0) + score;
    }

    for (final entry in themeRawScores.entries) {
      final theme = entry.key;
      final raw = entry.value;
      final average = theme == 'Fear of Negative Evaluation & Embarassment'
          ? raw / 20 * 100
          : theme == 'Physiological Symptoms'
          ? raw / 16 * 100
          : raw / 8 * 100;
      themeAverages[theme] = average;
    }

    var priorityScenario = '';
    var maxAverage = -1.0;
    final candidates = <String>[];
    for (final entry in themeAverages.entries) {
      if (entry.value > maxAverage) {
        maxAverage = entry.value;
        candidates
          ..clear()
          ..add(entry.key);
      } else if (entry.value == maxAverage) {
        candidates.add(entry.key);
      }
    }
    if (candidates.isNotEmpty) {
      candidates.shuffle();
      priorityScenario = candidates.first;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      try {
        await ref.collection('spinAssessments').doc('initial').set({
          'score': totalScore,
          'themeRawScores': themeRawScores,
          'themeAverages': themeAverages,
          'priorityScenario': priorityScenario,
          'completedAt': FieldValue.serverTimestamp(),
        });
        await ref.set({
          'initialSpinScore': totalScore,
          'initialSpinCompleted': true,
          'initialSpinCompletedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SpinResultScreen(score: totalScore)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _started ? _buildQuestionScreen() : _buildIntroScreen();
  }

  // ─────────────────────────────────────────────────────────────
  // INTRO SCREEN  (no scroll — fills the viewport exactly)
  // ─────────────────────────────────────────────────────────────
  Widget _buildIntroScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Blue header ──────────────────────────────────────
            Container(
              width: double.infinity,
              color: _blue,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: const [
                  Text(
                    'HATI',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Social Comfort Check-in',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // ── Body — expands to fill remaining space ───────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info card
                    _InfoCard(
                      icon: Icons.checklist_rounded,
                      title: 'What to expect',
                      body:
                          '17 short questions about how social situations feel '
                          'for you. No right or wrong answers — just honest ones.',
                    ),
                    const SizedBox(height: 20),

                    // Quick-facts
                    _FactRow(
                      icon: Icons.timer_outlined,
                      text: 'Takes about 3–5 minutes',
                    ),
                    const SizedBox(height: 12),
                    _FactRow(
                      icon: Icons.lock_outline,
                      text: 'Your answers are private',
                    ),
                    const SizedBox(height: 12),
                    _FactRow(
                      icon: Icons.tune_rounded,
                      text: 'Personalizes your HATI experience',
                    ),

                    const Spacer(),

                    // Buttons
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: () => setState(() => _started = true),
                      child: const Text(
                        'Begin Check-in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black12),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: _handleDoThisLater,
                      child: const Text(
                        'Do this later',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Disclaimer
                    const Text(
                      'This is not a diagnostic test. Your responses are used\n'
                      'only for research and personalization.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black38,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // QUESTION SCREEN  (no scroll — fills the viewport exactly)
  // ─────────────────────────────────────────────────────────────
  Widget _buildQuestionScreen() {
    final question = spinQuestions[currentIndex];
    final progress = (currentIndex + 1) / spinQuestions.length;
    final hasAnswer = question.selectedScore != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Blue header with progress ──────────────────────
            Container(
              color: _blue,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HATI',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Question ${currentIndex + 1} of ${spinQuestions.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Question text ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAST WEEK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black38,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${question.question}"',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'HOW MUCH DOES THIS DESCRIBE YOU?',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // ── Options — expand to fill remaining space ───────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Column(
                  children: List.generate(_options.length, (i) {
                    final selected = question.selectedScore == i;
                    final isLast = i == _options.length - 1;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                        child: _OptionTile(
                          label: _options[i],
                          selected: selected,
                          onTap: () =>
                              setState(() => question.selectedScore = i),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // ── Bottom: nav buttons + disclaimer ──────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          onPressed: _previousQuestion,
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              disabledBackgroundColor: _blue.withOpacity(0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: hasAnswer ? _nextQuestion : null,
                            child: Text(
                              currentIndex == spinQuestions.length - 1
                                  ? 'Finish'
                                  : 'Next',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This is not a diagnostic test. Your responses are used\n'
                    'only for research and personalization.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black38,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────

class _DoThisLaterDialog extends StatelessWidget {
  const _DoThisLaterDialog();

  static const _blue = Color(0xFF0B28D9);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: _blue,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Come back anytime',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You can finish your Social Comfort Check-in later when '
                'you\'re ready. Your progress is saved when you sign in again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Exit app',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Stay',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
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

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _blue = Color(0xFF0B28D9);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _blue : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _blue : Colors.black87,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _blue : Colors.white,
                border: Border.all(
                  color: selected ? _blue : const Color(0xFFCCCCCC),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0B28D9), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B28D9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF333333),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE8ECFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF0B28D9), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
