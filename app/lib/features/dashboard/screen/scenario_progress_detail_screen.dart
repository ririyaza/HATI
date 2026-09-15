import 'package:flutter/material.dart';

import 'weekly_progress_data.dart';

/// Detail view opened by tapping a Scenario Module card on the Progress
/// screen. Mirrors `WeeklyProgressDetailScreen`'s header/background styling
/// for consistency.
///
/// Scores are real: every emotion log for [scenarioKey] across every play
/// session, scoped to P.I.E.S./Interaction only (see
/// `EmotionLogEntry.isPiesOrInteraction` in weekly_progress_data.dart) —
/// the same scene scoping the end-of-scenario summary and the Weekly
/// Progress screen already use, so this module's numbers never disagree
/// with either of those.
class ScenarioProgressDetailScreen extends StatefulWidget {
  final String scenarioKey;

  const ScenarioProgressDetailScreen({super.key, required this.scenarioKey});

  static const _blue = Color(0xFF0B28D9);

  // PNG (not SVG): these are flattened raster exports of the Hati_emojis
  // source art. flutter_svg doesn't reliably support the layered/masked
  // SVG features the originals use (embedded raster fills clipped by
  // vector paths), which renders as a blank/silhouette image — see the
  // same tradeoff in scenario_models.dart's placeholderAsset.
  static const _emotionAssets = {
    'anxious': 'assets/Hati_emojis/hati_anxious.png',
    'happy': 'assets/Hati_emojis/hati_happy.png',
    'neutral': 'assets/Hati_emojis/hati_neutral.png',
    'sad': 'assets/Hati_emojis/hati_sad.png',
    'anger': 'assets/Hati_emojis/hati_mad.png',
    'disgust': 'assets/Hati_emojis/hati_disgust.png',
    'surprised': 'assets/Hati_emojis/hati_surprised.png',
  };

  @override
  State<ScenarioProgressDetailScreen> createState() =>
      _ScenarioProgressDetailScreenState();
}

/// Which sessions count toward the chart — 'all' combines Easy + Hard
/// (the only option that existed before this filter), 'easy'/'difficult'
/// scope to just that mode's own logs. Logs written before scenario_engine.py
/// started tagging difficulty default to 'easy' (see EmotionLogEntry) — a
/// guess for old data, not a fact, so a "difficult" filter is only reliable
/// for sessions played after that change shipped.
enum _DifficultyFilter {
  all('All Modes'),
  easy('Easy Mode'),
  difficult('Hard Mode');

  const _DifficultyFilter(this.label);
  final String label;
}

class _ScenarioProgressDetailScreenState
    extends State<ScenarioProgressDetailScreen> {
  late final Future<List<EmotionLogEntry>> _logsFuture = fetchAllEmotionLogs();
  _DifficultyFilter _difficultyFilter = _DifficultyFilter.all;

  // All 7 canonical emotions (same set/order as weekly_progress_data.dart's
  // Emotion Trends chart) — this used to track only 4 of them. _scoresFrom
  // below still counted EVERY relevant log (any of the 7) into `total`,
  // just never showed anger/disgust/surprised as their own bar — so those
  // logs silently deflated all 4 displayed percentages (denominator too
  // big for what was actually shown, never summing to 100%) instead of
  // just being absent.
  static const _trackedEmotions = [
    'happy',
    'sad',
    'anxious',
    'anger',
    'disgust',
    'surprised',
    'neutral',
  ];

  List<_EmotionScore> _scoresFrom(List<EmotionLogEntry> allLogs) {
    final relevant = allLogs.where(
      (e) =>
          e.scenarioKey == widget.scenarioKey &&
          e.isPiesOrInteraction &&
          (_difficultyFilter == _DifficultyFilter.all ||
              e.difficulty == _difficultyFilter.name),
    );
    final counts = <String, int>{};
    var total = 0;
    for (final entry in relevant) {
      counts[entry.emotion] = (counts[entry.emotion] ?? 0) + 1;
      total++;
    }
    return [
      for (final key in _trackedEmotions)
        _EmotionScore(
          key,
          key[0].toUpperCase() + key.substring(1),
          total == 0 ? 0 : (counts[key] ?? 0) / total * 100,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScenarioProgressDetailScreen._blue,
      body: SafeArea(
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
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Scenario Progress',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Scopes the whole screen below (dominant mood + bars) to
                  // just one mode's logs, or both combined — see
                  // _DifficultyFilter.
                  PopupMenuButton<_DifficultyFilter>(
                    initialValue: _difficultyFilter,
                    onSelected: (v) => setState(() => _difficultyFilter = v),
                    color: const Color(0xFF13308F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    icon: const Icon(
                      Icons.filter_alt_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    itemBuilder: (context) => [
                      for (final f in _DifficultyFilter.values)
                        PopupMenuItem(
                          value: f,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                f.label,
                                style: const TextStyle(color: Colors.white),
                              ),
                              if (f == _difficultyFilter)
                                const Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<EmotionLogEntry>>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  final scores = _scoresFrom(snapshot.data ?? const []);
                  final total = scores.fold<double>(
                    0,
                    (sum, s) => sum + s.value,
                  );
                  final dominant = total == 0
                      ? null
                      : scores.reduce((a, b) => b.value > a.value ? b : a);
                  // No dominant emotion yet (never played) falls back to
                  // the neutral mood art rather than a made-up default.
                  final emotionAsset = dominant == null
                      ? ScenarioProgressDetailScreen._emotionAssets['neutral']!
                      : (ScenarioProgressDetailScreen
                                ._emotionAssets[dominant.key] ??
                            ScenarioProgressDetailScreen
                                ._emotionAssets['neutral']!);

                  final String headline;
                  final String body;
                  if (total == 0) {
                    // Distinguishes "never played at all" from "played,
                    // just not in the currently-selected mode" — otherwise
                    // filtering to Hard Mode on a scenario you've only ever
                    // played Easy falsely reads as never having touched it.
                    if (_difficultyFilter == _DifficultyFilter.all) {
                      headline = "You haven't practiced this scenario yet";
                      body =
                          "Play through it once and I'll start tracking how "
                          "you feel during the P.I.E.S. check-in and the "
                          "conversation itself.";
                    } else {
                      headline = "No ${_difficultyFilter.label} logs yet";
                      body =
                          "You haven't played this scenario in "
                          "${_difficultyFilter.label} yet — switch the "
                          "filter above or give it a try.";
                    }
                  } else {
                    // Used to only special-case 'anxious' — every other
                    // dominant emotion, sad/anger/disgust included, fell
                    // through to the same "handling this one well" message,
                    // which read as tone-deaf when the logs were actually
                    // dominated by a different negative emotion.
                    switch (dominant?.key) {
                      case 'anxious':
                        headline = 'Take things one step at a time';
                        body =
                            'Your logs for this scenario show more anxious '
                            'moments than calm ones. Try to slow down, '
                            'breathe, and focus on small improvements.';
                      case 'sad':
                        headline = "It's okay to feel this way";
                        body =
                            'Your logs for this scenario lean toward sadder '
                            "moments. Be gentle with yourself — progress "
                            "isn't always a straight line.";
                      case 'anger':
                        headline = "Notice what's triggering this";
                        body =
                            'Your logs for this scenario show more '
                            'frustration than ease. Try pausing to breathe '
                            'before reacting next time.';
                      case 'disgust':
                        headline = "It's okay to feel uneasy";
                        body =
                            'Your logs for this scenario lean toward '
                            'discomfort. Recognizing that reaction is the '
                            'first step to managing it.';
                      default:
                        headline = "You're handling this one well";
                        body =
                            'Your logs for this scenario lean toward '
                            'steadier emotions. Keep practicing to build on '
                            'that.';
                    }
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(
                      children: [
                        _EmotionGlowCircle(assetPath: emotionAsset),
                        const SizedBox(height: 28),
                        Text(
                          headline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 46,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF3DA9FC),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Let's Practice More",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        // 7 bars (previously 4, which fit fine in one row)
                        // are wide enough to overflow a narrow phone screen
                        // — wraps onto additional rows (typically 4 then 3)
                        // instead of scrolling sideways, so every bar is
                        // visible at once without a swipe. Emotions never
                        // logged for this scenario (0%) are skipped
                        // entirely rather than shown as an empty bar.
                        Wrap(
                          alignment: WrapAlignment.center,
                          runSpacing: 16,
                          children: [
                            for (final s in scores)
                              if (s.value > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: _EmotionBar(score: s),
                                ),
                          ],
                        ),
                      ],
                    ),
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

class _EmotionScore {
  const _EmotionScore(this.key, this.label, this.value);
  final String key;
  final String label;
  final double value;
}

class _EmotionGlowCircle extends StatelessWidget {
  const _EmotionGlowCircle({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          ClipOval(
            child: Container(
              width: 140,
              height: 140,
              color: const Color(0xFF4C2E8F),
              alignment: Alignment.center,
              // BoxFit.cover + a matching-size ClipOval so the art fills
              // the entire circle edge-to-edge (cropping to fit) instead
              // of sitting as a smaller inset square with the purple
              // background showing around it.
              child: Image.asset(
                assetPath,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                // A swapped-in file that fails to decode shouldn't crash
                // this screen — falls back to a plain icon instead.
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.emoji_emotions_outlined,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmotionBar extends StatelessWidget {
  const _EmotionBar({required this.score});

  final _EmotionScore score;

  static const _maxHeight = 130.0;
  static const _maxValue = 100.0;

  @override
  Widget build(BuildContext context) {
    final barHeight = (_maxHeight * (score.value / _maxValue)).clamp(
      16.0,
      _maxHeight,
    );

    return Column(
      children: [
        Text(
          // score.value is this emotion's SHARE of this scenario's own
          // logs (see _scoresFrom), not a raw occurrence count — displaying
          // it bare (no "%") made it look like an absolute count, which
          // reads as wildly inconsistent next to Weekly Progress's Emotion
          // Trends chart (a true all-scenario, all-time raw count) even
          // though neither number is actually wrong.
          '${score.value.toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 52,
          height: _maxHeight,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8BC34A), Color(0xFFFF9800)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          score.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
