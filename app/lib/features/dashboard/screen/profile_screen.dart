import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screen/login_screen.dart';
import '../../auth/session_persistence.dart';
import '../../notifications/daily_login_reminder_service.dart';
import '../../postAssessment/data/post_assessment_repository.dart';
import '../../postAssessment/data/reassessment_notification_service.dart';
import '../../postAssessment/screen/post_assessment_intro_screen.dart';
import '../data/dashboard_user_data.dart';
import '../widgets/help_center_sheet.dart';
import '../widgets/profile_edit_sheets.dart';
import 'privacy_policy_screen.dart';

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

Future<void> _handleLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => const _LogoutConfirmDialog(),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  // Grabbed now, before signing out: this screen watches Firebase's auth
  // state directly, so the moment signOut() resolves it swaps itself for
  // a "Please log in." placeholder — unmounting this context. The
  // NavigatorState itself lives higher up the tree and stays valid, but
  // only if captured before that happens.
  final navigator = Navigator.of(context);

  await clearLoginTimestamp();
  await FirebaseAuth.instance.signOut();

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

/// Confirm-to-proceed dialog for logging out — styled to match
/// `_ConsentSuccessDialog` in `consent_flow_screen.dart` (the one shown
/// right before profile setup): a rounded white card, a tinted circular
/// icon badge, a bold headline, and full-width pill buttons, instead of a
/// plain [AlertDialog]. Unlike that one-button success dialog, this needs
/// two actions, stacked the same way `consent_flow_screen.dart`'s bottom
/// bar stacks "I Agree & Continue" over "I Do Not Agree".
class _LogoutConfirmDialog extends StatelessWidget {
  const _LogoutConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD9250B).withOpacity(0.1),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFD9250B),
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Log Out?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Are you sure you want to log out of HATI?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD9250B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Log Out',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
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
                        _EditableProfileAvatar(
                          uid: data.uid,
                          photoUrl: data.photoUrl,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      data.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => showEditNameAndPronounsSheet(
                                      context,
                                      uid: data.uid,
                                      currentName: data.displayName,
                                      currentPronouns: data.pronouns,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
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
                    const SizedBox(height: 24),
                    const Text(
                      '2-Week Check-in',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CheckInStatusCard(uid: data.uid),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      title: 'My Goal',
                      onEdit: () => showEditGoalSheet(
                        context,
                        uid: data.uid,
                        currentGoal: data.goal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      body: data.goal.isNotEmpty
                          ? data.goal
                          : "You haven't set a goal yet. Tap the edit icon "
                              'to add one.',
                    ),
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
                    _SectionTitle(
                      title: 'Coping Preferences',
                      onEdit: () => showEditCopingSheet(
                        context,
                        uid: data.uid,
                        currentText: data.copingPreferences,
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
                      onTap: () =>
                          _showNotificationSettingsSheet(context, data.uid),
                    ),
                    _SettingsTile(
                      icon: Icons.volume_up_outlined,
                      label: 'Sound & Music',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      label: 'Privacy',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.help_outline,
                      label: 'Help & Support',
                      onTap: () => showHelpCenterSheet(context),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _handleLogout(context),
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

class _EditableProfileAvatar extends StatelessWidget {
  const _EditableProfileAvatar({required this.uid, required this.photoUrl});

  final String uid;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showAvatarPickerSheet(
        context,
        uid: uid,
        currentAssetPath: photoUrl.startsWith('assets/') ? photoUrl : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _ProfileAvatar(photoUrl: photoUrl),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0B28D9),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 12,
                color: Colors.white,
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
    final isAsset = photoUrl.startsWith('assets/');

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
          ? isAsset
                ? Image.asset(photoUrl, fit: BoxFit.cover)
                : Image.network(
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.onEdit});

  final String title;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        if (onEdit != null) ...[
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onEdit,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF0B28D9),
              ),
            ),
          ),
        ],
      ],
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

/// Shows where the user stands in the 14-day reassessment cycle — the
/// same data the dashboard's [ReassessmentBanner] uses to decide whether
/// to show itself, surfaced here so it's visible without waiting for the
/// banner to appear (or checking Firestore directly).
///
/// Tappable whenever the underlying 14-day due date has already passed —
/// whether it's actively due (`isDue`) or currently hidden behind a
/// "Remind me tomorrow" snooze (`snoozedUntil != null`) — so a user who
/// snoozes the dashboard prompt but changes their mind can still start the
/// check-in from here instead of waiting out the snooze. Not tappable while
/// still mid-cooldown, so this can't be used to take it early.
class _CheckInStatusCard extends StatelessWidget {
  const _CheckInStatusCard({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReassessmentStatus?>(
      future: PostAssessmentRepository.getStatus(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final status = snapshot.data;
        if (status == null) return const SizedBox.shrink();

        final String title;
        final String subtitle;
        final Color color;
        if (status.isDue) {
          title = 'Check-in available';
          subtitle =
              'It has been ${status.daysSinceLastAssessment} days since '
              'your last check-in. Tap to start.';
          color = const Color(0xFF0B28D9);
        } else if (status.snoozedUntil != null) {
          title = 'Check-in snoozed until ${_formatDate(status.snoozedUntil)}';
          subtitle =
              'Originally due ${_formatDate(status.dueDate)} — '
              'changed your mind? Tap to start it now.';
          color = const Color(0xFFFF9500);
        } else {
          title = 'Next check-in in ${status.daysUntilDue} '
              '${status.daysUntilDue == 1 ? 'day' : 'days'}';
          subtitle =
              'Last check-in: ${_formatDate(status.lastAssessedAt)} '
              '(${status.daysSinceLastAssessment} days ago).';
          color = const Color(0xFF1DB954);
        }

        final canStartNow = status.isDue || status.snoozedUntil != null;

        return GestureDetector(
          onTap: canStartNow
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PostAssessmentIntroScreen(),
                    ),
                  )
              : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canStartNow)
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.black26,
                    size: 22,
                  ),
              ],
            ),
          ),
        );
      },
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

Future<void> _showNotificationSettingsSheet(
  BuildContext context,
  String uid,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _NotificationSettingsSheet(uid: uid),
  );
}

/// Toggles for the two on-device reminders: the "2-week check-in due" one
/// ([ReassessmentNotificationService]) and the daily "come back to HATI"
/// nudge ([DailyLoginReminderService], on by default after the first-login
/// permission prompt). Turning either on requests the OS notification
/// permission; if that's denied, the switch snaps back off and a message
/// explains why, rather than silently saving a setting that can't actually
/// notify anyone.
class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet({required this.uid});

  final String uid;

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  bool? _checkInEnabled;
  bool? _dailyEnabled;
  bool _checkInBusy = false;
  bool _dailyBusy = false;

  @override
  void initState() {
    super.initState();
    ReassessmentNotificationService.isEnabled(widget.uid).then((value) {
      if (mounted) setState(() => _checkInEnabled = value);
    });
    DailyLoginReminderService.isEnabled(widget.uid).then((value) {
      if (mounted) setState(() => _dailyEnabled = value);
    });
  }

  void _explainIfBlocked(bool requested, bool effective) {
    if (!requested || effective) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Notifications are blocked for HATI in your phone's settings. "
          'Enable them there, then try again.',
        ),
      ),
    );
  }

  Future<void> _toggleCheckIn(bool value) async {
    setState(() => _checkInBusy = true);
    final effective = await ReassessmentNotificationService.setEnabled(
      widget.uid,
      value,
    );
    if (!mounted) return;
    setState(() {
      _checkInEnabled = effective;
      _checkInBusy = false;
    });
    _explainIfBlocked(value, effective);
  }

  Future<void> _toggleDaily(bool value) async {
    setState(() => _dailyBusy = true);
    final effective = await DailyLoginReminderService.setEnabled(
      widget.uid,
      value,
    );
    if (!mounted) return;
    setState(() {
      _dailyEnabled = effective;
      _dailyBusy = false;
    });
    _explainIfBlocked(value, effective);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Reminders sent to your phone, even while the app is closed.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _NotificationToggleRow(
              label: 'Daily reminder',
              description: "A nudge to open HATI if you haven't that day.",
              value: _dailyEnabled,
              busy: _dailyBusy,
              onChanged: _toggleDaily,
            ),
            const SizedBox(height: 10),
            _NotificationToggleRow(
              label: 'Check-in reminders',
              description: 'When your 2-week check-in is ready.',
              value: _checkInEnabled,
              busy: _checkInBusy,
              onChanged: _toggleCheckIn,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  const _NotificationToggleRow({
    required this.label,
    required this.description,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool? value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E6FF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          value == null
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Switch(
                  value: value!,
                  activeThumbColor: const Color(0xFF0B28D9),
                  onChanged: busy ? null : onChanged,
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
