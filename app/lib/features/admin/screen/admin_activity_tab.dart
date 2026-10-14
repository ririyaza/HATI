import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../emotiondetection/themed_scenario/scenario_models.dart';
import '../widgets/admin_widgets.dart';

/// Admin view of how actively each user practices, built from the scenario
/// session docs (`users/{uid}/scenarios/*`) and the day streak in
/// `users/{uid}/badge_progress/summary`. Both are written by the backend's
/// scenario engine, so this covers every app version, not just new ones.
///
/// It measures practice, not app opens: a user who only browses the
/// dashboard without starting a scenario leaves no session here.
class AdminActivityTab extends StatelessWidget {
  const AdminActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    // No orderBy on the collectionGroup queries: unordered ones need no
    // Firestore index.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').snapshots(),
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collectionGroup('scenarios').snapshots(),
          builder: (context, sessionsSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.collectionGroup('badge_progress').snapshots(),
              builder: (context, badgeSnap) {
                final error =
                    usersSnap.error ?? sessionsSnap.error ?? badgeSnap.error;
                if (error != null) {
                  return AdminErrorView(
                    title: 'Unable to load user activity.',
                    error: error,
                  );
                }
                if (!usersSnap.hasData ||
                    !sessionsSnap.hasData ||
                    !badgeSnap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.blue),
                  );
                }
                return _ActivityList(
                  users: _buildRows(
                    usersSnap.data!.docs,
                    sessionsSnap.data!.docs,
                    badgeSnap.data!.docs,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  static List<_ActivityRow> _buildRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> badgeDocs,
  ) {
    final sessionsByUid = <String, List<_Session>>{};
    for (final doc in sessionDocs) {
      final uid = _ownerUid(doc.reference);
      final session = _Session.tryParse(doc.data());
      if (uid == null || session == null) continue;
      sessionsByUid.putIfAbsent(uid, () => []).add(session);
    }

    final streakByUid = <String, int>{};
    for (final doc in badgeDocs) {
      if (doc.id != 'summary') continue;
      final uid = _ownerUid(doc.reference);
      if (uid == null) continue;
      final streak = doc.data()['currentDayStreak'];
      if (streak is num) streakByUid[uid] = streak.toInt();
    }

    final rows = <_ActivityRow>[];
    for (final doc in userDocs) {
      final data = doc.data();
      if (data['role'] == 'admin') continue;
      final sessions = (sessionsByUid[doc.id] ?? [])
        ..sort((a, b) => b.lastActive.compareTo(a.lastActive));
      rows.add(
        _ActivityRow(
          user: AdminUserInfo.fromDoc(doc),
          sessions: sessions,
          dayStreak: streakByUid[doc.id] ?? 0,
        ),
      );
    }
    return rows;
  }

  /// The `{uid}` in `users/{uid}/<collection>/<doc>`, or null if [ref]
  /// lives anywhere else.
  static String? _ownerUid(DocumentReference<Map<String, dynamic>> ref) {
    final userDoc = ref.parent.parent;
    if (userDoc == null || userDoc.parent.id != 'users') return null;
    return userDoc.id;
  }
}

DateTime? _parseDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

enum _SessionStatus { completed, inProgress, openedOnly }

class _Session {
  const _Session({
    required this.startedAt,
    required this.lastActive,
    required this.scenarioTitle,
    required this.difficulty,
    required this.status,
    required this.sceneLabel,
  });

  final DateTime startedAt;
  final DateTime lastActive;
  final String scenarioTitle;
  final String? difficulty;
  final _SessionStatus status;
  final String sceneLabel;

  bool get wasPlayed => status != _SessionStatus.openedOnly;

  static _Session? tryParse(Map<String, dynamic> data) {
    final createdAt = _parseDate(data['created_at']);
    final updatedAt = _parseDate(data['updated_at']);
    final startedAt = createdAt ?? updatedAt;
    if (startedAt == null) return null;

    final sessionState = data['session_state'];
    final sessionData = sessionState is Map ? sessionState['data'] : null;
    final scenarioKey =
        (sessionData is Map ? sessionData['scenario_key'] : null)?.toString() ??
        data['scenario_key']?.toString() ??
        '';
    final difficulty = sessionData is Map
        ? sessionData['difficulty']?.toString()
        : null;

    final step = (data['current_step'] ?? '').toString();
    final scene = sceneForStep(step);
    final _SessionStatus status;
    if (step == 'complete' || scene == SceneId.dashboard) {
      status = _SessionStatus.completed;
    } else if (kStepToScene.containsKey(step) && scene == SceneId.preScene) {
      // Opening a scenario's intro screen already creates a session, before
      // "Begin Scenario" is tapped.
      status = _SessionStatus.openedOnly;
    } else {
      status = _SessionStatus.inProgress;
    }

    return _Session(
      startedAt: startedAt,
      lastActive: updatedAt ?? startedAt,
      scenarioTitle:
          kScenarioConfigs[scenarioKey]?.title ??
          (scenarioKey.isEmpty ? 'Unknown scenario' : scenarioKey),
      difficulty: difficulty,
      status: status,
      sceneLabel: _sceneLabel(scene),
    );
  }

  static String _sceneLabel(SceneId scene) {
    switch (scene) {
      case SceneId.preScene:
        return 'Intro';
      case SceneId.office:
        return 'P.I.E.S. check-in';
      case SceneId.preparation:
        return 'Preparation';
      case SceneId.interaction:
        return 'Interaction';
      case SceneId.debrief:
        return 'Debrief';
      case SceneId.coping:
        return 'Coping';
      case SceneId.closing:
        return 'Closing';
      case SceneId.dashboard:
        return 'Summary';
    }
  }
}

class _ActivityRow {
  _ActivityRow({
    required this.user,
    required this.sessions,
    required this.dayStreak,
  });

  final AdminUserInfo user;

  /// Most recently active first.
  final List<_Session> sessions;
  final int dayStreak;

  DateTime? get lastActive =>
      sessions.isEmpty ? null : sessions.first.lastActive;

  int get playedCount => sessions.where((s) => s.wasPlayed).length;

  int get completedCount =>
      sessions.where((s) => s.status == _SessionStatus.completed).length;

  /// Distinct calendar days with any scenario activity. Approximate: each
  /// session only records when it started and its last turn, so a session
  /// spanning several days counts those two days only.
  int get activeDays => {
    for (final s in sessions) ...[_dayOf(s.startedAt), _dayOf(s.lastActive)],
  }.length;
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.users});

  final List<_ActivityRow> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No users yet.', style: TextStyle(color: Colors.black45)),
      );
    }
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final activeThisWeek = users
        .where((u) => u.lastActive != null && u.lastActive!.isAfter(weekAgo))
        .length;
    final totalPlayed = users.fold<int>(0, (acc, u) => acc + u.playedCount);
    return AdminSearchableUserList<_ActivityRow>(
      rows: users,
      userOf: (row) => row.user,
      header: AdminStatRow(
        stats: [
          ('${users.length}', 'Users'),
          ('$activeThisWeek', 'Active in last 7 days'),
          ('$totalPlayed', 'Sessions played'),
        ],
      ),
      cardBuilder: (row) => _ActivityCard(row: row),
      filters: [
        AdminFilter(
          'Active in last 7 days',
          (r) => r.lastActive != null && r.lastActive!.isAfter(weekAgo),
        ),
        AdminFilter(
          'Inactive 7+ days',
          (r) => r.lastActive != null && !r.lastActive!.isAfter(weekAgo),
        ),
        AdminFilter('Never played', (r) => r.playedCount == 0),
        AdminFilter('Completed a scenario', (r) => r.completedCount > 0),
        AdminFilter(
          'Has unfinished session',
          (r) => r.sessions.any((s) => s.status == _SessionStatus.inProgress),
        ),
        AdminFilter('On a streak', (r) => r.dayStreak > 0),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.row});

  final _ActivityRow row;

  @override
  Widget build(BuildContext context) {
    final lastActive = row.lastActive;
    return AdminUserCard(
      user: row.user,
      chips: lastActive == null
          ? const [AdminChip(text: 'Never played a scenario', muted: true)]
          : [
              AdminChip(
                text:
                    'Last active: ${formatAdminDate(lastActive)} '
                    '(${_relative(lastActive)})',
              ),
              AdminChip(
                text:
                    'Sessions: ${row.playedCount} '
                    '(${row.completedCount} completed)',
              ),
              AdminChip(text: 'Active days: ${row.activeDays}'),
              AdminChip(
                text:
                    'Streak: ${row.dayStreak} '
                    'day${row.dayStreak == 1 ? '' : 's'}',
              ),
            ],
      children: [
        for (final s in row.sessions)
          AdminHistoryLine(
            date: s.lastActive,
            title: s.scenarioTitle,
            detail: _statusText(s),
            footnote: [
              if (s.difficulty != null) '${_capitalize(s.difficulty!)} mode',
              'started ${formatAdminDate(s.startedAt)} '
                  '${_time(s.startedAt)}',
            ].join(' · '),
          ),
        if (row.sessions.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'No scenario sessions recorded.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
      ],
    );
  }

  static String _statusText(_Session s) {
    switch (s.status) {
      case _SessionStatus.completed:
        return 'Completed';
      case _SessionStatus.inProgress:
        return 'In progress — stopped at ${s.sceneLabel}';
      case _SessionStatus.openedOnly:
        return 'Opened, not started';
    }
  }

  static String _relative(DateTime date) {
    final days = _dayOf(DateTime.now()).difference(_dayOf(date)).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  static String _time(DateTime date) {
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
