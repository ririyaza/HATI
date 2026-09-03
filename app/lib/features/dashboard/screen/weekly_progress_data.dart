import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show Color;

import '../../emotiondetection/themed_scenario/scenario_models.dart'
    show kStepToScene, SceneId;

/// One flattened row from `users/{uid}/scenarios/{sessionId}/emotionLogs`,
/// combining the fields `_log_emotion` (scenario_engine.py) actually writes:
/// emotion, step, theme, scenario_key, timestamp (ISO string).
class EmotionLogEntry {
  const EmotionLogEntry({
    required this.emotion,
    required this.step,
    required this.theme,
    required this.scenarioKey,
    required this.timestamp,
  });

  /// Already normalized to one of the 7 canonical keys (see
  /// [normalizeEmotionLabel]) — happy/sad/anxious/anger/disgust/surprised/neutral.
  final String emotion;
  final String step;
  final String theme;
  final String scenarioKey;
  final DateTime timestamp;

  /// True only for a step rendered by Scene 1 (P.I.E.S.) or Scene 3
  /// (Interaction) — Trigger Patterns and Emotion Trends only count the
  /// user's own felt emotion during those two phases, per product decision;
  /// Briefing/Preparation/Debrief/Coping/Closing carry curated dialogue
  /// choices rather than the user's own reaction, so they're excluded.
  ///
  /// Classification reuses [kStepToScene], the app's own single source of
  /// truth for step->scene routing, rather than hand-duplicating its step
  /// list here (that duplication is exactly the class of bug this project
  /// kept hitting all session: a step added on one side and forgotten on
  /// the other). The one exception: the three `pies_*_other` follow-up
  /// steps (scenario_engine.py's P.I.E.S. "Other" custom-text flow) aren't
  /// in kStepToScene yet, so they're caught via the `pies_` prefix instead,
  /// which is true of every P.I.E.S. step by naming convention.
  bool get isPiesOrInteraction {
    if (step.startsWith('pies_')) return true;
    return kStepToScene[step] == SceneId.interaction;
  }
}

/// Same normalization scenario_game.dart's `_loadEmotionCounts` already
/// applies to raw backend emotion strings before counting them.
String? normalizeEmotionLabel(dynamic rawEmotion) {
  final label = rawEmotion?.toString().trim().toLowerCase();
  if (label == null || label.isEmpty) return null;
  if (['angry', 'anger'].contains(label)) return 'anger';
  if (['fear', 'fearful', 'scared', 'afraid'].contains(label)) return 'anxious';
  if (['joy', 'joyful', 'happy', 'love'].contains(label)) return 'happy';
  if (['sadness', 'sad', 'depressed'].contains(label)) return 'sad';
  if (['surprise', 'surprised'].contains(label)) return 'surprised';
  if (['disgust', 'disgusted'].contains(label)) return 'disgust';
  if (['neutral', 'calm', 'okay', 'meh'].contains(label)) return 'neutral';
  return label;
}

/// Reads every emotion log across every scenario session the signed-in user
/// has ever played. One Firestore read per session (its emotionLogs
/// subcollection) rather than a collectionGroup query, since a raw
/// collectionGroup('emotionLogs') would span every user's logs with no
/// per-doc user_id field to filter on cheaply.
Future<List<EmotionLogEntry>> fetchAllEmotionLogs() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];

  final sessionsSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('scenarios')
      .get();

  final logSnaps = await Future.wait(
    sessionsSnap.docs.map((s) => s.reference.collection('emotionLogs').get()),
  );

  final entries = <EmotionLogEntry>[];
  for (final logsSnap in logSnaps) {
    for (final doc in logsSnap.docs) {
      final data = doc.data();
      final emotion = normalizeEmotionLabel(data['emotion']);
      if (emotion == null) continue;
      final timestamp = DateTime.tryParse(data['timestamp']?.toString() ?? '');
      if (timestamp == null) continue;
      entries.add(EmotionLogEntry(
        emotion: emotion,
        step: (data['step'] ?? '').toString(),
        theme: (data['theme'] ?? '').toString(),
        scenarioKey: (data['scenario_key'] ?? '').toString(),
        timestamp: timestamp,
      ));
    }
  }
  return entries;
}

// ── Summary page: calendar + Confidence/Anxiety ────────────────────────────

const confidenceEmotions = {'happy', 'neutral', 'surprised'};
const anxietyEmotions = {'sad', 'anger', 'anxious', 'disgust'};

/// Days-of-month (1-31) on which the user has at least one emotion log in
/// [month] — drives the calendar's active-cell highlight. Every emotion log
/// counts here (not just P.I.E.S./Interaction ones) since the calendar is
/// about "did I do something that day," not the trigger-specific pages.
Set<int> activeDaysInMonth(List<EmotionLogEntry> logs, DateTime month) {
  return {
    for (final e in logs)
      if (e.timestamp.year == month.year && e.timestamp.month == month.month)
        e.timestamp.day,
  };
}

DateTime startOfWeek(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  // DateTime.weekday: Mon=1..Sun=7. The calendar's own day labels are
  // S/M/T/W/TH/F/S (Sunday-first), so the week start is the most recent
  // Sunday — weekday%7 gives 0 for Sunday itself, 1 for Monday, etc.
  return d.subtract(Duration(days: d.weekday % 7));
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class ConfidenceAnxietySummary {
  const ConfidenceAnxietySummary({
    required this.confidencePct,
    required this.anxietyPct,
    required this.confidenceChangePct,
    required this.anxietyChangePct,
    required this.confidenceSparkline,
    required this.anxietySparkline,
    required this.totalLogsThisWeek,
  });

  /// 0..1 fraction of this week's logs that were confidence emotions
  /// (happy/neutral/surprised). Since confidenceEmotions + anxietyEmotions
  /// covers all 7 canonical emotions exactly once each, confidencePct +
  /// anxietyPct == 1.0 whenever there's any data this week.
  final double confidencePct;
  final double anxietyPct;

  /// This week's pct minus last week's pct — positive means it went up.
  final double confidenceChangePct;
  final double anxietyChangePct;

  /// 7 values (Sun..Sat of the current week), each 0..1 — that day's
  /// confidence/anxiety fraction, or 0 on a day with no logs.
  final List<double> confidenceSparkline;
  final List<double> anxietySparkline;

  /// How many emotion logs (of any kind) fell in the current week — used to
  /// tell "no activity yet this week" apart from "confidencePct/anxietyPct
  /// both happen to be 0," since both read 0 in the no-data case too.
  final int totalLogsThisWeek;
}

double _pctOf(Set<String> bucket, List<EmotionLogEntry> pool) {
  if (pool.isEmpty) return 0;
  final count = pool.where((e) => bucket.contains(e.emotion)).length;
  return count / pool.length;
}

ConfidenceAnxietySummary computeConfidenceAnxiety(
  List<EmotionLogEntry> logs,
  DateTime now,
) {
  final weekStart = startOfWeek(now);
  final weekEnd = weekStart.add(const Duration(days: 7));
  final prevWeekStart = weekStart.subtract(const Duration(days: 7));

  final thisWeek = logs
      .where((e) => !e.timestamp.isBefore(weekStart) && e.timestamp.isBefore(weekEnd))
      .toList();
  final prevWeek = logs
      .where((e) => !e.timestamp.isBefore(prevWeekStart) && e.timestamp.isBefore(weekStart))
      .toList();

  final confidenceSparkline = List.generate(7, (i) {
    final day = weekStart.add(Duration(days: i));
    final pool = thisWeek.where((e) => _isSameDate(e.timestamp, day)).toList();
    return _pctOf(confidenceEmotions, pool);
  });
  final anxietySparkline = List.generate(7, (i) {
    final day = weekStart.add(Duration(days: i));
    final pool = thisWeek.where((e) => _isSameDate(e.timestamp, day)).toList();
    return _pctOf(anxietyEmotions, pool);
  });

  return ConfidenceAnxietySummary(
    confidencePct: _pctOf(confidenceEmotions, thisWeek),
    anxietyPct: _pctOf(anxietyEmotions, thisWeek),
    confidenceChangePct:
        _pctOf(confidenceEmotions, thisWeek) - _pctOf(confidenceEmotions, prevWeek),
    anxietyChangePct: _pctOf(anxietyEmotions, thisWeek) - _pctOf(anxietyEmotions, prevWeek),
    confidenceSparkline: confidenceSparkline,
    anxietySparkline: anxietySparkline,
    totalLogsThisWeek: thisWeek.length,
  );
}

/// Picks one of a few feedback messages based on how this week's anxiety
/// rate moved relative to last week — a >=5 percentage-point swing either
/// way is treated as a real change worth commenting on; anything smaller is
/// "steady." Mirrors the tone of the original static placeholder text for
/// the "clearly improving" case.
String computeFeedbackMessage(ConfidenceAnxietySummary summary) {
  if (summary.totalLogsThisWeek == 0) {
    return "You haven't logged any scenario activity yet this week. Try a "
        "scenario to start tracking your confidence and anxiety trends!";
  }

  const meaningfulShift = 0.05; // 5 percentage points
  final anxietyChange = summary.anxietyChangePct;

  if (anxietyChange <= -meaningfulShift) {
    return 'Your recent results show lower anxiety and higher confidence. '
        'Finishing multiple scenarios is a good sign of progress. Stay '
        'consistent and continue challenging yourself.';
  }
  if (anxietyChange >= meaningfulShift) {
    return 'This week showed a bit more anxiety than last week — that '
        "happens, and it's a normal part of practice. Consider revisiting "
        'a scenario that felt manageable before, and keep at it.';
  }
  return "Your confidence and anxiety levels have stayed fairly steady "
      "this week. Keep practicing consistently to keep building your "
      "confidence.";
}

// ── Trigger Patterns page ───────────────────────────────────────────────

class TriggerDatum {
  const TriggerDatum(this.label, this.value);
  final String label;

  /// 0..100 — of this theme's P.I.E.S.+Interaction emotion logs, what % were
  /// "anxious." This is an anxiety RATE per trigger, not a share of total
  /// anxious moments — the latter would just reflect how often a scenario
  /// was played, not how triggering it actually is.
  final double value;
}

/// scenario_engine.py's `_normalize_theme` canonical theme strings -> the
/// short trigger label the UI shows (kept close to this card's original
/// placeholder wording: "Authority figure", "Social gathering", etc.).
const _themeShortLabels = {
  'Fear of Authority': 'Authority figure',
  'Fear of Strangers & New People': 'Talking to stranger',
  'Fear of Being Observed & Performing': 'Being observed',
  'Fear of Social Gatherings': 'Social gathering',
  'Fear of Negative Evaluation & Embarrassment': 'Negative evaluation',
  'Physiological Symptoms': 'Physical symptoms',
};

List<TriggerDatum> computeTriggerPatterns(List<EmotionLogEntry> logs) {
  final relevant =
      logs.where((e) => e.isPiesOrInteraction && e.theme.isNotEmpty).toList();

  final totalByTheme = <String, int>{};
  final anxiousByTheme = <String, int>{};
  for (final e in relevant) {
    totalByTheme[e.theme] = (totalByTheme[e.theme] ?? 0) + 1;
    if (e.emotion == 'anxious') {
      anxiousByTheme[e.theme] = (anxiousByTheme[e.theme] ?? 0) + 1;
    }
  }

  final result = totalByTheme.entries.map((entry) {
    final anxiousCount = anxiousByTheme[entry.key] ?? 0;
    final pct = entry.value == 0 ? 0.0 : (anxiousCount / entry.value) * 100;
    return TriggerDatum(_themeShortLabels[entry.key] ?? entry.key, pct);
  }).toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return result;
}

// ── Emotion Trends page ─────────────────────────────────────────────────

class EmotionDatum {
  const EmotionDatum(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// (normalized emotion key, display label, chart color) — same 7 colors the
/// original placeholder UI used, so a real-data rose chart looks identical
/// in palette to what it replaces.
const _emotionDisplay = [
  ('happy', 'Happy', Color(0xFFB7A6F2)),
  ('sad', 'Sad', Color(0xFFFF8C82)),
  ('anxious', 'Anxious', Color(0xFF3FD3E0)),
  ('surprised', 'Surprise', Color(0xFFFFC24B)),
  ('disgust', 'Disgust', Color(0xFF5FE0C7)),
  ('neutral', 'Neutral', Color(0xFF6FE38B)),
  ('anger', 'Angry', Color(0xFF8B5CF6)),
];

/// Counts of each of the 7 emotions across every P.I.E.S./Interaction log
/// the user has ever had, across all scenarios — an all-time trend, not
/// scoped to a week (Trigger Patterns is the same way), unlike the
/// Confidence/Anxiety cards which this "Weekly Progress" screen scopes to
/// the current week.
List<EmotionDatum> computeEmotionTrends(List<EmotionLogEntry> logs) {
  final counts = {for (final e in _emotionDisplay) e.$1: 0};
  for (final e in logs) {
    if (!e.isPiesOrInteraction) continue;
    if (counts.containsKey(e.emotion)) {
      counts[e.emotion] = counts[e.emotion]! + 1;
    }
  }
  return _emotionDisplay
      .map((e) => EmotionDatum(e.$2, counts[e.$1]!.toDouble(), e.$3))
      .toList();
}
