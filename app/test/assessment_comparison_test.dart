import 'package:app/features/postAssessment/data/assessment_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

InstrumentSnapshot _spin(int total, String severity) =>
    InstrumentSnapshot(total: total, severity: severity);

void main() {
  group('per-instrument rule (via SPIN)', () {
    test('score increased -> worsened', () {
      final result = compareAssessments(
        previousSpin: _spin(30, 'Mild'),
        currentSpin: _spin(35, 'Moderate'),
        currentGad7: _spin(0, 'Minimal'),
        previousGad7: _spin(0, 'Minimal'),
      );
      expect(result.spinResult, InstrumentComparisonResult.worsened);
    });

    test('score unchanged -> noChange', () {
      final result = compareAssessments(
        previousSpin: _spin(30, 'Mild'),
        currentSpin: _spin(30, 'Mild'),
        currentGad7: _spin(0, 'Minimal'),
        previousGad7: _spin(0, 'Minimal'),
      );
      expect(result.spinResult, InstrumentComparisonResult.noChange);
    });

    test('trivial 1-point decrease with no band change -> noChange', () {
      final result = compareAssessments(
        previousSpin: _spin(35, 'Moderate'),
        currentSpin: _spin(34, 'Moderate'),
        currentGad7: _spin(0, 'Minimal'),
        previousGad7: _spin(0, 'Minimal'),
      );
      expect(result.spinResult, InstrumentComparisonResult.noChange);
    });

    test('2+ point decrease with no band change -> improved', () {
      final result = compareAssessments(
        previousSpin: _spin(35, 'Moderate'),
        currentSpin: _spin(33, 'Moderate'),
        currentGad7: _spin(0, 'Minimal'),
        previousGad7: _spin(0, 'Minimal'),
      );
      expect(result.spinResult, InstrumentComparisonResult.improved);
    });

    test('1-point decrease that still crosses a severity band -> improved', () {
      final result = compareAssessments(
        previousSpin: _spin(41, 'Severe'),
        currentSpin: _spin(40, 'Moderate'),
        currentGad7: _spin(0, 'Minimal'),
        previousGad7: _spin(0, 'Minimal'),
      );
      expect(result.spinResult, InstrumentComparisonResult.improved);
    });

    test('large decrease that crosses several bands -> improved', () {
      final result = compareAssessments(
        previousSpin: _spin(55, 'Very Severe'),
        currentSpin: _spin(25, 'Mild'),
        currentGad7: _spin(0, 'Minimal'),
        previousGad7: _spin(0, 'Minimal'),
      );
      expect(result.spinResult, InstrumentComparisonResult.improved);
    });
  });

  group('GAD-7 elevated threshold (isGad7Elevated / gad7Elevated)', () {
    test('9 (Mild) is not elevated', () {
      expect(isGad7Elevated(9), isFalse);
    });

    test('10 (Moderate) is elevated', () {
      expect(isGad7Elevated(10), isTrue);
    });

    test('21 (Severe) is elevated', () {
      expect(isGad7Elevated(21), isTrue);
    });

    test('judged on the current score alone, ignoring any GAD-7 trend', () {
      // GAD-7 dropped a lot (20 -> 12) but 12 is still >= 10.
      final result = compareAssessments(
        previousSpin: _spin(30, 'Mild'),
        currentSpin: _spin(20, 'None'),
        currentGad7: _spin(12, 'Moderate'),
        previousGad7: _spin(20, 'Severe'),
      );
      expect(result.gad7Result, InstrumentComparisonResult.improved);
      expect(result.gad7Elevated, isTrue);
    });
  });

  group('SPIN still-significant threshold (isSpinStillSignificant)', () {
    test('Moderate is not significant', () {
      expect(isSpinStillSignificant('Moderate'), isFalse);
    });

    test('Severe is significant', () {
      expect(isSpinStillSignificant('Severe'), isTrue);
    });

    test('Very Severe is significant', () {
      expect(isSpinStillSignificant('Very Severe'), isTrue);
    });
  });

  group('post-assessment category table', () {
    test('1.1 improved, not elevated, no longer significant', () {
      final result = compareAssessments(
        previousSpin: _spin(55, 'Very Severe'),
        currentSpin: _spin(25, 'Mild'),
        currentGad7: _spin(3, 'Minimal'),
        previousGad7: _spin(3, 'Minimal'),
      );
      expect(result.category, PostAssessmentCategory.improvedNoConcerns);
      expect(result.isReferral, isFalse);
      expect(result.routedTo, 'progress');
    });

    test(
      '1.2 improved, not elevated, but still significant (very severe -> severe)',
      () {
        final result = compareAssessments(
          previousSpin: _spin(55, 'Very Severe'),
          currentSpin: _spin(45, 'Severe'),
          currentGad7: _spin(3, 'Minimal'),
          previousGad7: _spin(3, 'Minimal'),
        );
        expect(
          result.category,
          PostAssessmentCategory.improvedStillSignificant,
        );
        expect(result.isReferral, isFalse);
        expect(result.routedTo, 'progress');
      },
    );

    test('2 improved SPIN, but GAD-7 elevated', () {
      final result = compareAssessments(
        previousSpin: _spin(55, 'Very Severe'),
        currentSpin: _spin(25, 'Mild'),
        currentGad7: _spin(12, 'Moderate'),
        previousGad7: _spin(3, 'Minimal'),
      );
      expect(result.category, PostAssessmentCategory.improvedGad7Elevated);
      expect(result.isReferral, isTrue);
      expect(result.routedTo, 'referral');
    });

    test('3 no significant SPIN change, not elevated', () {
      final result = compareAssessments(
        previousSpin: _spin(35, 'Moderate'),
        currentSpin: _spin(34, 'Moderate'),
        currentGad7: _spin(3, 'Minimal'),
        previousGad7: _spin(3, 'Minimal'),
      );
      expect(result.category, PostAssessmentCategory.noChangeNotElevated);
      expect(result.isReferral, isFalse);
      expect(result.routedTo, 'progress');
    });

    test('4 no significant SPIN change + GAD-7 elevated', () {
      final result = compareAssessments(
        previousSpin: _spin(35, 'Moderate'),
        currentSpin: _spin(34, 'Moderate'),
        currentGad7: _spin(15, 'Severe'),
        previousGad7: _spin(3, 'Minimal'),
      );
      expect(result.category, PostAssessmentCategory.noChangeGad7Elevated);
      expect(result.isReferral, isTrue);
      expect(result.routedTo, 'referral');
    });

    test('5 SPIN worsened, not elevated', () {
      final result = compareAssessments(
        previousSpin: _spin(20, 'None'),
        currentSpin: _spin(35, 'Moderate'),
        currentGad7: _spin(3, 'Minimal'),
        previousGad7: _spin(3, 'Minimal'),
      );
      expect(result.category, PostAssessmentCategory.worsenedNotElevated);
      expect(result.isReferral, isTrue);
      expect(result.routedTo, 'referral');
    });

    test('6 SPIN worsened + GAD-7 elevated', () {
      final result = compareAssessments(
        previousSpin: _spin(20, 'None'),
        currentSpin: _spin(35, 'Moderate'),
        currentGad7: _spin(18, 'Severe'),
        previousGad7: _spin(3, 'Minimal'),
      );
      expect(result.category, PostAssessmentCategory.worsenedGad7Elevated);
      expect(result.isReferral, isTrue);
      expect(result.routedTo, 'referral');
    });
  });

  group('missing GAD-7 baseline (first-ever reassessment)', () {
    test('no previous GAD-7 -> gad7Result (chart-only) is noChange', () {
      final result = compareAssessments(
        previousSpin: _spin(41, 'Severe'),
        currentSpin: _spin(30, 'Mild'),
        currentGad7: _spin(2, 'Minimal'),
        previousGad7: null,
      );
      expect(result.gad7Result, InstrumentComparisonResult.noChange);
    });

    test(
      'missing GAD-7 baseline does not affect gad7Elevated, which only '
      'needs the current score',
      () {
        final result = compareAssessments(
          previousSpin: _spin(41, 'Severe'),
          currentSpin: _spin(30, 'Mild'),
          currentGad7: _spin(14, 'Moderate'),
          previousGad7: null,
        );
        expect(result.gad7Elevated, isTrue);
        expect(result.category, PostAssessmentCategory.improvedGad7Elevated);
      },
    );

    test('missing GAD-7 baseline cannot mask a worsened SPIN result', () {
      final result = compareAssessments(
        previousSpin: _spin(20, 'None'),
        currentSpin: _spin(35, 'Moderate'),
        currentGad7: _spin(2, 'Minimal'),
        previousGad7: null,
      );
      expect(result.spinResult, InstrumentComparisonResult.worsened);
      expect(result.category, PostAssessmentCategory.worsenedNotElevated);
      expect(result.isReferral, isTrue);
    });
  });
}
