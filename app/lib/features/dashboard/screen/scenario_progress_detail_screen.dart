import 'package:flutter/material.dart';

/// Detail view opened by tapping a Scenario Module card on the Progress
/// screen. Mirrors `WeeklyProgressDetailScreen`'s header/background styling
/// for consistency.
///
/// UI-only for now, like `WeeklyProgressDetailScreen`: the four emotion
/// scores below are placeholder demo data — the app doesn't yet aggregate a
/// module's `emotionLogs` (see `emotiondetection/scenario_game.dart`)
/// across play sessions into a single per-module score. The dominant-
/// emotion emoji in the circle is real logic though: it's always whichever
/// of the four scores is currently highest, so it keeps working correctly
/// once real aggregated data replaces the placeholders below.
class ScenarioProgressDetailScreen extends StatelessWidget {
  const ScenarioProgressDetailScreen({super.key});

  static const _blue = Color(0xFF0B28D9);

  static const _scores = [
    _EmotionScore('anxious', 'Anxious', 88),
    _EmotionScore('happy', 'Happy', 51),
    _EmotionScore('neutral', 'Neutral', 30),
    _EmotionScore('sad', 'Sad', 71),
  ];

  static const _emojis = {
    'anxious': '😰',
    'happy': '😊',
    'neutral': '😐',
    'sad': '😢',
    'anger': '😠',
    'disgust': '🤢',
    'surprised': '😲',
  };

  static _EmotionScore get _dominant =>
      _scores.reduce((a, b) => b.value > a.value ? b : a);

  @override
  Widget build(BuildContext context) {
    final dominant = _dominant;
    final emoji = _emojis[dominant.key] ?? '🙂';

    return Scaffold(
      backgroundColor: _blue,
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
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  children: [
                    _EmotionGlowCircle(emoji: emoji),
                    const SizedBox(height: 28),
                    const Text(
                      'Take things one step at a time',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your recent logs show increased anxiety. Try to slow '
                      'down, breathe, and focus on small improvements.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                          padding: const EdgeInsets.symmetric(horizontal: 28),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _scores
                          .map((s) => _EmotionBar(score: s))
                          .toList(),
                    ),
                  ],
                ),
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
  const _EmotionGlowCircle({required this.emoji});

  final String emoji;

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
          Container(
            width: 140,
            height: 140,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4C2E8F),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 56)),
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
          score.value.toStringAsFixed(0),
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
