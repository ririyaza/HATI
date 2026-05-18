import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/dashboard_user_data.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
              return const _StateScaffold(message: 'Unable to load profile.');
            }
            if (!snapshot.hasData) {
              return const _StateScaffold.loading();
            }
            return _ProfileContent(data: snapshot.data!);
          },
        );
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.data});

  final DashboardUserData data;

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _ProfileAvatar(photoUrl: data.photoUrl),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _HeaderChip(
                                    label: 'Level ${data.level} Learner',
                                  ),
                                  if (data.pronouns.isNotEmpty)
                                    _HeaderChip(label: data.pronouns),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    _StatsRow(data: data),
                    if (data.goal.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'My Goal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(body: data.goal),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Assessment Scores',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (data.assessments.isEmpty)
                      const _InfoCard(
                        body: 'No assessment scores have been recorded yet.',
                      )
                    else
                      _AssessmentScoresSection(entries: data.assessments),
                    const SizedBox(height: 24),
                    const Text(
                      'Coping Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CopingPreferencesCard(
                      preferences: data.copingPreferences,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.volume_up_outlined,
                      label: 'Sound & Music',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      label: 'Privacy',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.help_outline,
                      label: 'Help & Support',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => FirebaseAuth.instance.signOut(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            color: Color(0xFFD9250B),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person,
                size: 40,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.person, size: 40, color: Colors.white),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});

  final DashboardUserData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(value: '${data.modulesStarted}', label: 'Modules\nStarted'),
        const SizedBox(width: 10),
        _StatCard(
          value: '${data.scenariosCompleted}',
          label: 'Scenarios\nCompleted',
        ),
        const SizedBox(width: 10),
        _StatCard(value: '${data.currentStreak}', label: 'Day\nStreak'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0B28D9).withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B28D9),
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

class _AssessmentScoresSection extends StatelessWidget {
  const _AssessmentScoresSection({required this.entries});

  final List<AssessmentScoreData> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AssessmentEntryCard(entry: entry),
            ),
          )
          .toList(),
    );
  }
}

class _AssessmentEntryCard extends StatelessWidget {
  const _AssessmentEntryCard({required this.entry});

  final AssessmentScoreData entry;

  Color _scoreColor(int? score) {
    if (score == null) return Colors.black38;
    final percent = score / entry.maxScore;
    if (percent >= 0.75) return const Color(0xFFD9250B);
    if (percent >= 0.45) return const Color(0xFFFF9500);
    return const Color(0xFF1DB954);
  }

  String _grade(int? score) {
    if (score == null) return 'Pending';
    final percent = score / entry.maxScore;
    if (percent >= 0.75) return 'High';
    if (percent >= 0.45) return 'Moderate';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    final gain = entry.preScore == null || entry.postScore == null
        ? null
        : entry.postScore! - entry.preScore!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B28D9).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.icon,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B28D9),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (gain != null)
                  _GainChip(gain: gain),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _ScoreColumn(
                    label: 'Initial',
                    date: _formatDate(entry.preDate),
                    score: entry.preScore,
                    maxScore: entry.maxScore,
                    color: _scoreColor(entry.preScore),
                    grade: _grade(entry.preScore),
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: const Color(0xFFEEEEEE),
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                Expanded(
                  child: _ScoreColumn(
                    label: 'Post',
                    date: _formatDate(entry.postDate),
                    score: entry.postScore,
                    maxScore: entry.maxScore,
                    color: _scoreColor(entry.postScore),
                    grade: _grade(entry.postScore),
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

class _GainChip extends StatelessWidget {
  const _GainChip({required this.gain});

  final int gain;

  @override
  Widget build(BuildContext context) {
    final improved = gain < 0;
    final color = improved ? const Color(0xFF1DB954) : const Color(0xFFFF9500);
    final label = gain == 0
        ? 'No change'
        : '${gain > 0 ? '+' : ''}$gain pts';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.label,
    required this.date,
    required this.score,
    required this.maxScore,
    required this.color,
    required this.grade,
  });

  final String label;
  final String date;
  final int? score;
  final int maxScore;
  final Color color;
  final String grade;

  @override
  Widget build(BuildContext context) {
    final value = score ?? 0;
    final progress = score == null
        ? 0.0
        : (value / maxScore).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(date, style: const TextStyle(fontSize: 10, color: Colors.black38)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              score?.toString() ?? '--',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 2),
              child: Text(
                '/$maxScore',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            grade,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.body});

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
      child: Text(
        body,
        style: const TextStyle(color: Colors.black54, height: 1.45),
      ),
    );
  }
}

class _CopingPreferencesCard extends StatelessWidget {
  const _CopingPreferencesCard({required this.preferences});

  final String preferences;

  List<String> get _items => preferences
      .split(RegExp(r'[,;]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final hasPreferences = items.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B28D9).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.self_improvement_outlined,
                  color: Color(0xFF0B28D9),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasPreferences
                      ? 'What helps you feel steady'
                      : 'No coping preferences yet',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasPreferences)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E6FF)),
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0B28D9),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            )
          else
            const Text(
              'Complete the coping reflection after the SPIN assessment to show your preferences here.',
              style: TextStyle(color: Colors.black45, height: 1.4),
            ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0B28D9), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 22),
          ],
        ),
      ),
    );
  }
}

class _StateScaffold extends StatelessWidget {
  const _StateScaffold({required this.message}) : loading = false;
  const _StateScaffold.loading()
      : message = 'Loading profile...',
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

String _formatDate(DateTime? date) {
  if (date == null) return 'Not recorded';
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
