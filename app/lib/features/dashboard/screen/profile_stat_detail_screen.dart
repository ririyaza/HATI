import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../emotiondetection/themed_scenario/scenario_models.dart'
    show kScenarioConfigs;
import '../data/dashboard_user_data.dart';
import 'weekly_progress_data.dart';

/// Which Profile stat card opened [ProfileStatDetailScreen].
enum ProfileStat {
  modulesStarted('Modules Started'),
  modesCompleted('Modes Completed'),
  dayStreak('Day Streak');

  const ProfileStat(this.title);
  final String title;
}

/// Dedicated breakdown page for the three stat cards at the top of the
/// Profile tab. Previously those cards just switched the dashboard to the
/// Modules/Progress tab; this explains the number itself instead.
///
/// Watches the same [DashboardDataService.watchForUser] stream the Profile
/// tab does, so the figures here always match the card that was tapped.
class ProfileStatDetailScreen extends StatelessWidget {
  const ProfileStatDetailScreen({super.key, required this.stat});

  final ProfileStat stat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.cream,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      stat.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Balances the back button so the title stays centred.
                  const SizedBox(width: 28),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder(
                stream: DashboardDataService.authStateChanges(),
                builder: (context, authSnapshot) {
                  final user = authSnapshot.data;
                  if (user == null) {
                    return const _Message('Please log in.');
                  }
                  return StreamBuilder<DashboardUserData>(
                    stream: DashboardDataService.watchForUser(user),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const _Message('Unable to load your progress.');
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.cream,
                          ),
                        );
                      }
                      final data = snapshot.data!;
                      return switch (stat) {
                        ProfileStat.modulesStarted => _ModulesStartedBody(
                          data: data,
                        ),
                        ProfileStat.modesCompleted => _ModesCompletedBody(
                          data: data,
                        ),
                        ProfileStat.dayStreak => _DayStreakBody(data: data),
                      };
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modules Started ────────────────────────────────────────────────────────

class _ModulesStartedBody extends StatelessWidget {
  const _ModulesStartedBody({required this.data});

  final DashboardUserData data;

  @override
  Widget build(BuildContext context) {
    final started = data.modules.where((m) => m.isStarted).toList();
    final notStarted = data.modules.where((m) => !m.isStarted).toList();
    final total = data.modules.length;

    return _DetailLayout(
      hero: _Hero(
        value: '${data.modulesStarted}',
        suffix: '/ $total',
        caption: started.isEmpty
            ? "You haven't started a module yet."
            : data.modulesStarted == total
            ? "You've started every module. Great work!"
            : '${total - data.modulesStarted} '
                  '${total - data.modulesStarted == 1 ? 'module' : 'modules'} '
                  'left to explore.',
        progress: total == 0 ? 0 : data.modulesStarted / total,
      ),
      children: [
        const _Explainer(
          'A module counts as started once you finish it at least once, '
          'or while you have a session in progress.',
        ),
        if (started.isNotEmpty) ...[
          const _SectionLabel('Started'),
          for (final module in started) _ModuleStatusTile(module: module),
        ],
        if (notStarted.isNotEmpty) ...[
          const _SectionLabel('Not started yet'),
          for (final module in notStarted) _ModuleStatusTile(module: module),
        ],
      ],
    );
  }
}

class _ModuleStatusTile extends StatelessWidget {
  const _ModuleStatusTile({required this.module});

  final ModuleProgressData module;

  @override
  Widget build(BuildContext context) {
    final String status;
    final Color color;
    if (module.completedScenarios > 0) {
      status = 'Completed';
      color = const Color(0xFF1DB954);
    } else if (module.inProgressProgress != null) {
      status = '${(module.inProgressProgress! * 100).round()}% in progress';
      color = const Color(0xFFFF9500);
    } else {
      status = 'Not started';
      color = Colors.black38;
    }

    return _Card(
      child: Row(
        children: [
          _ModuleThumb(module: module),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
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
                if (module.lastCompletedAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Last completed ${formatShortDate(module.lastCompletedAt!)}',
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(label: status, color: color),
        ],
      ),
    );
  }
}

// ── Modes Completed ────────────────────────────────────────────────────────

class _ModesCompletedBody extends StatelessWidget {
  const _ModesCompletedBody({required this.data});

  final DashboardUserData data;

  @override
  Widget build(BuildContext context) {
    final modes = data.modesCompleted;
    final total = data.totalModes;
    // Mirrors DashboardUserData.level: one level per 4 modes, capped by the
    // number of modes that exist.
    final nextLevelAt = (modes ~/ 4 + 1) * 4;
    final toNextLevel = nextLevelAt - modes;

    return _DetailLayout(
      hero: _Hero(
        value: '$modes',
        suffix: '/ $total',
        caption: modes >= total && total > 0
            ? 'Every Easy and Hard mode is done!'
            : 'Level ${data.level} Learner · $toNextLevel more '
                  '${toNextLevel == 1 ? 'mode' : 'modes'} to Level '
                  '${data.level + 1}',
        progress: data.overallProgress,
      ),
      children: [
        const _Explainer(
          'Each module has an Easy and a Hard mode. Finishing either one '
          'counts as a completed mode.',
        ),
        Row(
          children: [
            _MiniStat(
              label: 'Easy modes',
              value:
                  '${data.modules.where((m) => m.easyCompleted).length}'
                  '/${data.modules.length}',
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 10),
            _MiniStat(
              label: 'Hard modes',
              value:
                  '${data.modules.where((m) => m.difficultCompleted).length}'
                  '/${data.modules.length}',
              color: const Color(0xFFC62828),
            ),
          ],
        ),
        const _SectionLabel('By module'),
        for (final module in data.modules) _ModeBreakdownTile(module: module),
      ],
    );
  }
}

class _ModeBreakdownTile extends StatelessWidget {
  const _ModeBreakdownTile({required this.module});

  final ModuleProgressData module;

  @override
  Widget build(BuildContext context) {
    // A module finished before scenario_progress tracked modes has neither
    // flag set but still counts as one mode (see ModuleProgressData).
    final legacyOnly =
        !module.easyCompleted &&
        !module.difficultCompleted &&
        module.completedScenarios > 0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ModuleThumb(module: module),
              const SizedBox(width: 12),
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
                '${module.modesCompleted}/${module.totalModes}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (legacyOnly)
            const _ModeCheckRow(
              label: 'Completed (mode not recorded)',
              done: true,
              color: AppColors.blue,
            )
          else ...[
            _ModeCheckRow(
              label: 'Easy Mode',
              done: module.easyCompleted,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 6),
            _ModeCheckRow(
              label: 'Hard Mode',
              done: module.difficultCompleted,
              color: const Color(0xFFC62828),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeCheckRow extends StatelessWidget {
  const _ModeCheckRow({
    required this.label,
    required this.done,
    required this.color,
  });

  final String label;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: done ? color : Colors.black26,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: done ? color : Colors.black45,
          ),
        ),
        const Spacer(),
        Text(
          done ? 'Done' : 'Not yet',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: done ? color : Colors.black38,
          ),
        ),
      ],
    );
  }
}

// ── Day Streak ─────────────────────────────────────────────────────────────

class _DayStreakBody extends StatefulWidget {
  const _DayStreakBody({required this.data});

  final DashboardUserData data;

  @override
  State<_DayStreakBody> createState() => _DayStreakBodyState();
}

class _DayStreakBodyState extends State<_DayStreakBody> {
  late final Future<List<EmotionLogEntry>> _logsFuture = fetchAllEmotionLogs();

  // Same target as the "5-Day Streak" badge.
  static const _badgeTarget = 5;

  @override
  Widget build(BuildContext context) {
    final streak = widget.data.currentStreak;
    final badgeEarned = widget.data.badgeProgress.earnedBadges.containsKey(
      'five_day_streak',
    );

    return _DetailLayout(
      hero: _Hero(
        value: '$streak',
        suffix: streak == 1 ? 'day' : 'days',
        caption: streak == 0
            ? 'Complete a scenario today to start a streak.'
            : 'Keep it going by completing a scenario tomorrow.',
        icon: Icons.local_fire_department_rounded,
      ),
      children: [
        const _Explainer(
          'Your streak grows by one for every day in a row that you '
          'complete at least one scenario.',
        ),
        _Card(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Opacity(
                  opacity: badgeEarned ? 1 : 0.4,
                  child: Image.asset(
                    'assets/badges/streak.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '5-Day Streak badge',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (badgeEarned)
                      const Text(
                        'Earned!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1DB954),
                        ),
                      )
                    else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (streak / _badgeTarget).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.creamDeep,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${streak.clamp(0, _badgeTarget)}/$_badgeTarget days',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        FutureBuilder<List<EmotionLogEntry>>(
          future: _logsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                ),
              );
            }
            final logs = snapshot.data ?? const <EmotionLogEntry>[];
            final now = DateTime.now();
            final week = activeDaysInWeek(logs, startOfWeekMonday(now));
            final monthDays = activeDaysInMonth(logs, now).length;
            final allDays = {
              for (final e in logs)
                DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day),
            }.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('This week'),
                _Card(child: _WeekRow(activeDays: week)),
                const _SectionLabel('Activity'),
                Row(
                  children: [
                    _MiniStat(
                      label: 'Active days\nthis week',
                      value: '${week.where((d) => d).length}',
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      label: 'Active days\nthis month',
                      value: '$monthDays',
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      label: 'Active days\nall time',
                      value: '$allDays',
                      color: AppColors.blue,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.activeDays});

  final List<bool> activeDays;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final todayIndex = DateTime.now().weekday - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_days.length, (i) {
        final active = i < activeDays.length && activeDays[i];
        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.blue : AppColors.creamDeep,
                border: i == todayIndex
                    ? Border.all(color: AppColors.blue, width: 2)
                    : null,
              ),
              child: Icon(
                active ? Icons.check : Icons.remove,
                size: 16,
                color: active ? AppColors.cream : Colors.black26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _days[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.blue : Colors.black38,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Shared pieces ──────────────────────────────────────────────────────────

/// Blue hero area with the big number, then the cream rounded sheet that
/// holds [children] — same header/sheet split as the Profile tab.
class _DetailLayout extends StatelessWidget {
  const _DetailLayout({required this.hero, required this.children});

  final Widget hero;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        hero,
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).padding.bottom,
              ),
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.value,
    required this.suffix,
    required this.caption,
    this.progress,
    this.icon,
  });

  final String value;
  final String suffix;
  final String caption;
  final double? progress;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Icon(icon, color: const Color(0xFFFF9500), size: 36),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  suffix,
                  style: TextStyle(
                    color: AppColors.cream.withValues(alpha: 0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.cream.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.cream,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.cream.withValues(alpha: 0.85),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamLine),
      ),
      child: child,
    );
  }
}

/// The module's thumbnail art — the same image its card shows on the
/// Modules tab (see modules_screen.dart's _placeholderAssetForScenario).
/// Falls back to the letter well for a module id with no scenario config.
class _ModuleThumb extends StatelessWidget {
  const _ModuleThumb({required this.module});

  final ModuleProgressData module;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final asset = kScenarioConfigs[module.id]?.placeholderAsset;
    if (asset == null) return _IconWell(text: module.icon);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: _size,
        height: _size,
        // Same as the Modules tab: the art isn't square, so contain it on a
        // neutral fill instead of cropping into it.
        color: AppColors.creamSoft,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _IconWell(text: module.icon),
        ),
      ),
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: AppColors.cream)),
    );
  }
}

/// "Oct 14, 2026" — same format as the Profile tab's dates.
String formatShortDate(DateTime date) {
  const months = [
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
