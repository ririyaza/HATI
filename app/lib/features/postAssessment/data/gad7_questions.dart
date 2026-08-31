import '../../spinAssessment/models/spin_question_model.dart';

/// The standard 7-item GAD-7. Reuses [SpinQuestion] (just `{question,
/// selectedScore}`) since there's nothing SPIN-specific about that model.
List<SpinQuestion> buildGad7Questions() => [
  SpinQuestion(question: 'Feeling nervous, anxious, or on edge'),
  SpinQuestion(question: 'Not being able to stop or control worrying'),
  SpinQuestion(question: 'Worrying too much about different things'),
  SpinQuestion(question: 'Trouble relaxing'),
  SpinQuestion(question: "Being so restless that it's hard to sit still"),
  SpinQuestion(question: 'Becoming easily annoyed or irritable'),
  SpinQuestion(
    question: 'Feeling afraid as if something awful might happen',
  ),
];

const gad7Options = [
  'Not at all',
  'Several days',
  'More than half the days',
  'Nearly every day',
];

const gad7PromptEyebrow = 'PAST 2 WEEKS';
const gad7Prompt =
    'Over the last two weeks, how often have you been bothered by the '
    'following problems?';
