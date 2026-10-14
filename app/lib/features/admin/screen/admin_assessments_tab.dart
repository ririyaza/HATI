import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../postAssessment/data/post_assessment_scoring.dart' as scoring;
import '../widgets/admin_widgets.dart';

/// Admin view of every user's onboarding SPIN baseline and post-assessment
/// (reassessment) history, read from `users` and the `reassessments`
/// collection group.
class AdminAssessmentsTab extends StatelessWidget {
  const AdminAssessmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnap) {
        // No orderBy: an unordered collectionGroup query needs no index.
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collectionGroup('reassessments')
              .snapshots(),
          builder: (context, reassessSnap) {
            final error = usersSnap.error ?? reassessSnap.error;
            if (error != null) {
              return AdminErrorView(
                title: 'Unable to load assessment scores.',
                error: error,
              );
            }
            if (!usersSnap.hasData || !reassessSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.blue),
              );
            }
            final users = _buildUserRows(
              usersSnap.data!.docs,
              reassessSnap.data!.docs,
            );
            return _UserList(users: users);
          },
        );
      },
    );
  }

  static List<_UserRow> _buildUserRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reassessmentDocs,
  ) {
    final byUid = <String, List<_Reassessment>>{};
    for (final doc in reassessmentDocs) {
      final uid = doc.reference.parent.parent?.id;
      final parsed = _Reassessment.tryParse(doc.data());
      if (uid == null || parsed == null) continue;
      byUid.putIfAbsent(uid, () => []).add(parsed);
    }

    final rows = <_UserRow>[];
    for (final doc in userDocs) {
      final data = doc.data();
      if (data['role'] == 'admin') continue;
      final history = (byUid[doc.id] ?? [])
        ..sort((a, b) => b.administeredAt.compareTo(a.administeredAt));
      rows.add(
        _UserRow(
          user: AdminUserInfo.fromDoc(doc),
          initialSpin: _asInt(data['initialSpinScore']),
          initialSpinAt: (data['initialSpinCompletedAt'] as Timestamp?)
              ?.toDate(),
          history: history,
        ),
      );
    }
    return rows;
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class _UserRow {
  const _UserRow({
    required this.user,
    required this.initialSpin,
    required this.initialSpinAt,
    required this.history,
  });

  final AdminUserInfo user;
  final int? initialSpin;
  final DateTime? initialSpinAt;

  /// Newest first.
  final List<_Reassessment> history;
}

class _Reassessment {
  const _Reassessment({
    required this.administeredAt,
    required this.spinTotal,
    required this.spinSeverity,
    required this.gad7Total,
    required this.gad7Severity,
    required this.category,
    required this.routedTo,
  });

  final DateTime administeredAt;
  final int spinTotal;
  final String spinSeverity;
  final int? gad7Total;
  final String? gad7Severity;
  final String? category;
  final String? routedTo;

  static _Reassessment? tryParse(Map<String, dynamic> data) {
    final administeredAt = (data['administeredAt'] as Timestamp?)?.toDate();
    final spin = data['spin'];
    if (administeredAt == null || spin is! Map) return null;
    final spinTotal = _asInt(spin['total']);
    if (spinTotal == null) return null;
    final gad7 = data['gad7'];
    final comparison = data['comparison'];
    return _Reassessment(
      administeredAt: administeredAt,
      spinTotal: spinTotal,
      spinSeverity:
          spin['severity']?.toString() ?? scoring.spinSeverity(spinTotal),
      gad7Total: gad7 is Map ? _asInt(gad7['total']) : null,
      gad7Severity: gad7 is Map ? gad7['severity']?.toString() : null,
      category: comparison is Map ? comparison['category']?.toString() : null,
      routedTo: data['routedTo']?.toString(),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users});

  final List<_UserRow> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No users yet.', style: TextStyle(color: Colors.black45)),
      );
    }
    final assessed = users.where((u) => u.history.isNotEmpty).length;
    final total = users.fold<int>(0, (acc, u) => acc + u.history.length);
    return AdminSearchableUserList<_UserRow>(
      rows: users,
      userOf: (row) => row.user,
      header: AdminStatRow(
        stats: [
          ('${users.length}', 'Users'),
          ('$assessed', 'Took post-assessment'),
          ('$total', 'Total check-ins'),
        ],
      ),
      cardBuilder: (row) => _UserCard(row: row),
      filters: [
        AdminFilter('Took post-assessment', (r) => r.history.isNotEmpty),
        AdminFilter('No post-assessment', (r) => r.history.isEmpty),
        AdminFilter('Improved', (r) => _latestCategoryStarts(r, 'improved')),
        AdminFilter('No change', (r) => _latestCategoryStarts(r, 'noChange')),
        AdminFilter('Worsened', (r) => _latestCategoryStarts(r, 'worsened')),
        AdminFilter(
          'GAD-7 elevated',
          (r) => _latest(r)?.category?.endsWith('Gad7Elevated') ?? false,
        ),
        AdminFilter(
          'Referred to professional',
          (r) => _latest(r)?.routedTo == 'referral',
        ),
      ],
    );
  }

  /// Filters look at the user's most recent post-assessment only.
  static _Reassessment? _latest(_UserRow row) =>
      row.history.isEmpty ? null : row.history.first;

  static bool _latestCategoryStarts(_UserRow row, String prefix) =>
      _latest(row)?.category?.startsWith(prefix) ?? false;
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.row});

  final _UserRow row;

  @override
  Widget build(BuildContext context) {
    final latest = row.history.isEmpty ? null : row.history.first;
    return AdminUserCard(
      user: row.user,
      chips: [
        _scoreChip(
          'Initial SPIN',
          row.initialSpin,
          row.initialSpin == null
              ? null
              : scoring.spinSeverity(row.initialSpin!),
        ),
        if (latest != null) ...[
          _scoreChip('Latest SPIN', latest.spinTotal, latest.spinSeverity),
          _scoreChip('Latest GAD-7', latest.gad7Total, latest.gad7Severity),
        ] else
          const AdminChip(text: 'No post-assessment yet', muted: true),
      ],
      children: [
        if (row.initialSpinAt != null)
          AdminHistoryLine(
            date: row.initialSpinAt!,
            title: 'Onboarding SPIN',
            detail: row.initialSpin == null
                ? '—'
                : '${row.initialSpin} '
                      '(${scoring.spinSeverity(row.initialSpin!)})',
          ),
        for (final r in row.history.reversed)
          AdminHistoryLine(
            date: r.administeredAt,
            title: 'Post-assessment',
            detail:
                'SPIN ${r.spinTotal} (${r.spinSeverity}) · '
                'GAD-7 ${r.gad7Total ?? '—'}'
                '${r.gad7Severity == null ? '' : ' (${r.gad7Severity})'}',
            footnote: [
              if (r.category != null) _categoryLabel(r.category!),
              if (r.routedTo != null) 'routed to ${r.routedTo}',
            ].join(' · '),
          ),
        if (row.initialSpinAt == null && row.history.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'No assessments recorded.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
      ],
    );
  }

  static Widget _scoreChip(String label, int? value, String? severity) {
    return AdminChip(
      text: value == null
          ? '$label: —'
          : '$label: $value${severity == null ? '' : ' · $severity'}',
    );
  }

  static String _categoryLabel(String category) {
    const labels = {
      'improvedNoConcerns': 'Improved',
      'improvedStillSignificant': 'Improved, still significant',
      'improvedGad7Elevated': 'Improved, GAD-7 elevated',
      'noChangeNotElevated': 'No change',
      'noChangeGad7Elevated': 'No change, GAD-7 elevated',
      'worsenedNotElevated': 'Worsened',
      'worsenedGad7Elevated': 'Worsened, GAD-7 elevated',
    };
    return labels[category] ?? category;
  }
}
