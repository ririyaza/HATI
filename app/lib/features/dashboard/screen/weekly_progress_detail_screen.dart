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
/// screen. Trigger Patterns is all-time, since it's about overall patterns
/// across every scenario play, not a single week's snapshot. Emotion Trends
/// defaults to all-time too, but its own filter (Daily/This week/All time —
/// see [EmotionTrendsRange]) lets the user narrow it down.
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
  EmotionTrendsRange _emotionTrendsRange = EmotionTrendsRange.allTime;
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
                  final emotions = computeEmotionTrends(
                    logs,
                    range: _emotionTrendsRange,
                  );

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
                      _EmotionTrendsPage(
                        emotions: emotions,
                        range: _emotionTrendsRange,
                        onRangeChanged: (r) =>
                            setState(() => _emotionTrendsRange = r),
                      ),
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
                const SizedBox(height: 12),
                const _TriggerSeverityLegend(),
                const SizedBox(height: 16),
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

/// Three-tier severity coloring for a trigger's anxiety rate — validated
/// (`validate_palette.js`, light mode) as a green/amber/red status trio
/// distinguishable even under protan/deutan color vision, on the condition
/// (met by [_TriggerSeverityLegend] plus each bar's own visible percentage)
/// that color is never the only signal for which tier a bar is in.
const Color _kLowTrigger = Color(0xFF16A34A);
const Color _kModerateTrigger = Color(0xFFD97706);
const Color _kHighTrigger = Color(0xFFB91C1C);

Color _triggerSeverityColor(double value) {
  if (value >= 67) return _kHighTrigger;
  if (value >= 34) return _kModerateTrigger;
  return _kLowTrigger;
}

class _TriggerSeverityLegend extends StatelessWidget {
  const _TriggerSeverityLegend();

  static const _tiers = [
    ('Low', _kLowTrigger),
    ('Moderate', _kModerateTrigger),
    ('High', _kHighTrigger),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final tier in _tiers)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: tier.$2, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                tier.$1,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
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

  /// Text sits *inside* the bar (right-aligned, white) once it's wide enough
  /// to hold "100%" without crowding the fill's edge — this is also what
  /// keeps a near-100% bar's label from being pushed past the track and
  /// clipped, which is what happened when the label always rendered to the
  /// bar's right.
  static const _insideLabelThreshold = 0.22;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                datum.label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                datum.sampleSize == 1
                    ? '1 log'
                    : '${datum.sampleSize} logs',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Colors.black38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fraction = (datum.value / 100).clamp(0.0, 1.0);
              final barWidth = constraints.maxWidth * fraction;
              final barColor = _triggerSeverityColor(datum.value);
              final labelInside = fraction >= _insideLabelThreshold;
              final valueText = '${datum.value.round()}%';

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
                  // Gridlines at 20/40/60/80% — same positions _TriggerAxis
                  // labels sit above, so the numbers up top actually line up
                  // with something down here instead of floating free.
                  for (final mark in [0.2, 0.4, 0.6, 0.8])
                    Positioned(
                      left: constraints.maxWidth * mark,
                      child: Container(width: 1, height: 22, color: Colors.black12),
                    ),
                  Container(
                    width: barWidth,
                    height: 22,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  if (labelInside)
                    Positioned(
                      left: 0,
                      width: barWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          valueText,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      left: barWidth + 6,
                      child: Text(
                        valueText,
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
  const _EmotionTrendsPage({
    required this.emotions,
    required this.range,
    required this.onRangeChanged,
  });

  final List<EmotionDatum> emotions;
  final EmotionTrendsRange range;
  final ValueChanged<EmotionTrendsRange> onRangeChanged;

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
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<EmotionTrendsRange>(
                    initialValue: range,
                    onSelected: onRangeChanged,
                    color: const Color(0xFF13308F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      for (final r in EmotionTrendsRange.values)
                        PopupMenuItem(
                          value: r,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                r.label,
                                style: const TextStyle(color: Colors.white),
                              ),
                              if (r == range)
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.filter_alt_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          range.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                emotions.every((e) => e.value <= 0)
                    ? SizedBox(
                        height: 260,
                        child: Center(
                          child: Text(
                            switch (range) {
                              EmotionTrendsRange.daily =>
                                "No emotions logged today yet — play a scenario to see today's trends.",
                              EmotionTrendsRange.weekly =>
                                "No emotions logged this week yet — play a scenario to see this week's trends.",
                              EmotionTrendsRange.allTime =>
                                'Finish a few scenarios to see your emotion trends here.',
                            },
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      )
                    : _EmotionDonutChart(emotions: emotions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A real pie/donut chart — slices are proportional to value by angle only
/// (equal radius throughout), unlike the earlier polar/"rose" chart that
/// varied *both* radius and angle, which made slices impossible to compare
/// at a glance. Improvements over a plain pie: slices are ordered
/// largest-first from 12 o'clock clockwise (so position itself communicates
/// rank), a thin background-color gap separates every slice, big-enough
/// slices carry their own "NN%" label, the donut hole surfaces the total
/// log count instead of going to waste, and the legend below lists every
/// emotion in the same largest-first order with its exact percentage and
/// count, so nothing depends on eyeballing similar hues.
class _EmotionDonutChart extends StatelessWidget {
  const _EmotionDonutChart({required this.emotions});

  final List<EmotionDatum> emotions;

  @override
  Widget build(BuildContext context) {
    final sorted = [...emotions]..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (sum, e) => sum + e.value);
    final slices = sorted.where((e) => e.value > 0).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          width: 200,
          child: CustomPaint(
            painter: _EmotionDonutPainter(slices: slices, total: total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'logged',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Column(
          children: [
            for (final emotion in sorted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: emotion.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        emotion.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      total <= 0
                          ? '0%'
                          : '${(emotion.value / total * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text(
                        emotion.value.toStringAsFixed(0),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmotionDonutPainter extends CustomPainter {
  _EmotionDonutPainter({required this.slices, required this.total});

  /// Non-zero-value emotions only, already sorted largest-first.
  final List<EmotionDatum> slices;
  final double total;

  /// Angular gap left as background between adjacent slices — a visual
  /// separator that works regardless of how close two slice colors are,
  /// rather than relying on a stroke outline.
  static const _gapRadians = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || slices.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2;
    final ringWidth = outerRadius * 0.4;
    final ringRadius = outerRadius - ringWidth / 2;
    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);

    final totalGap = _gapRadians * slices.length;
    final sweepBudget = (2 * math.pi) - totalGap;

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * sweepBudget;

      canvas.drawArc(
        ringRect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..strokeCap = StrokeCap.butt,
      );

      // Only label slices wide enough to fit "NN%" without crowding —
      // everything else is still exact in the legend below.
      final share = slice.value / total;
      if (share >= 0.06) {
        final labelAngle = startAngle + sweep / 2;
        final labelCenter = Offset(
          center.dx + ringRadius * math.cos(labelAngle),
          center.dy + ringRadius * math.sin(labelAngle),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '${(share * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(labelCenter.dx - tp.width / 2, labelCenter.dy - tp.height / 2),
        );
      }

      startAngle += sweep + _gapRadians;
    }
  }

  @override
  bool shouldRepaint(covariant _EmotionDonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}
