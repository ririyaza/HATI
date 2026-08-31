import '../../spinAssessment/data/spin_questions.dart' as pretest;
import '../../spinAssessment/models/spin_question_model.dart';

/// Fresh copies of the same 17 SPIN items used at onboarding, for the
/// reassessment flow.
///
/// Deliberately NOT reusing `spinQuestions` from the pre-test directly: that
/// list is a single shared mutable global (each [SpinQuestion.selectedScore]
/// is written in place), so answering it here would corrupt the onboarding
/// screen's in-progress state and vice versa. A fresh, per-flow copy avoids
/// that entirely.
List<SpinQuestion> buildPostAssessmentSpinQuestions() => pretest.spinQuestions
    .map((q) => SpinQuestion(question: q.question, theme: q.theme))
    .toList();

const spinOptions = [
  'Not at all',
  'A little bit',
  'Somewhat',
  'Very much',
  'Extremely',
];

const spinPromptEyebrow = 'PAST WEEK';
