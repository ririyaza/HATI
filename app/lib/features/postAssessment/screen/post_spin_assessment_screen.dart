import 'package:flutter/material.dart';

import '../data/post_assessment_spin_questions.dart';
import '../widgets/likert_assessment_flow.dart';
import 'post_gad7_intro_screen.dart';

/// SPIN-17 portion of the reassessment flow (questions 1–17 of 24).
///
/// Named `Post*` (not `SpinAssessmentScreen`) to avoid colliding with the
/// pre-test's existing `spinAssessment/screen/spin_assessment_screen.dart`
/// class of that exact name.
class PostSpinAssessmentScreen extends StatelessWidget {
  const PostSpinAssessmentScreen({super.key});

  static const _totalInFlow = 24;

  @override
  Widget build(BuildContext context) {
    final questions = buildPostAssessmentSpinQuestions();

    return LikertAssessmentFlow(
      questions: questions,
      options: spinOptions,
      promptSentence: spinPrompt,
      instructionLine: 'HOW MUCH DOES THIS DESCRIBE YOU?',
      startIndex: 0,
      totalInFlow: _totalInFlow,
      onComplete: (scores) {
        final spinTotal = scores.fold(0, (sum, s) => sum + s);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PostGad7IntroScreen(spinTotal: spinTotal),
          ),
        );
      },
    );
  }
}
