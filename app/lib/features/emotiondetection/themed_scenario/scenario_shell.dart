// ─────────────────────────────────────────────
// HATI – Themed Scenario Shell
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

import '../../dashboard/widgets/draggable_help_button.dart';
import 'app_theme.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'scene0_pre_setup.dart';
import 'scene1_office_pies.dart';
import 'scene2_preparation.dart';
import 'scene3_interaction.dart';
import 'scene4_debrief.dart';
import 'scene5_coping.dart';
import 'shared_widgets.dart';

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
      builder: (context) => const _ResumeScenarioDialog(),
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

    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: _buildScene(scene),
        ),
        const Positioned.fill(child: DraggableHelpButton()),
      ],
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

// ── Resume scenario dialog ───────────────────────────────────────────────────
class _ResumeScenarioDialog extends StatelessWidget {
  const _ResumeScenarioDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: HatiColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: const BoxDecoration(
                // Brand blue (0xFF0B28D9) — same header color as the
                // Progress and Profile screens — rather than this dialog
                // family's usual green, matching the Badge Unlocked dialog.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B28D9), Color(0xFF081F9E)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: HatiColors.softGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Resume Scenario?',
                      style: HatiTextStyles.heading3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'A previous scenario is already in progress. Would you like '
                'to pick up where you left off, or start over from the '
                'beginning?',
                style: HatiTextStyles.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: HatiButton(
                      label: 'Continue',
                      icon: Icons.play_arrow_rounded,
                      color: HatiColors.mossGreen,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ),
                  const SizedBox(height: 10),
                  HatiOutlineButton(
                    label: 'Start Over',
                    borderColor: HatiColors.textLight,
                    onTap: () => Navigator.pop(context, false),
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

// ── Dashboard return screen ─────────────────────────────────────────────────
class _ScenarioDashboardScene extends StatelessWidget {
  const _ScenarioDashboardScene({super.key});

  // Only these two scenes count toward the end-of-scenario emotion summary:
  // P.I.E.S. (office scene) and the NPC interaction scene. Everything else
  // the FSM logs emotions for — scene0 greeting, debrief, coping, closing,
  // Hati's own coaching turns — is deliberately excluded so the summary
  // reflects the user's reaction to the scenario itself, not to Hati.
  // Reuses sceneForStep so this stays correct across every scenario key
  // without hand-listing step names here. Shown as one combined list
  // ranked by count, not split into separate P.I.E.S./Interaction sections.
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
      final data = doc.data();
      final emotion = (data['emotion'] ?? '').toString().trim().toLowerCase();
      if (emotion.isEmpty) continue;

      final scene = sceneForStep(data['step']?.toString());
      if (scene != SceneId.office && scene != SceneId.interaction) continue;

      counts[emotion] = (counts[emotion] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _showProgressDialog(BuildContext context, String? sessionId) async {
    final counts = await _loadEmotionCounts(sessionId);
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (context) => _EmotionSummaryDialog(counts: counts),
    );
  }

  void _maybeShowBadgeUnlock(BuildContext context, ScenarioProvider provider) {
    final newlyUnlocked = provider.consumeNewlyUnlockedBadges();
    if (newlyUnlocked.isEmpty || !context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => _BadgeUnlockDialog(badgeIds: newlyUnlocked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();
    final summary = joinMessageText(provider.messages, separator: ' ');

    // Fires once per completion: consumeNewlyUnlockedBadges() clears the
    // list it returns, so a later rebuild of this same scene (e.g. after
    // returning from the emotion-summary dialog) naturally gets an empty
    // list and shows nothing — no separate "have I already shown this"
    // flag needed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowBadgeUnlock(context, provider);
    });

    return PopScope(
      // Mirrors the "Close" button's onTap below — without this, leaving
      // via the system back button (or the dashboard's own back-to-Home
      // interception) never tells the backend this scenario finished, so
      // current_step stays "scene7_dashboard" forever and
      // get_unfinished_scenarios() keeps treating it as incomplete,
      // resurfacing "Resume Scenario?" for a scenario the user already
      // completed and closed out of.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        provider.submitText('Close');
        Navigator.pop(context);
      },
      child: Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [HatiColors.deepForest, Color(0xFF2A4A2A)],
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HatiColors.leafGreen.withValues(alpha: 0.15),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const HatiFrogAvatar(size: 160, mood: HatiMood.happy),
                  const SizedBox(height: 20),
                  Text(
                    'Nice work!',
                    style: HatiTextStyles.heading1.copyWith(
                      color: HatiColors.warmCream,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary.isNotEmpty
                        ? summary
                        : "I've logged your emotions. Over time, you'll see patterns.",
                    textAlign: TextAlign.center,
                    style: HatiTextStyles.bodyMedium.copyWith(
                      color: HatiColors.warmCream.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 36),
                  for (final opt in provider.ui.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: HatiButton(
                        label: opt,
                        icon: opt == 'Close'
                            ? Icons.close_rounded
                            : Icons.bar_chart_rounded,
                        color: opt == 'Close'
                            ? HatiColors.mossGreen
                            : HatiColors.softGold,
                        onTap: () async {
                          if (opt == 'Close') {
                            // Tell the backend this scenario actually
                            // finished — without this, it never leaves
                            // step "scene7_dashboard" and stays in
                            // get_unfinished_scenarios() forever, so the
                            // "Resume Scenario?" dialog kept reappearing
                            // even for scenarios the user already
                            // completed. Fire-and-forget (not awaited) so
                            // the pop still happens immediately, client-
                            // side, without waiting on a network round
                            // trip — mirrors EmotionPage's exit.
                            provider.submitText(opt);
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
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Emotion summary: horizontal bar chart ───────────────────────────────────

/// Categorical colors for each detected emotion. Distinct from the app's
/// PIES-selection colors (HatiColors.anxious/calm/etc.) — those fail
/// colorblind-safe separation as a group, so this is a validated palette
/// (see dataviz skill) that keeps a similar hue per emotion where possible.
const Map<String, Color> _emotionChartColors = {
  'anxious': Color(0xFFEF6C00),
  'calm': Color(0xFF00897B),
  'neutral': Color(0xFF3949AB),
  'scared': Color(0xFFAB47BC),
  'angry': Color(0xFFC62828),
};
const Color _emotionChartFallbackColor = Color(0xFF78909C);

const Map<String, String> _emotionChartLabels = {
  'anxious': 'Anxious',
  'calm': 'Calm',
  'neutral': 'Neutral',
  'scared': 'Scared',
  'angry': 'Angry',
};

String _emotionLabelFor(String key) {
  final known = _emotionChartLabels[key];
  if (known != null) return known;
  if (key.isEmpty) return key;
  return key[0].toUpperCase() + key.substring(1);
}

List<MapEntry<String, int>> _sortedEmotionEntries(Map<String, int> counts) {
  final sorted = counts.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted;
}

class _EmotionSummaryDialog extends StatelessWidget {
  final Map<String, int> counts;

  const _EmotionSummaryDialog({required this.counts});

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedEmotionEntries(counts);
    final maxCount = sorted.isNotEmpty ? sorted.first.value.toDouble() : 1.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: HatiColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HatiColors.deepForest, HatiColors.mossGreen],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: HatiColors.softGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Emotions Felt',
                      style: HatiTextStyles.heading3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: sorted.isEmpty
                  ? Text(
                      'No emotion logs are available yet.',
                      style: HatiTextStyles.bodyMedium,
                    )
                  : Column(
                      children: sorted
                          .map(
                            (entry) => _EmotionBarRow(
                              emotion: entry.key,
                              count: entry.value,
                              maxCount: maxCount,
                            ),
                          )
                          .toList(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: HatiButton(
                  label: 'Close',
                  color: HatiColors.mossGreen,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge unlock notification ────────────────────────────────────────────
// Ids/order must match exactly what scenario_engine.py's _evaluate_badges
// writes into badge_progress/summary.earnedBadges, and the display copy
// (label/image) mirrors dashboard_user_data.dart's BadgeData list so the
// notification and the Progress screen's badge grid never disagree.
class _BadgeInfo {
  final String label;
  final String description;
  final String image;

  const _BadgeInfo({
    required this.label,
    required this.description,
    required this.image,
  });
}

const Map<String, _BadgeInfo> _kBadgeInfo = {
  'first_step': _BadgeInfo(
    label: 'First Step',
    description: 'You completed your very first scenario.',
    image: 'assets/badges/first_step.png',
  ),
  'five_day_streak': _BadgeInfo(
    label: '5-Day Streak',
    description: 'You practiced a scenario 5 days in a row.',
    image: 'assets/badges/streak.png',
  ),
  'halfway': _BadgeInfo(
    label: 'Half Way!',
    description: "You've completed half of all available scenarios.",
    image: 'assets/badges/half_way.png',
  ),
  'quick_thinker': _BadgeInfo(
    label: 'Quick Thinker',
    description: 'You finished a scenario within its target time.',
    image: 'assets/badges/quick_thinker.png',
  ),
  'sharpshooter': _BadgeInfo(
    label: 'Sharpshooter',
    description: 'You handled several scenarios well, back to back.',
    image: 'assets/badges/sharpshooter.png',
  ),
};

/// Shown once, right after scene6_closing's response reports newly
/// unlocked badges (see ScenarioProvider.consumeNewlyUnlockedBadges).
/// Stacks multiple badges from the same completion into one dialog
/// (rather than queuing separate popups) since they were unlocked by the
/// exact same event.
class _BadgeUnlockDialog extends StatelessWidget {
  final List<String> badgeIds;

  const _BadgeUnlockDialog({required this.badgeIds});

  @override
  Widget build(BuildContext context) {
    final badges = badgeIds
        .map((id) => _kBadgeInfo[id])
        .whereType<_BadgeInfo>()
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: HatiColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: const BoxDecoration(
                // Brand blue (0xFF0B28D9) — the same header color as the
                // Progress and Profile screens — rather than this dialog
                // family's usual green, since a badge unlock is a
                // dashboard-level moment, not scenario dialogue.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B28D9), Color(0xFF081F9E)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: HatiColors.softGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: HatiColors.softGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      badges.length > 1 ? 'Badges Unlocked!' : 'Badge Unlocked!',
                      style: HatiTextStyles.heading3.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                children: badges
                    .map(
                      (badge) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: HatiColors.softGold.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                badge.image,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.military_tech_rounded,
                                  color: HatiColors.softGold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(badge.label, style: HatiTextStyles.heading3),
                                  const SizedBox(height: 2),
                                  Text(
                                    badge.description,
                                    style: HatiTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: HatiButton(
                  label: 'Nice!',
                  color: HatiColors.mossGreen,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmotionBarRow extends StatelessWidget {
  final String emotion;
  final int count;
  final double maxCount;

  const _EmotionBarRow({
    required this.emotion,
    required this.count,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = _emotionChartColors[emotion] ?? _emotionChartFallbackColor;
    final label = _emotionLabelFor(emotion);
    // A visible sliver even for a small count against a much larger max,
    // so a single occurrence never renders as an invisible bar.
    final factor = maxCount > 0 ? (count / maxCount).clamp(0.08, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: HatiTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: HatiColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: HatiColors.divider,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: factor,
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 22,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: HatiTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: HatiColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
