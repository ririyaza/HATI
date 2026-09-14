import 'package:app/features/postAssessment/data/assessment_comparison.dart';
import 'package:app/features/postAssessment/screen/post_assessment_results_screen.dart';
import 'package:app/features/postAssessment/screen/progress_update_screen.dart';
import 'package:app/features/postAssessment/screen/referral_screen.dart';
import 'package:flutter_test/flutter_test.dart';

AssessmentComparisonResult _result(PostAssessmentCategory category) {
  return AssessmentComparisonResult(
    spinResult: InstrumentComparisonResult.noChange,
    gad7Result: InstrumentComparisonResult.noChange,
    gad7Elevated: false,
    spinStillSignificant: false,
    category: category,
  );
}

void main() {
  group('nextScreenForComparison', () {
    test('1.1 improvedNoConcerns routes to ProgressUpdateScreen', () {
      final screen = nextScreenForComparison(
        _result(PostAssessmentCategory.improvedNoConcerns),
      );
      expect(screen, isA<ProgressUpdateScreen>());
    });

    test('1.2 improvedStillSignificant routes to ProgressUpdateScreen', () {
      final screen = nextScreenForComparison(
        _result(PostAssessmentCategory.improvedStillSignificant),
      );
      expect(screen, isA<ProgressUpdateScreen>());
    });

    test('2 improvedGad7Elevated routes to ReferralScreen', () {
      final screen = nextScreenForComparison(
        _result(PostAssessmentCategory.improvedGad7Elevated),
      );
      expect(screen, isA<ReferralScreen>());
    });

    test('3 noChangeNotElevated routes to ProgressUpdateScreen', () {
      final screen = nextScreenForComparison(
        _result(PostAssessmentCategory.noChangeNotElevated),
      );
      expect(screen, isA<ProgressUpdateScreen>());
    });

    test('4 noChangeGad7Elevated routes to ReferralScreen', () {
      final screen = nextScreenForComparison(
        _result(PostAssessmentCategory.noChangeGad7Elevated),
      );
      expect(screen, isA<ReferralScreen>());
    });

    test('5 worsenedNotElevated routes to ReferralScreen', () {
      final screen = nextScreenForComparison(
        _result(PostAssessmentCategory.worsenedNotElevated),
      );
      expect(screen, isA<ReferralScreen>());
    });

    test('6 worsenedGad7Elevated routes to ReferralScreen', () {
      final screen = nextScreenForComparison(
        _result(PostAssessmentCategory.worsenedGad7Elevated),
      );
      expect(screen, isA<ReferralScreen>());
    });
  });
}
