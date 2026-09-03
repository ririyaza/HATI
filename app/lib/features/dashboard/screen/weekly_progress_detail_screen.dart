import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'weekly_progress_data.dart';

/// Detail view opened from "This Week" on the Progress screen: a 3-page
/// swipeable breakdown (Summary / Trigger Patterns / Emotion Trends), backed
/// by the signed-in user's real `emotionLogs` data from Firestore (see
/// weekly_progress_data.dart for the fetch/aggregation logic).
///
/// Confidence/Anxiety (Summary page) are scoped to the current week, matching
/// this screen's own name and its "This Week" entry point on the Progress
/// screen. Trigger Patterns and Emotion Trends are all-time, since they're
/// about overall patterns across every scenario play, not a single week's
/// snapshot.
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
  DateTime _displayedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  late Future<List<EmotionLogEntry>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = fetchAllEmotionLogs();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    var picked = _displayedMonth;
    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => setDialogState(
                  () => picked = DateTime(picked.year, picked.month - 1),
                ),
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  _formatMonth(picked),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setDialogState(
                  () => picked = DateTime(picked.year, picked.month + 1),
                ),
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, picked),
              child: const Text('Go', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _displayedMonth = DateTime(result.year, result.month));
    }
  }

  static String _formatMonth(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]}, ${date.year}';
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
              child: FutureBuilder<List<EmotionLogEntry>>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          "Couldn't load your progress data. Pull to refresh or try again later.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }
                  final logs = snapshot.data ?? const [];
                  final confidenceAnxiety =
                      computeConfidenceAnxiety(logs, DateTime.now());
                  final activeDays = activeDaysInMonth(logs, _displayedMonth);
                  final triggers = computeTriggerPatterns(logs);
                  final emotions = computeEmotionTrends(logs);

                  return PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _SummaryPage(
                        month: _displayedMonth,
                        activeDays: activeDays,
                        summary: confidenceAnxiety,
                        onTapMonth: _pickMonth,
                      ),
                      _TriggerPatternsPage(triggers: triggers),
                      _EmotionTrendsPage(emotions: emotions),
                    ],
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

class _SummaryPage extends StatelessWidget {
  const _SummaryPage({
    required this.month,
    required this.activeDays,
    required this.summary,
    required this.onTapMonth,
  });

  final DateTime month;
  final Set<int> activeDays;
  final ConfidenceAnxietySummary summary;
  final VoidCallback onTapMonth;

  @override
  Widget build(BuildContext context) {
    final monthLabel = _formatMonth(month);

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
          InkWell(
            onTap: onTapMonth,
            child: Align(
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
          ),
          const SizedBox(height: 10),
          _CalendarCard(month: month, activeDays: activeDays),
          const SizedBox(height: 20),
          _TrendCard(
            label: 'Confidence',
            changeLabel: '${(summary.confidenceChangePct.abs() * 100).toStringAsFixed(0)}%',
            improving: summary.confidenceChangePct >= 0,
            color: const Color(0xFF1DB954),
            values: summary.confidenceSparkline,
          ),
          const SizedBox(height: 14),
          _TrendCard(
            label: 'Anxiety',
            changeLabel: '${(summary.anxietyChangePct.abs() * 100).toStringAsFixed(0)}%',
            // "improving" here just means the raw value went up (matches
            // the arrow's literal direction, not a good/bad judgment) — the
            // original demo data showed a *decreasing* anxiety trend with a
            // *downward* arrow, so a decrease must map to improving:false,
            // same as an increase maps to improving:true for Confidence.
            improving: summary.anxietyChangePct >= 0,
            color: const Color(0xFFE5484D),
            values: summary.anxietySparkline,
          ),
          const SizedBox(height: 20),
          _FeedbackCard(message: computeFeedbackMessage(summary)),
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
  const _CalendarCard({required this.month, required this.activeDays});

  final DateTime month;
  final Set<int> activeDays;

  static const _dayLabels = ['S', 'M', 'T', 'W', 'TH', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday: Mon=1..Sun=7. The day labels above are Sunday-first,
    // so the leading blank-cell count is however many days after Sunday the
    // 1st falls on (0 if the 1st is itself a Sunday).
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leadingBlanks = firstWeekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

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
          for (var row = 0; row < rows; row++)
            Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final day = cellIndex - leadingBlanks + 1;
                final visible = day >= 1 && day <= daysInMonth;
                final active = visible && activeDays.contains(day);
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
  const _FeedbackCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'Feedback',
            style: TextStyle(
              color: Color(0xFF0B28D9),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
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

class _TriggerPatternsPage extends StatelessWidget {
  const _TriggerPatternsPage({required this.triggers});

  final List<TriggerDatum> triggers;

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
                if (triggers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Finish a few scenarios to see your trigger patterns here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black45, fontSize: 12.5),
                    ),
                  )
                else
                  ...triggers.map(
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

  final TriggerDatum datum;

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

class _EmotionTrendsPage extends StatelessWidget {
  const _EmotionTrendsPage({required this.emotions});

  final List<EmotionDatum> emotions;

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
                      'All time',
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
                  child: emotions.every((e) => e.value <= 0)
                      ? const Center(
                          child: Text(
                            'Finish a few scenarios to see your emotion trends here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        )
                      : CustomPaint(
                          painter: _EmotionRosePainter(emotions: emotions),
                          size: Size.infinite,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _EmotionLegend(emotions: emotions),
        ],
      ),
    );
  }
}

class _EmotionRosePainter extends CustomPainter {
  _EmotionRosePainter({required this.emotions});

  final List<EmotionDatum> emotions;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 24;
    final maxValue = emotions.map((e) => e.value).reduce(math.max);
    if (maxValue <= 0) return; // no data yet — nothing to draw, avoids a div-by-zero
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
  bool shouldRepaint(covariant _EmotionRosePainter oldDelegate) =>
      oldDelegate.emotions != emotions;
}

class _EmotionLegend extends StatelessWidget {
  const _EmotionLegend({required this.emotions});

  final List<EmotionDatum> emotions;

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

  final List<EmotionDatum> emotions;

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
