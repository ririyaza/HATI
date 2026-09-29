import 'package:flutter/material.dart';

import '../../emotiondetection/themed_scenario/scenario_models.dart';
import '../data/dashboard_user_data.dart';
import 'scenario_progress_detail_screen.dart';
import 'weekly_progress_data.dart';
import 'weekly_progress_detail_screen.dart';

/// Legacy module-progress doc IDs that predate the current scenario-key
/// naming in [kScenarioConfigs] — mapped onto their modern equivalent so
/// the thumbnail still resolves. Every other ID is used as-is (it already
/// matches a `kScenarioConfigs` key, e.g. `foa_supervisor`).
const _kLegacyModuleIdAliases = {'where_to_sit': 'foa_classroom'};

/// Same placeholder art the Modules tab uses for each scenario — reused
/// here so a module's progress card and its entry in the Modules grid
/// show the same thumbnail.
String _placeholderAssetForModuleId(String id) {
  final scenarioKey = _kLegacyModuleIdAliases[id] ?? id;
  return kScenarioConfigs[scenarioKey]?.placeholderAsset ??
      kScenarioConfigs['foa_supervisor']!.placeholderAsset;
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, this.weeklyKey});

  /// Spotlight target for the dashboard tour's "This Week" step.
  final Key? weeklyKey;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: DashboardDataService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _StateScaffold.loading();
        }
        final user = authSnapshot.data;
        if (user == null)
          return const _StateScaffold(message: 'Please log in.');

        return StreamBuilder<DashboardUserData>(
          stream: DashboardDataService.watchForUser(user),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _StateScaffold(message: 'Unable to load progress.');
            }
            if (!snapshot.hasData) {
              return const _StateScaffold.loading();
            }
            return _ProgressContent(data: snapshot.data!, weeklyKey: weeklyKey);
          },
        );
      },
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.data, this.weeklyKey});

  final DashboardUserData data;
  final Key? weeklyKey;

  @override
  Widget build(BuildContext context) {
    final percent = (data.overallProgress * 100).round();
    final startedModules = data.modules
        .where((module) => module.completedScenarios > 0)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF0B28D9),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HATI',
                      style: TextStyle(
                        color: const Color(0xFFF5F1E8),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'My Progress',
                      style: TextStyle(
                        color: Color(0xFFF5F1E8).withValues(alpha: 0.70),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F1E8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: data.overallProgress,
                                  strokeWidth: 7,
                                  backgroundColor: const Color(
                                    0xFFF5F1E8,
                                  ).withOpacity(0.25),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        const Color(0xFFF5F1E8),
                                      ),
                                ),
                                Center(
                                  child: Text(
                                    '$percent%',
                                    style: const TextStyle(
                                      color: const Color(0xFFF5F1E8),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Overall Completion',
                                  style: TextStyle(
                                    color: const Color(0xFFF5F1E8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${data.scenariosCompleted} of ${data.totalScenarios} scenarios done',
                                  style: TextStyle(
                                    color: Color(
                                      0xFFF5F1E8,
                                    ).withValues(alpha: 0.70),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Level ${data.level} Learner',
                                  style: const TextStyle(
                                    color: const Color(0xFFF5F1E8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: const Color(0xFFF5F1E8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              transform: Matrix4.translationValues(0, -20, 0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      key: weeklyKey,
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WeeklyProgressDetailScreen(),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'This Week',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _WeeklyStreakCard(currentStreak: data.currentStreak),
                        ],
                      ),
                    ),
                    if (startedModules.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Scenario Modules',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...startedModules.map(
                        (module) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScenarioProgressDetailScreen(
                                    scenarioKey: module.id,
                                  ),
                                ),
                              );
                            },
                            child: _ModuleProgressCard(module: module),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Badges Earned',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BadgesRow(badges: data.badges),
                    const SizedBox(height: 8),
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

/// Fetches the user's emotion logs once and lets them page back through past
/// weeks (never forward past the current one) via [_WeeklyStreak]'s two nav
/// arrows — each past week's day circles come from real logged activity
/// ([activeDaysInWeek]), the same source [WeeklyProgressDetailScreen] uses,
/// rather than [DashboardUserData.weeklyActivity] (module *last*-completion
/// dates only, which can't reconstruct any week but the current one).
class _WeeklyStreakCard extends StatefulWidget {
  const _WeeklyStreakCard({required this.currentStreak});

  final int currentStreak;

  @override
  State<_WeeklyStreakCard> createState() => _WeeklyStreakCardState();
}

class _WeeklyStreakCardState extends State<_WeeklyStreakCard> {
  late final Future<List<EmotionLogEntry>> _logsFuture;

  /// 0 = the current week; each decrement steps one week further into the
  /// past. Clamped at 0 so the user can't page into the future.
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    _logsFuture = fetchAllEmotionLogs();
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeekMonday(
      DateTime.now(),
    ).add(Duration(days: 7 * _weekOffset));

    return FutureBuilder<List<EmotionLogEntry>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? const [];
        return _WeeklyStreak(
          streak: widget.currentStreak,
          completedDays: activeDaysInWeek(logs, weekStart),
          weekStart: weekStart,
          isCurrentWeek: _weekOffset == 0,
          onPreviousWeek: () => setState(() => _weekOffset -= 1),
          onNextWeek: _weekOffset < 0
              ? () => setState(() => _weekOffset += 1)
              : null,
        );
      },
    );
  }
}

class _WeeklyStreak extends StatelessWidget {
  const _WeeklyStreak({
    required this.streak,
    required this.completedDays,
    required this.weekStart,
    required this.isCurrentWeek,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final int streak;
  final List<bool> completedDays;
  final DateTime weekStart;
  final bool isCurrentWeek;
  final VoidCallback onPreviousWeek;

  /// Null (and rendered disabled) once already on the current week — there's
  /// no future week to page forward into.
  final VoidCallback? onNextWeek;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get _weekRangeLabel {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final start = '${_months[weekStart.month - 1]} ${weekStart.day}';
    final end = weekStart.month == weekEnd.month
        ? '${weekEnd.day}'
        : '${_months[weekEnd.month - 1]} ${weekEnd.day}';
    return '$start – $end';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        // Same blue as the "Continue" card on the Modules screen.
        color: const Color(0xFF0B28D9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF5F1E8).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _WeekNavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: onPreviousWeek,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        isCurrentWeek ? '$streak-Day Streak' : _weekRangeLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFFF5F1E8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCurrentWeek
                            ? 'Built from completed scenarios'
                            : 'Days with a logged scenario',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFFF5F1E8).withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _WeekNavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: onNextWeek,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_days.length, (i) {
                final active = i < completedDays.length && completedDays[i];
                return Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Solid cream for a completed day (pops against the
                        // card's dark blue), a barely-there tint of it
                        // otherwise — same on/off treatment as the badge
                        // tiles above.
                        color: active
                            ? const Color(0xFFF5F1E8)
                            : const Color(0xFFF5F1E8).withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        active ? Icons.check : Icons.remove,
                        size: 16,
                        color: active
                            ? const Color(0xFF0B28D9)
                            : const Color(0xFFF5F1E8).withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _days[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? const Color(0xFFF5F1E8)
                            : const Color(0xFFF5F1E8).withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left/right week-page arrow inside [_WeeklyStreak]'s header — nested
/// inside that whole card's own tap-to-open-detail-screen [InkWell], so it
/// needs its own ink response to win the gesture arena over the parent's
/// (which it does: Flutter resolves a tap to the innermost recognizer),
/// otherwise tapping an arrow would also have opened the detail screen.
class _WeekNavButton extends StatelessWidget {
  const _WeekNavButton({required this.icon, required this.onTap});

  final IconData icon;

  /// Null renders a disabled (greyed-out, untappable) arrow — used for "next
  /// week" once already viewing the current week.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 22,
          color: const Color(0xFFF5F1E8).withValues(alpha: enabled ? 1 : 0.25),
        ),
      ),
    );
  }
}

class _ModuleProgressCard extends StatelessWidget {
  const _ModuleProgressCard({required this.module});

  final ModuleProgressData module;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              color: const Color(0xFFF0F3FF),
              child: Image.asset(
                _placeholderAssetForModuleId(module.id),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        module.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${module.completedScenarios}/${module.totalScenarios}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  module.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (module.easyCompleted || module.difficultCompleted) ...[
                  const SizedBox(height: 6),
                  // Completion HISTORY, not a "next attempt" prediction —
                  // shows a pill per mode actually cleared, so beating both
                  // Easy and Hard shows both instead of collapsing down to
                  // just one (unlike the Modules tab's own pill, which
                  // intentionally shows only the single next-attempt mode).
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (module.easyCompleted)
                        const _DifficultyPill(
                          label: 'Easy Mode',
                          color: Color(0xFF2E7D32),
                        ),
                      if (module.difficultCompleted)
                        const _DifficultyPill(
                          label: 'Hard Mode',
                          color: Color(0xFFC62828),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: module.progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE8ECFF),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF0B28D9),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(module.progress * 100).round()}% complete',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0B28D9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyPill extends StatelessWidget {
  const _DifficultyPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _BadgesRow extends StatelessWidget {
  const _BadgesRow({required this.badges});

  final List<BadgeData> badges;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: badges
            .map(
              (badge) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _BadgeTile(badge: badge),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final BadgeData badge;

  void _showDescription(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _BadgeDescriptionDialog(badge: badge),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDescription(context),
      onLongPress: () => _showDescription(context),
      child: Opacity(
        opacity: badge.earned ? 1.0 : 0.35,
        child: Container(
          // Was 80 — just wide enough for "Sharpshooter" (the one label
          // with no natural word-break point, unlike "5-Day\nStreak" /
          // "Quick\nThinker" which pick their own line break) to wrap
          // mid-word instead of fitting on one line. This is in a
          // horizontally-scrolling row, so widening every tile a bit costs
          // nothing layout-wise.
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: badge.earned
                ? const Color(0xFF0B28D9).withOpacity(0.07)
                : const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: badge.earned
                  ? const Color(0xFF0B28D9).withOpacity(0.2)
                  : const Color(0xFFE0E0E0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                badge.image,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 6),
              Text(
                badge.label,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: badge.earned
                      ? const Color(0xFF0B28D9)
                      : Colors.black38,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge detail popup shown on tap/long-press of a [_BadgeTile] — styled
/// like the app's other gradient-header popups (badge-unlock, resume-
/// scenario) instead of a plain default AlertDialog, so it reads as part
/// of the same design rather than a generic system dialog.
class _BadgeDescriptionDialog extends StatelessWidget {
  const _BadgeDescriptionDialog({required this.badge});

  final BadgeData badge;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1E8),
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
                      color: const Color(0xFFF5F1E8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFD4A843),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      badge.label.replaceAll('\n', ' '),
                      style: const TextStyle(
                        color: const Color(0xFFF5F1E8),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
              child: Column(
                children: [
                  Opacity(
                    opacity: badge.earned ? 1.0 : 0.35,
                    child: Image.asset(badge.image, width: 64, height: 64),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    badge.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                  if (badge.earned) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B28D9).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF0B28D9),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Earned',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B28D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B28D9),
                    foregroundColor: const Color(0xFFF5F1E8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateScaffold extends StatelessWidget {
  const _StateScaffold({required this.message}) : loading = false;
  const _StateScaffold.loading()
    : message = 'Loading progress...',
      loading = true;

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      body: Center(
        child: loading
            ? const CircularProgressIndicator(color: Color(0xFF0B28D9))
            : Text(message, style: const TextStyle(color: Colors.black54)),
      ),
    );
  }
}
