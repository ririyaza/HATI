/// HATI speech for the low-score exit screen.
abstract final class LowScoreExitHatiDialogue {
  LowScoreExitHatiDialogue._();

  static const String message =
      'Based on your results, HATI may not be the right fit for you right now. '
      'Thank you for being honest with me. '
      'You can review your results below.';

  /// Shown after the user returns from reviewing their result, so Hati
  /// isn't just repeating the same opening line a second time.
  static const String afterReviewMessage =
      'Thanks for taking another look. Whatever you decide from here, '
      'I hope things go well for you.';
}
