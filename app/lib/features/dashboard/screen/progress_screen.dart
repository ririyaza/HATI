import 'package:flutter/material.dart';

import '../data/dashboard_user_data.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: DashboardDataService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _StateScaffold.loading();
        }
        final user = authSnapshot.data;
        if (user == null) return const _StateScaffold(message: 'Please log in.');

        return StreamBuilder<DashboardUserData>(
          stream: DashboardDataService.watchForUser(user),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _StateScaffold(message: 'Unable to load progress.');
            }
            if (!snapshot.hasData) {
              return const _StateScaffold.loading();
            }
            return _ProgressContent(data: snapshot.data!);
          },
        );
      },
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.data});

  final DashboardUserData data;

  @override
  Widget build(BuildContext context) {
    final percent = (data.overallProgress * 100).round();

    return Scaffold(
      backgroundColor: Colors.white,
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
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'My Progress',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
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
                                  backgroundColor:
                                      Colors.white.withOpacity(0.25),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    '$percent%',
                                    style: const TextStyle(
                                      color: Colors.white,
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
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${data.scenariosCompleted} of ${data.totalScenarios} scenarios done',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Level ${data.level} Learner',
                                  style: const TextStyle(
                                    color: Colors.white,
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
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              transform: Matrix4.translationValues(0, -20, 0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _WeeklyStreak(
                      streak: data.currentStreak,
                      completedDays: data.weeklyActivity,
                    ),
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
                    if (data.modules.isEmpty)
                      const _EmptyCard(
                        title: 'No module progress yet',
                        body: 'Complete a scenario to start tracking progress.',
                      )
                    else
                      ...data.modules.map(
                        (module) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ModuleProgressCard(module: module),
                        ),
                      ),
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

class _WeeklyStreak extends StatelessWidget {
  const _WeeklyStreak({required this.streak, required this.completedDays});

  final int streak;
  final List<bool> completedDays;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak-Day Streak',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Built from completed scenarios',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: List.generate(_days.length, (i) {
              final active = i < completedDays.length && completedDays[i];
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? const Color(0xFF0B28D9)
                            : const Color(0xFFE8ECFF),
                      ),
                      child: Icon(
                        active ? Icons.check : Icons.remove,
                        size: 16,
                        color: active ? Colors.white : Colors.black26,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _days[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? const Color(0xFF0B28D9)
                            : Colors.black38,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0B28D9).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              module.icon,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B28D9),
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

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: badge.earned ? 1.0 : 0.35,
      child: Container(
        width: 80,
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
          children: [
            Text(
              badge.icon,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B28D9),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badge.earned ? const Color(0xFF0B28D9) : Colors.black38,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(color: Colors.black45, height: 1.4),
          ),
        ],
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
      backgroundColor: Colors.white,
      body: Center(
        child: loading
            ? const CircularProgressIndicator(color: Color(0xFF0B28D9))
            : Text(message, style: const TextStyle(color: Colors.black54)),
      ),
    );
  }
}
