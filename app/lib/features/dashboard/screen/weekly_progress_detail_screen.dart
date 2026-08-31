import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Detail view opened from "This Week" on the Progress screen: a 3-page
/// swipeable breakdown (Summary / Trigger Patterns / Emotion Trends).
///
/// UI-only for now, per product decision: the calendar highlights and the
/// trend/trigger/emotion numbers below are placeholder demo data, clearly
/// not derived from the signed-in user's real activity. The app doesn't
/// currently track a confidence/anxiety score or a trigger category per
/// scenario anywhere in Firestore, so there's nothing real yet to plot for
/// the Summary trend cards or Trigger Patterns. Emotion Trends could
/// eventually be backed by the real per-scenario `emotionLogs` subcollection
/// used in `emotiondetection/scenario_game.dart`, but is left as demo data
/// here too so the three pages stay internally consistent until that
/// aggregation is built.
class WeeklyProgressDetailScreen extends StatefulWidget {
  const WeeklyProgressDetailScreen({super.key});

  @override
  State<WeeklyProgressDetailScreen> createState() =>
      _WeeklyProgressDetailScreenState();
}

class _WeeklyProgressDetailScreenState
    extends State<WeeklyProgressDetailScreen> {
  static const _blue = Color(0xFF0B28D9);

  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      'Weekly Progress',
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
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _SummaryPage(),
                  _TriggerPatternsPage(),
                  _EmotionTrendsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPage extends StatelessWidget {
  const _SummaryPage();

  static const _activeCells = {0, 1, 2, 4};

  @override
  Widget build(BuildContext context) {
    final monthLabel = _formatMonth(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _CalendarCard(activeCells: _activeCells),
          const SizedBox(height: 20),
          const _TrendCard(
            label: 'Confidence',
            changeLabel: '10%',
            improving: true,
            color: Color(0xFF1DB954),
            values: [0.35, 0.5, 0.42, 0.55, 0.5, 0.62, 0.8],
          ),
          const SizedBox(height: 14),
          const _TrendCard(
            label: 'Anxiety',
            changeLabel: '15%',
            improving: false,
            color: Color(0xFFE5484D),
            values: [0.75, 0.6, 0.68, 0.5, 0.55, 0.4, 0.32],
          ),
          const SizedBox(height: 20),
          const _FeedbackCard(),
        ],
      ),
    );
  }

  static String _formatMonth(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]}, ${date.year}';
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.activeCells});

  final Set<int> activeCells;

  static const _dayLabels = ['S', 'M', 'T', 'W', 'TH', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: _dayLabels
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          for (var row = 0; row < 5; row++)
            Row(
              children: List.generate(7, (col) {
                final index = row * 7 + col;
                final visible = index < 30;
                final active = activeCells.contains(index);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: visible
                        ? AspectRatio(
                            aspectRatio: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFFFFB020)
                                    : Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.label,
    required this.changeLabel,
    required this.improving,
    required this.color,
    required this.values,
  });

  final String label;
  final String changeLabel;
  final bool improving;
  final Color color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                improving
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: Colors.black87,
              ),
              const SizedBox(width: 2),
              Text(
                changeLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 120,
            height: 44,
            child: CustomPaint(
              painter: _SparklinePainter(values: values, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final dx = size.width / (values.length - 1);

    final points = List.generate(values.length, (i) {
      final y = size.height * (1 - values[i]);
      return Offset(i * dx, y);
    });

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final dot = Paint()..color = color;
    for (final p in points) {
      canvas.drawCircle(p, 2.6, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Text(
            'Feedback',
            style: TextStyle(
              color: Color(0xFF0B28D9),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your recent results show lower anxiety and higher confidence. '
            'Finishing multiple scenarios is a good sign of progress. Stay '
            'consistent and continue challenging yourself.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TriggerDatum {
  const _TriggerDatum(this.label, this.value);
  final String label;
  final double value;
}

class _TriggerPatternsPage extends StatelessWidget {
  const _TriggerPatternsPage();

  static const _triggers = [
    _TriggerDatum('Speaking in class', 25.25),
    _TriggerDatum('Talking to stranger', 34.86),
    _TriggerDatum('Authority figure', 29.86),
    _TriggerDatum('Social gathering', 63.75),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trigger Patterns',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Most Common Triggers',
                  style: TextStyle(
                    color: Colors.black45,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                const _TriggerAxis(),
                const SizedBox(height: 12),
                ..._triggers.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _TriggerBarRow(datum: t),
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

class _TriggerAxis extends StatelessWidget {
  const _TriggerAxis();

  static const _marks = ['0', '20', '40', '60', '80', '100'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 120),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _marks
                .map(
                  (m) => Text(
                    m,
                    style: const TextStyle(fontSize: 10, color: Colors.black38),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _TriggerBarRow extends StatelessWidget {
  const _TriggerBarRow({required this.datum});

  final _TriggerDatum datum;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            datum.label,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fraction = (datum.value / 100).clamp(0.0, 1.0);
              final barWidth = constraints.maxWidth * fraction;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    width: barWidth,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB7A6F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Positioned(
                    left: barWidth + 6,
                    child: Text(
                      datum.value.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmotionDatum {
  const _EmotionDatum(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _EmotionTrendsPage extends StatelessWidget {
  const _EmotionTrendsPage();

  static const _emotions = [
    _EmotionDatum('Happy', 45, Color(0xFFB7A6F2)),
    _EmotionDatum('Sad', 26, Color(0xFFFF8C82)),
    _EmotionDatum('Anxious', 38, Color(0xFF3FD3E0)),
    _EmotionDatum('Surprise', 23, Color(0xFFFFC24B)),
    _EmotionDatum('Disgust', 11, Color(0xFF5FE0C7)),
    _EmotionDatum('Neutral', 34, Color(0xFF6FE38B)),
    _EmotionDatum('Angry', 31, Color(0xFF8B5CF6)),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emotion Trends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.filter_alt_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Weeks',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: CustomPaint(
                    painter: _EmotionRosePainter(emotions: _emotions),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _EmotionLegend(emotions: _emotions),
        ],
      ),
    );
  }
}

class _EmotionRosePainter extends CustomPainter {
  _EmotionRosePainter({required this.emotions});

  final List<_EmotionDatum> emotions;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 24;
    final maxValue = emotions.map((e) => e.value).reduce(math.max);
    final sweep = (2 * math.pi) / emotions.length;
    var start = -math.pi / 2;

    for (final emotion in emotions) {
      final radius = maxRadius * (emotion.value / maxValue);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()..color = emotion.color.withValues(alpha: 0.9),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final labelAngle = start + sweep / 2;
      final labelRadius = radius * 0.62 + 14;
      final labelCenter = Offset(
        center.dx + labelRadius * math.cos(labelAngle),
        center.dy + labelRadius * math.sin(labelAngle),
      );

      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${emotion.label}\n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: emotion.value.toStringAsFixed(0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2),
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _EmotionRosePainter oldDelegate) => false;
}

class _EmotionLegend extends StatelessWidget {
  const _EmotionLegend({required this.emotions});

  final List<_EmotionDatum> emotions;

  @override
  Widget build(BuildContext context) {
    final left = emotions.sublist(0, 4);
    final right = emotions.sublist(4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _EmotionLegendColumn(emotions: left)),
        Expanded(child: _EmotionLegendColumn(emotions: right)),
      ],
    );
  }
}

class _EmotionLegendColumn extends StatelessWidget {
  const _EmotionLegendColumn({required this.emotions});

  final List<_EmotionDatum> emotions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: emotions
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: e.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
