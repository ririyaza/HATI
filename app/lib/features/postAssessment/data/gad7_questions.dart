import '../../spinAssessment/models/spin_question_model.dart';

/// The standard 7-item GAD-7. Reuses [SpinQuestion] (just `{question,
/// selectedScore}`) since there's nothing SPIN-specific about that model.
///
/// TODO(jaspher): `theme` is a SPIN category and GAD-7 isn't theme-based —
/// left empty here as a placeholder so this compiles (SpinQuestion.theme is
/// required). Confirm nothing downstream reads .theme for GAD-7 items
/// specifically before relying on this.
List<SpinQuestion> buildGad7Questions() => [
  SpinQuestion(question: 'Feeling nervous, anxious, or on edge', theme: ''),
  SpinQuestion(
    question: 'Not being able to stop or control worrying',
    theme: '',
  ),
  SpinQuestion(
    question: 'Worrying too much about different things',
    theme: '',
  ),
  SpinQuestion(question: 'Trouble relaxing', theme: ''),
  SpinQuestion(
    question: "Being so restless that it's hard to sit still",
    theme: '',
  ),
  SpinQuestion(question: 'Becoming easily annoyed or irritable', theme: ''),
  SpinQuestion(
    question: 'Feeling afraid as if something awful might happen',
    theme: '',
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
