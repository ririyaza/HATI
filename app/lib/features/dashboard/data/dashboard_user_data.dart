import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardUserData {
  const DashboardUserData({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.pronouns,
    required this.goal,
    required this.copingPreferences,
    required this.modules,
    required this.assessments,
    this.badgeProgress = const BadgeProgressData(),
  });

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String pronouns;
  final String goal;
  final String copingPreferences;
  final List<ModuleProgressData> modules;
  final List<AssessmentScoreData> assessments;
  final BadgeProgressData badgeProgress;

  int get scenariosCompleted =>
      modules.fold(0, (sum, module) => sum + module.completedScenarios);

  int get totalScenarios =>
      modules.fold(0, (sum, module) => sum + module.totalScenarios);

  int get modulesStarted =>
      modules.where((module) => module.completedScenarios > 0).length;

  double get overallProgress {
    if (totalScenarios <= 0) return 0;
    return (scenariosCompleted / totalScenarios).clamp(0.0, 1.0).toDouble();
  }

  int get level => (scenariosCompleted ~/ 5) + 1;

  int get currentStreak => _streakFromModules(modules);

  List<bool> get weeklyActivity => _weeklyActivityFromModules(modules);

  // Earned state now comes from the backend's persisted
  // users/{uid}/badge_progress/summary (via badgeProgress.earnedBadges),
  // set the moment scenario_engine.py's _evaluate_badges unlocks each one
  // — not derived from these on-screen counters anymore. The ids below
  // ('first_step', 'five_day_streak', ...) must match the badge ids
  // scenario_engine.py writes into earnedBadges exactly.
  List<BadgeData> get badges => [
    BadgeData(
      image: 'assets/badges/first_step.png',
      label: 'First Step',
      earned: badgeProgress.earnedBadges.containsKey('first_step'),
    ),
    BadgeData(
      image: 'assets/badges/streak.png',
      label: '5-Day\nStreak',
      earned: badgeProgress.earnedBadges.containsKey('five_day_streak'),
    ),
    BadgeData(
      image: 'assets/badges/half_way.png',
      label: 'Half Way!',
      earned: badgeProgress.earnedBadges.containsKey('halfway'),
    ),
    BadgeData(
      image: 'assets/badges/quick_thinker.png',
      label: 'Quick\nThinker',
      earned: badgeProgress.earnedBadges.containsKey('quick_thinker'),
    ),
    BadgeData(
      image: 'assets/badges/sharpshooter.png',
      label: 'Sharpshooter',
      earned: badgeProgress.earnedBadges.containsKey('sharpshooter'),
    ),
  ];
}

/// Parsed from users/{uid}/badge_progress/summary — the durable badge
/// state scenario_engine.py's _evaluate_badges/EmotionDatabase.
/// update_badge_progress maintains server-side. `earnedBadges` maps
/// badge id to the timestamp it was earned (kept, not just a Set, in case
/// a future screen wants to show "earned on" a specific date).
class BadgeProgressData {
  const BadgeProgressData({
    this.earnedBadges = const {},
    this.distinctScenariosCompleted = 0,
    this.currentDayStreak = 0,
    this.currentSuccessStreak = 0,
  });

  final Map<String, DateTime> earnedBadges;
  final int distinctScenariosCompleted;
  final int currentDayStreak;
  final int currentSuccessStreak;
}

class ModuleProgressData {
  const ModuleProgressData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completedScenarios,
    required this.totalScenarios,
    required this.lastCompletedAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final int completedScenarios;
  final int totalScenarios;
  final DateTime? lastCompletedAt;

  double get progress {
    if (totalScenarios <= 0) return 0;
    return (completedScenarios / totalScenarios).clamp(0.0, 1.0).toDouble();
  }
}

class AssessmentScoreData {
  const AssessmentScoreData({
    required this.name,
    required this.icon,
    required this.maxScore,
    required this.preScore,
    required this.preDate,
    required this.postScore,
    required this.postDate,
  });

  final String name;
  final String icon;
  final int maxScore;
  final int? preScore;
  final DateTime? preDate;
  final int? postScore;
  final DateTime? postDate;
}

class BadgeData {
  const BadgeData({
    required this.image,
    required this.label,
    required this.earned,
  });

  final String image;
  final String label;
  final bool earned;
}

class DashboardDataService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  // Combines three independent live listeners (the user doc plus its
  // moduleProgress/spinAssessments subcollections) into one stream, and
  // re-emits whenever ANY of them changes. A single `userRef.snapshots()`
  // listener that only `.get()`s the subcollections once per parent-doc
  // event (the previous approach) misses updates entirely when the backend
  // writes straight to `moduleProgress/{scenarioKey}` without also touching
  // the parent `users/{uid}` doc — e.g. finishing a scenario would silently
  // fail to refresh the Progress screen until the app was restarted.
  static Stream<DashboardUserData> watchForUser(User user) {
    final userRef = _firestore.collection('users').doc(user.uid);
    late final StreamController<DashboardUserData> controller;

    DocumentSnapshot<Map<String, dynamic>>? latestUserDoc;
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? latestModuleDocs;
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? latestAssessmentDocs;
    DocumentSnapshot<Map<String, dynamic>>? latestBadgeDoc;

    void emitIfReady() {
      final userDoc = latestUserDoc;
      final moduleDocs = latestModuleDocs;
      final assessmentDocs = latestAssessmentDocs;
      final badgeDoc = latestBadgeDoc;
      if (userDoc == null ||
          moduleDocs == null ||
          assessmentDocs == null ||
          badgeDoc == null) {
        return;
      }
      controller.add(
        DashboardUserDataParser.parse(
          user: user,
          userDoc: userDoc,
          moduleDocs: moduleDocs,
          assessmentDocs: assessmentDocs,
          badgeDoc: badgeDoc,
        ),
      );
    }

    late final List<StreamSubscription> subs;
    controller = StreamController<DashboardUserData>(
      onListen: () {
        subs = [
          userRef.snapshots().listen((doc) {
            latestUserDoc = doc;
            emitIfReady();
          }, onError: controller.addError),
          userRef.collection('moduleProgress').snapshots().listen((snap) {
            latestModuleDocs = snap.docs;
            emitIfReady();
          }, onError: controller.addError),
          userRef.collection('spinAssessments').snapshots().listen((snap) {
            latestAssessmentDocs = snap.docs;
            emitIfReady();
          }, onError: controller.addError),
          // badge_progress/summary — a single doc (not a query) that may
          // not exist yet for a user who hasn't earned anything; a
          // snapshot listener still fires once immediately with
          // exists=false in that case, so this unblocks emitIfReady() the
          // same as the other three.
          userRef
              .collection('badge_progress')
              .doc('summary')
              .snapshots()
              .listen((doc) {
            latestBadgeDoc = doc;
            emitIfReady();
          }, onError: controller.addError),
        ];
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }
}

class DashboardUserDataParser {
  // Fallback/default cards for a scenario the user hasn't completed even
  // once yet (so it still shows as a 0/1 card instead of not appearing at
  // all) — the moment it IS completed, scenario_engine.py's own
  // _MODULE_DISPLAY_INFO writes the real title/subtitle/icon straight into
  // Firestore and that overrides this fallback (see _parseModules below).
  // Mirrors _MODULE_DISPLAY_INFO exactly so a card never visually changes
  // between "not started" and "started" states. Deliberately excludes:
  //  - 'where_to_sit' — a legacy, pre-backend placeholder id for what's
  //    now 'foa_classroom' ("WHERE TO SIT?"); nothing ever writes to this
  //    id anymore.
  //  - 'foa_classroom' itself — kept hidden from the dashboard by product
  //    decision (it's an alternate "Fear of Authority" scenario in
  //    scenario_engine.py's ALLOWED_SCENARIO_KEYS, not one of the 6 the
  //    app surfaces per theme via THEME_SCENARIO_KEYS).
  // The 6 remaining entries below match THEME_SCENARIO_KEYS one-for-one —
  // same 6 scenario_engine.py counts for the badges feature's Halfway
  // calculation (len(THEME_SCENARIO_KEYS)), so the dashboard's own
  // "scenarios completed out of N" agrees with what unlocks Halfway.
  static const _knownModules = {
    'foa_supervisor': _ModuleDefinition(
      title: "The Professor's Signature",
      subtitle: 'Fear of Authority - 1 scenario',
      icon: 'P',
      totalScenarios: 1,
    ),
    'fsn_seat': _ModuleDefinition(
      title: "The Food Hall's Seat",
      subtitle: 'Fear of Strangers & New People - 1 scenario',
      icon: 'F',
      totalScenarios: 1,
    ),
    'fbop_spotlight': _ModuleDefinition(
      title: 'Project Defense: Defended or Offended',
      subtitle: 'Fear of Being Observed & Performing - 1 scenario',
      icon: 'D',
      totalScenarios: 1,
    ),
    'fsg_party': _ModuleDefinition(
      title: 'The Student Gathering: To Approach or Not?',
      subtitle: 'Fear of Social Gatherings - 1 scenario',
      icon: 'H',
      totalScenarios: 1,
    ),
    'fne_stage': _ModuleDefinition(
      title: 'The Group Project: Defending Your Work',
      subtitle: 'Fear of Negative Evaluation & Embarrassment - 1 scenario',
      icon: 'G',
      totalScenarios: 1,
    ),
    'phys_jeepney': _ModuleDefinition(
      title: 'The Jeep Stop: Hiding Visible Anxiety',
      subtitle: 'Physiological Symptoms - 1 scenario',
      icon: 'B',
      totalScenarios: 1,
    ),
  };

  // Belt-and-suspenders: if a stray users/{uid}/moduleProgress/where_to_sit
  // document exists (real Firestore data, not just the hardcoded fallback
  // above), it would otherwise still show up via the live-docs loop in
  // _parseModules regardless of what's in _knownModules — 'foa_classroom'
  // in particular WILL have real data the moment anyone completes it
  // (scenario_engine.py writes to it same as any other scenario_key), so
  // omitting it from _knownModules alone isn't enough to actually hide it.
  static const _hiddenModuleIds = {'where_to_sit', 'foa_classroom'};

  static DashboardUserData parse({
    required User user,
    required DocumentSnapshot<Map<String, dynamic>> userDoc,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> moduleDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> assessmentDocs,
    DocumentSnapshot<Map<String, dynamic>>? badgeDoc,
  }) {
    final data = userDoc.data() ?? {};
    final modules = _parseModules(moduleDocs);
    final assessments = _parseAssessments(data, assessmentDocs);
    final copingPreferences = _parseCopingPreferences(data, assessmentDocs);
    final badgeProgress = _parseBadgeProgress(badgeDoc);

    return DashboardUserData(
      uid: user.uid,
      email: _string(data['email'], fallback: user.email ?? ''),
      displayName: _string(
        data['displayName'] ?? data['nickname'],
        fallback: user.email?.split('@').first ?? 'HATI User',
      ),
      photoUrl: _string(
        data['profilePicAssetPath'] ??
            data['profilePicUrl'] ??
            data['photoURL'] ??
            data['photoUrl'] ??
            user.photoURL,
      ),
      pronouns: _string(data['pronouns']),
      goal: _string(data['goal']),
      copingPreferences: copingPreferences,
      badgeProgress: badgeProgress,
      modules: modules,
      assessments: assessments,
    );
  }

  static List<ModuleProgressData> _parseModules(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final byId = <String, ModuleProgressData>{};

    for (final entry in _knownModules.entries) {
      final definition = entry.value;
      byId[entry.key] = ModuleProgressData(
        id: entry.key,
        title: definition.title,
        subtitle: definition.subtitle,
        icon: definition.icon,
        completedScenarios: 0,
        totalScenarios: definition.totalScenarios,
        lastCompletedAt: null,
      );
    }

    for (final doc in docs) {
      if (_hiddenModuleIds.contains(doc.id)) continue;
      final data = doc.data();
      final definition = _knownModules[doc.id];
      final total = _int(
        data['totalScenarios'] ?? data['totalSteps'],
        fallback: definition?.totalScenarios ?? 0,
      );
      final completed = _int(
        data['completedScenarios'] ?? data['stepsCompleted'],
      ).clamp(0, total <= 0 ? 999 : total).toInt();

      byId[doc.id] = ModuleProgressData(
        id: doc.id,
        title: _string(data['title'], fallback: definition?.title ?? doc.id),
        subtitle: _string(
          data['subtitle'],
          fallback: definition?.subtitle ?? '$total scenarios',
        ),
        icon: _string(data['icon'], fallback: definition?.icon ?? '-'),
        completedScenarios: completed,
        totalScenarios: total,
        lastCompletedAt: _date(data['lastCompletedAt']),
      );
    }

    return byId.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  static List<AssessmentScoreData> _parseAssessments(
    Map<String, dynamic> userData,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    Map<String, dynamic>? initialDoc;
    Map<String, dynamic>? postDoc;

    for (final doc in docs) {
      if (doc.id == 'initial') initialDoc = doc.data();
      if (doc.id == 'post' || doc.id == 'final') postDoc = doc.data();
    }

    final initialScore = _nullableInt(
      initialDoc?['score'] ?? userData['initialSpinScore'],
    );
    final initialDate = _date(
      initialDoc?['completedAt'] ?? userData['initialSpinCompletedAt'],
    );
    final postScore = _nullableInt(
      postDoc?['score'] ?? userData['postSpinScore'] ?? userData['finalSpinScore'],
    );
    final postDate = _date(
      postDoc?['completedAt'] ??
          userData['postSpinCompletedAt'] ??
          userData['finalSpinCompletedAt'],
    );

    if (initialScore == null && postScore == null) return const [];

    return [
      AssessmentScoreData(
        name: 'SPIN Assessment',
        icon: 'S',
        maxScore: 68,
        preScore: initialScore,
        preDate: initialDate,
        postScore: postScore,
        postDate: postDate,
      ),
    ];
  }

  static BadgeProgressData _parseBadgeProgress(
    DocumentSnapshot<Map<String, dynamic>>? doc,
  ) {
    final data = doc?.data();
    if (data == null) return const BadgeProgressData();

    final rawEarned = data['earnedBadges'];
    final earned = <String, DateTime>{};
    if (rawEarned is Map) {
      for (final entry in rawEarned.entries) {
        final date = _date(entry.value);
        if (date != null) earned[entry.key.toString()] = date;
      }
    }

    return BadgeProgressData(
      earnedBadges: earned,
      distinctScenariosCompleted: _int(data['distinctScenariosCompleted']),
      currentDayStreak: _int(data['currentDayStreak']),
      currentSuccessStreak: _int(data['currentSuccessStreak']),
    );
  }

  static String _parseCopingPreferences(
    Map<String, dynamic> userData,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    Map<String, dynamic>? initialDoc;

    for (final doc in docs) {
      if (doc.id == 'initial') {
        initialDoc = doc.data();
        break;
      }
    }

    return _string(
      userData['initialCopingMechanism'] ??
          userData['copingMechanism'] ??
          initialDoc?['copingMechanism'],
    );
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static int _int(Object? value, {int fallback = 0}) =>
      _nullableInt(value) ?? fallback;

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }
}

class _ModuleDefinition {
  const _ModuleDefinition({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.totalScenarios,
  });

  final String title;
  final String subtitle;
  final String icon;
  final int totalScenarios;
}

List<bool> _weeklyActivityFromModules(List<ModuleProgressData> modules) {
  final week = List<bool>.filled(7, false);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));

  for (final module in modules) {
    final completedAt = module.lastCompletedAt;
    if (completedAt == null) continue;
    final day = DateTime(completedAt.year, completedAt.month, completedAt.day);
    final index = day.difference(monday).inDays;
    if (index >= 0 && index < week.length) week[index] = true;
  }

  return week;
}

int _streakFromModules(List<ModuleProgressData> modules) {
  final completedDays = modules
      .map((module) => module.lastCompletedAt)
      .whereType<DateTime>()
      .map((date) => DateTime(date.year, date.month, date.day))
      .toSet();

  var streak = 0;
  var cursor = DateTime.now();
  cursor = DateTime(cursor.year, cursor.month, cursor.day);

  while (completedDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return streak;
}
