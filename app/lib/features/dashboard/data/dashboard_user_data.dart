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

  List<BadgeData> get badges => [
    BadgeData(
      icon: '*',
      label: 'First Step',
      earned: scenariosCompleted > 0,
    ),
    BadgeData(
      icon: 'F',
      label: '5-Day\nStreak',
      earned: currentStreak >= 5,
    ),
    BadgeData(
      icon: 'T',
      label: 'Half Way!',
      earned: overallProgress >= 0.5,
    ),
    BadgeData(
      icon: '!',
      label: 'Quick\nThinker',
      earned: scenariosCompleted >= 3,
    ),
    BadgeData(
      icon: 'A',
      label: 'Sharpshooter',
      earned: overallProgress >= 1,
    ),
  ];
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
    required this.icon,
    required this.label,
    required this.earned,
  });

  final String icon;
  final String label;
  final bool earned;
}

class DashboardDataService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Stream<DashboardUserData> watchForUser(User user) {
    final userRef = _firestore.collection('users').doc(user.uid);
    return userRef.snapshots().asyncMap((userDoc) async {
      final moduleDocs = await userRef.collection('moduleProgress').get();
      final assessmentDocs = await userRef.collection('spinAssessments').get();
      return DashboardUserDataParser.parse(
        user: user,
        userDoc: userDoc,
        moduleDocs: moduleDocs.docs,
        assessmentDocs: assessmentDocs.docs,
      );
    });
  }
}

class DashboardUserDataParser {
  static const _knownModules = {
    'where_to_sit': _ModuleDefinition(
      title: 'WHERE TO SIT?',
      subtitle: 'Social awareness - 1 scenario',
      icon: 'W',
      totalScenarios: 1,
    ),
  };

  static DashboardUserData parse({
    required User user,
    required DocumentSnapshot<Map<String, dynamic>> userDoc,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> moduleDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> assessmentDocs,
  }) {
    final data = userDoc.data() ?? {};
    final modules = _parseModules(moduleDocs);
    final assessments = _parseAssessments(data, assessmentDocs);
    final copingPreferences = _parseCopingPreferences(data, assessmentDocs);

    return DashboardUserData(
      uid: user.uid,
      email: _string(data['email'], fallback: user.email ?? ''),
      displayName: _string(
        data['displayName'] ?? data['nickname'],
        fallback: user.email?.split('@').first ?? 'HATI User',
      ),
      photoUrl: _string(
        data['profilePicUrl'] ??
            data['photoURL'] ??
            data['photoUrl'] ??
            user.photoURL,
      ),
      pronouns: _string(data['pronouns']),
      goal: _string(data['goal']),
      copingPreferences: copingPreferences,
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
