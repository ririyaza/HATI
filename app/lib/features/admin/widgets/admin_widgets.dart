import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/audio/hati_tap_sound.dart';

String formatAdminDate(DateTime date) {
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

/// A row of equal-width blue stat tiles shown at the top of an admin tab.
class AdminStatRow extends StatelessWidget {
  const AdminStatRow({super.key, required this.stats});

  /// (value, label) pairs, left to right.
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _StatTile(value: stats[i].$1, label: stats[i].$2),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.cream.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small blue label chip, e.g. "Latest SPIN: 32 · Moderate".
class AdminChip extends StatelessWidget {
  const AdminChip({super.key, required this.text, this.muted = false});

  final String text;

  /// Grey styling for "nothing here yet" notes instead of a value.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? AppColors.creamDeep : AppColors.blueTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
          color: muted ? Colors.black54 : AppColors.blue,
        ),
      ),
    );
  }
}

/// One dated entry in a user card's expanded history list.
class AdminHistoryLine extends StatelessWidget {
  const AdminHistoryLine({
    super.key,
    required this.date,
    required this.title,
    required this.detail,
    this.footnote = '',
  });

  final DateTime date;
  final String title;
  final String detail;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              formatAdminDate(date),
              style: const TextStyle(fontSize: 11.5, color: Colors.black45),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                ),
                if (footnote.isNotEmpty)
                  Text(
                    footnote,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable per-user card shared by the admin tabs.
class AdminUserCard extends StatelessWidget {
  const AdminUserCard({
    super.key,
    required this.user,
    required this.chips,
    required this.children,
  });

  final AdminUserInfo user;
  final List<Widget> chips;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (user.email.isNotEmpty && user.email != user.label) user.email,
      user.joinedAt == null
          ? 'Join date unknown'
          : 'Joined ${formatAdminDate(user.joinedAt!)}',
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamLine),
      ),
      child: Theme(
        // Removes ExpansionTile's default top/bottom divider lines.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            user.label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details,
                  style: const TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class AdminErrorView extends StatelessWidget {
  const AdminErrorView({super.key, required this.title, required this.error});

  final String title;
  final Object error;

  @override
  Widget build(BuildContext context) {
    final denied = error.toString().contains('permission-denied');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (denied)
              const Text(
                'The deployed Firestore rules don\'t allow the admin to read '
                'this data yet. Deploy firestore.rules and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The identity fields every admin tab shows for a user, read from their
/// `users/{uid}` doc.
class AdminUserInfo {
  const AdminUserInfo({
    required this.uid,
    required this.name,
    required this.email,
    required this.joinedAt,
  });

  factory AdminUserInfo.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    DateTime? date(Object? v) => v is Timestamp ? v.toDate() : null;
    return AdminUserInfo(
      uid: doc.id,
      name: (data['displayName'] ?? data['nickname'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      // `createdAt` is written at signup (email and social). The fallbacks
      // only matter for accounts made before that field existed.
      joinedAt:
          date(data['createdAt']) ??
          date(data['profileCompletedAt']) ??
          date(data['initialSpinCompletedAt']),
    );
  }

  final String uid;
  final String name;
  final String email;
  final DateTime? joinedAt;

  String get label => name.isNotEmpty ? name : (email.isNotEmpty ? email : uid);

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) || email.toLowerCase().contains(q);
  }

  /// Newest account first; accounts with no known join date last.
  static int newestFirst(AdminUserInfo a, AdminUserInfo b) {
    final aJoined = a.joinedAt;
    final bJoined = b.joinedAt;
    if (aJoined != null && bJoined != null) return bJoined.compareTo(aJoined);
    if (aJoined != null) return -1;
    if (bJoined != null) return 1;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }
}

/// One filter chip in [AdminSearchableUserList] — [test] decides which rows
/// it keeps.
class AdminFilter<T> {
  const AdminFilter(this.label, this.test);

  final String label;
  final bool Function(T row) test;
}

/// A user list with a search bar (by name or email) and a row of filter
/// chips pinned above it, and [header] scrolling as the list's first item.
/// Search and the selected filter apply together. Rows are shown newest
/// account first.
class AdminSearchableUserList<T> extends StatefulWidget {
  const AdminSearchableUserList({
    super.key,
    required this.rows,
    required this.userOf,
    required this.header,
    required this.cardBuilder,
    this.filters = const [],
  });

  final List<T> rows;
  final AdminUserInfo Function(T row) userOf;
  final Widget header;
  final Widget Function(T row) cardBuilder;

  /// Shown after an implicit "All" chip; only one can be active at a time.
  final List<AdminFilter<T>> filters;

  @override
  State<AdminSearchableUserList<T>> createState() =>
      _AdminSearchableUserListState<T>();
}

class _AdminSearchableUserListState<T>
    extends State<AdminSearchableUserList<T>> {
  final _controller = TextEditingController();
  String _query = '';

  /// Index into [AdminSearchableUserList.filters], or null for "All".
  int? _filterIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AdminFilter<T>? get _activeFilter {
    final index = _filterIndex;
    if (index == null || index >= widget.filters.length) return null;
    return widget.filters[index];
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.rows]
      ..sort(
        (a, b) => AdminUserInfo.newestFirst(widget.userOf(a), widget.userOf(b)),
      );
    // Chip counts reflect the current search, so they always match what
    // tapping that chip would show.
    final searched = sorted
        .where((row) => widget.userOf(row).matches(_query))
        .toList();
    final filter = _activeFilter;
    final visible = filter == null
        ? searched
        : searched.where(filter.test).toList();

    final query = _query.trim();
    final summary = [
      '${visible.length} of ${sorted.length} users',
      if (filter != null) filter.label.toLowerCase(),
      if (query.isNotEmpty) 'matching "$query"',
    ].join(' · ');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _searchField(),
        ),
        if (widget.filters.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                _chip('All', searched.length, filter == null, () {
                  setState(() => _filterIndex = null);
                }),
                for (var i = 0; i < widget.filters.length; i++)
                  _chip(
                    widget.filters[i].label,
                    searched.where(widget.filters[i].test).length,
                    _filterIndex == i,
                    () => setState(() => _filterIndex = i),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: visible.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.header,
                    const SizedBox(height: 12),
                    Text(
                      '$summary · newest first',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black45,
                      ),
                    ),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text(
                            'No users match this search or filter.',
                            style: TextStyle(color: Colors.black45),
                          ),
                        ),
                      ),
                  ],
                );
              }
              return widget.cardBuilder(visible[index - 1]);
            },
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: _controller,
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by name or email',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: AppColors.creamSoft,
        isDense: true,
        border: border(AppColors.creamLine),
        enabledBorder: border(AppColors.creamLine),
        focusedBorder: border(AppColors.blue, 1.5),
      ),
    );
  }

  Widget _chip(String label, int count, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: HatiTapSound.option(
        child: ChoiceChip(
          label: Text('$label ($count)'),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: AppColors.blue,
          backgroundColor: AppColors.creamSoft,
          side: BorderSide(
            color: selected ? AppColors.blue : AppColors.creamLine,
          ),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.cream : AppColors.ink,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
