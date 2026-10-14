import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/spin_scoring.dart';
import 'assessment_complete_screen.dart';
import 'spin_result_visuals.dart';
import 'triggers_and_coping_screen.dart';
import 'low_score_exit_screen.dart';
import '../../../shared/offline/action_feedback.dart';
import '../../../shared/offline/connectivity_service.dart';
import '../../../shared/offline/offline_save.dart';
import '../../../shared/audio/score_sounds.dart';

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────
class SpinResultScreen extends StatefulWidget {
  final int score;
  const SpinResultScreen({super.key, required this.score});

  @override
  State<SpinResultScreen> createState() => _SpinResultScreenState();
}

class _SpinResultScreenState extends State<SpinResultScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxScore = 68; // SPIN max

  late AnimationController _animCtrl;
  late Animation<double> _arcAnim;
  late Animation<double> _fadeAnim;
  late final ScoreAnimationSounds _scoreSounds;

  SpinScoreTier get _tier => spinScoreTierFor(widget.score);

  bool get _qualifies => spinQualifies(widget.score);

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _arcAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _scoreSounds = ScoreAnimationSounds(_arcAnim);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _scoreSounds.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final user = FirebaseAuth.instance.currentUser;
    DocumentReference<Map<String, dynamic>>? userRef;

    if (user != null) {
      userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (!_qualifies) {
        // This flag is what actually keeps a low-scoring user out of the
        // app on their next login (_guardAgainstRetake in
        // spin_assessment_screen.dart checks it) — silently swallowing a
        // failure here used to mean the access block just never took
        // effect, with nothing telling anyone it hadn't saved.
        await _saveWithRetryDialog(
          (batch) => batch.set(userRef!, {
            'accessBlocked': true,
          }, SetOptions(merge: true)),
        );
      }
    }

    if (!mounted) return;

    if (!_qualifies) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LowScoreExitScreen(score: widget.score),
        ),
      );
      return;
    }

    // Skip does not save coping — user can return to triggers. Continue with
    // input saves initialCopingMechanism and skips triggers on next visit.
    var hasSavedCoping = false;
    if (userRef != null) {
      try {
        // Offline, a default get() waits on the server before falling back
        // to cache — go straight to the cached doc so Continue responds.
        final doc = await userRef.get(
          ConnectivityService.instance.isOnline
              ? const GetOptions()
              : const GetOptions(source: Source.cache),
        );
        final data = doc.data() ?? {};
        final coping = data['initialCopingMechanism'];
        hasSavedCoping = coping is String && coping.trim().isNotEmpty;
      } catch (_) {}
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => hasSavedCoping
            ? AssessmentCompleteScreen(score: widget.score)
            : TriggersAndCopingScreen(score: widget.score),
      ),
    );
  }

  /// Retries [save] on failure via a blocking dialog that explains what
  /// happened instead of failing silently — returns true once it actually
  /// succeeds, or false if the user explicitly chooses to skip.
  ///
  /// Offline isn't a failure: [OfflineSave] queues the write on-device and
  /// it syncs on reconnect, so the user just gets a heads-up and moves on.
  Future<bool> _saveWithRetryDialog(
    void Function(WriteBatch batch) build,
  ) async {
    while (true) {
      try {
        final outcome = await OfflineSave.run(build);
        if (mounted && outcome == SaveOutcome.savedOffline) {
          ActionFeedback.saved(
            context,
            outcome,
            offlineMessage:
                "You're offline. Your results are saved on this device and "
                'will sync when you reconnect.',
          );
        }
        return true;
      } catch (e) {
        if (!mounted) return false;
        final action = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Couldn't Save Your Results"),
            content: Text(
              ActionFeedback.messageFor(
                e,
                fallback: "We couldn't save your assessment. Please try again.",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'skip'),
                child: const Text('Skip for now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'retry'),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        if (action != 'retry') return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = spinResultThemes[_tier]!;
    final progress = (widget.score / _maxScore).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      body: Column(
        children: [
          // ── Hero header ─────────────────────────────────────
          SpinResultHeroHeader(
            theme: theme,
            progress: progress,
            arcAnim: _arcAnim,
            score: widget.score,
          ),

          // ── Body content ────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Badge chip
                    Align(
                      alignment: Alignment.center,
                      child: SpinResultBadgeChip(
                        label: theme.badge,
                        color: theme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Headline
                    Text(
                      theme.headline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle interpretation
                    Text(
                      theme.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF64748B),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Info card
                    SpinResultInfoCard(theme: theme, qualifies: _qualifies),
                    const SizedBox(height: 32),

                    // CTA button
                    SpinResultActionButton(
                      color: theme.primary,
                      onTap: _onContinue,
                      label: _qualifies ? 'Start My Journey' : 'See My Results',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
