import 'package:app/features/postAssessment/data/assessment_comparison.dart';
import 'package:app/features/postAssessment/screen/post_assessment_results_screen.dart';
import 'package:app/features/postAssessment/screen/progress_update_screen.dart';
import 'package:app/features/postAssessment/screen/referral_screen.dart';
import 'package:flutter_test/flutter_test.dart';

AssessmentComparisonResult _result(InstrumentComparisonResult overall) {
  return AssessmentComparisonResult(
    spinResult: overall,
    gad7Result: overall,
    overall: overall,
  );
}

void main() {
  group('nextScreenForComparison', () {
    test('improved routes to ProgressUpdateScreen', () {
      final screen = nextScreenForComparison(
        _result(InstrumentComparisonResult.improved),
      );
      expect(screen, isA<ProgressUpdateScreen>());
    });

    test('noChange routes to ReferralScreen', () {
      final screen = nextScreenForComparison(
        _result(InstrumentComparisonResult.noChange),
      );
      expect(screen, isA<ReferralScreen>());
    });

    test('worsened routes to ReferralScreen', () {
      final screen = nextScreenForComparison(
        _result(InstrumentComparisonResult.worsened),
      );
      expect(screen, isA<ReferralScreen>());
    });
  });
}
