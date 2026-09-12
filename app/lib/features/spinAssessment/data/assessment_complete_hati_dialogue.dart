/// HATI speech for the assessment-complete screen.
abstract final class AssessmentCompleteHatiDialogue {
  AssessmentCompleteHatiDialogue._();

  static const String message =
      'Congratulations! You finished your Social Comfort Check-in. '
      'I\'m really proud of you. Whenever you\'re ready, we can explore the app together!';

  /// Shown after the user returns from reviewing their result, so Hati
  /// isn't just repeating the same opening line a second time.
  static const String afterReviewMessage =
      'Took another look at your results, huh? That\'s totally okay. '
      'Whenever you\'re ready, let\'s continue together.';
}
