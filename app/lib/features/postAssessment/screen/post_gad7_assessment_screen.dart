import 'package:flutter/material.dart';

import '../data/gad7_questions.dart';
import '../widgets/likert_assessment_flow.dart';
import 'post_assessment_results_screen.dart';

/// GAD-7 portion of the reassessment flow (questions 18–24 of 24),
/// continuing straight on from [PostSpinAssessmentScreen].
class PostGad7AssessmentScreen extends StatelessWidget {
  const PostGad7AssessmentScreen({super.key, required this.spinTotal});

  final int spinTotal;

  static const _totalInFlow = 24;
  static const _spinQuestionCount = 17;

  @override
  Widget build(BuildContext context) {
    final questions = buildGad7Questions();

    return LikertAssessmentFlow(
      questions: questions,
      options: gad7Options,
      promptEyebrow: gad7PromptEyebrow,
      instructionLine: 'HOW OFTEN HAS THIS BOTHERED YOU?',
      startIndex: _spinQuestionCount,
      totalInFlow: _totalInFlow,
      onBackFromFirst: () => Navigator.pop(context),
      onComplete: (scores) {
        final gad7Total = scores.fold(0, (sum, s) => sum + s);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PostAssessmentResultsScreen(
              spinTotal: spinTotal,
              gad7Total: gad7Total,
            ),
          ),
        );
      },
    );
  }
}
