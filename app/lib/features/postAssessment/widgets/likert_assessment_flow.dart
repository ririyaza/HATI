import 'package:flutter/material.dart';

import '../../spinAssessment/models/spin_question_model.dart';

/// Generic question-flow screen: one Likert-scale question at a time, with
/// a progress header and Back/Next controls.
///
/// This is a deliberate extraction of `spin_assessment_screen.dart`'s
/// question-screen visuals (`_buildQuestionScreen` / `_OptionTile`) into a
/// reusable, parameterized widget — NOT a reuse of that screen itself.
/// Reusing it directly would have meant driving it off the pre-test's
/// shared-global `spinQuestions` list and its `initialSpinScore` /
/// `accessBlocked` write path, which would corrupt onboarding state and
/// could incorrectly re-trigger the access-block flow from a reassessment.
/// The pre-test screen is untouched; this widget owns its own question
/// list per instance and never touches onboarding fields.
class LikertAssessmentFlow extends StatefulWidget {
  const LikertAssessmentFlow({
    super.key,
    required this.questions,
    required this.options,
    required this.promptEyebrow,
    required this.instructionLine,
    required this.startIndex,
    required this.totalInFlow,
    required this.onComplete,
    this.headerTitle = 'HATI',
    this.onBackFromFirst,
  });

  final List<SpinQuestion> questions;
  final List<String> options;

  /// Small label above the question text, e.g. "PAST WEEK".
  final String promptEyebrow;

  /// Label above the option list, e.g. "HOW MUCH DOES THIS DESCRIBE YOU?".
  final String instructionLine;

  /// Offset of this flow's first question within the combined progress
  /// count (0 for SPIN, 17 for GAD-7 in a 17+7 flow).
  final int startIndex;

  /// Total question count across the whole combined flow (e.g. 24).
  final int totalInFlow;

  /// Called with one score per question, in order, once the last question
  /// is answered and "Finish" is tapped.
  final void Function(List<int> scores) onComplete;

  final String headerTitle;

  /// Called when Back is tapped on this flow's first question. Defaults to
  /// popping the current route.
  final VoidCallback? onBackFromFirst;

  @override
  State<LikertAssessmentFlow> createState() => _LikertAssessmentFlowState();
}

class _LikertAssessmentFlowState extends State<LikertAssessmentFlow> {
  int _currentIndex = 0;

  static const _blue = Color(0xFF0B28D9);

  void _next() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      widget.onComplete(
        widget.questions.map((q) => q.selectedScore ?? 0).toList(),
      );
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    } else if (widget.onBackFromFirst != null) {
      widget.onBackFromFirst!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];
    final globalIndex = widget.startIndex + _currentIndex;
    final progress = (globalIndex + 1) / widget.totalInFlow;
    final hasAnswer = question.selectedScore != null;
    final isLastOfFlow = _currentIndex == widget.questions.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: _blue,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.headerTitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Question ${globalIndex + 1} of ${widget.totalInFlow}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.promptEyebrow,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black38,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${question.question}"',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.instructionLine,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Column(
                  children: List.generate(widget.options.length, (i) {
                    final selected = question.selectedScore == i;
                    final isLastOption = i == widget.options.length - 1;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: isLastOption ? 0 : 8,
                        ),
                        child: _OptionTile(
                          label: widget.options[i],
                          selected: selected,
                          onTap: () =>
                              setState(() => question.selectedScore = i),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                          ),
                          onPressed: _previous,
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              disabledBackgroundColor: _blue.withValues(
                                alpha: 0.35,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: hasAnswer ? _next : null,
                            child: Text(
                              isLastOfFlow ? 'Finish' : 'Next',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This is not a diagnostic test. Your responses are used\n'
                    'only for research and personalization.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black38,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _blue = Color(0xFF0B28D9);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _blue : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _blue : Colors.black87,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _blue : Colors.white,
                border: Border.all(
                  color: selected ? _blue : const Color(0xFFCCCCCC),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
