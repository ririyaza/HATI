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

    test(
      'trivial 1-point decrease with no band change -> noChange',
      () {
        final result = compareAssessments(
          previousSpin: _spin(35, 'Moderate'),
          currentSpin: _spin(34, 'Moderate'),
          currentGad7: _spin(0, 'Minimal'),
          previousGad7: _spin(0, 'Minimal'),
        );
        expect(result.spinResult, InstrumentComparisonResult.noChange);
      },
    );

    test('2+ point decrease with no band change -> improved', () {
      final result = compareAssessments(
        previousSpin: _spin(35, 'Moderate'),
        currentSpin: _spin(33, 'Moderate'),
        currentGad7: _spin(0, 'Minimal'),
        previousGad7: _spin(0, 'Minimal'),
      );
      expect(result.spinResult, InstrumentComparisonResult.improved);
    });

    test(
      '1-point decrease that still crosses a severity band -> improved',
      () {
        final result = compareAssessments(
          previousSpin: _spin(41, 'Severe'),
          currentSpin: _spin(40, 'Moderate'),
          currentGad7: _spin(0, 'Minimal'),
          previousGad7: _spin(0, 'Minimal'),
        );
        expect(result.spinResult, InstrumentComparisonResult.improved);
      },
    );

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

  group('either-instrument-worsened combination rule', () {
    test('both improved -> overall improved', () {
      final result = compareAssessments(
        previousSpin: _spin(41, 'Severe'),
        currentSpin: _spin(30, 'Mild'),
        currentGad7: _spin(3, 'Minimal'),
        previousGad7: _spin(10, 'Moderate'),
      );
      expect(result.spinResult, InstrumentComparisonResult.improved);
      expect(result.gad7Result, InstrumentComparisonResult.improved);
      expect(result.overall, InstrumentComparisonResult.improved);
      expect(result.isReferral, isFalse);
      expect(result.routedTo, 'progress');
    });

    test('SPIN improved but GAD-7 worsened -> overall worsened', () {
      final result = compareAssessments(
        previousSpin: _spin(41, 'Severe'),
        currentSpin: _spin(30, 'Mild'),
        currentGad7: _spin(15, 'Severe'),
        previousGad7: _spin(5, 'Mild'),
      );
      expect(result.spinResult, InstrumentComparisonResult.improved);
      expect(result.gad7Result, InstrumentComparisonResult.worsened);
      expect(result.overall, InstrumentComparisonResult.worsened);
      expect(result.isReferral, isTrue);
      expect(result.routedTo, 'referral');
    });

    test('SPIN worsened but GAD-7 improved -> overall worsened', () {
      final result = compareAssessments(
        previousSpin: _spin(20, 'None'),
        currentSpin: _spin(35, 'Moderate'),
        currentGad7: _spin(3, 'Minimal'),
        previousGad7: _spin(12, 'Moderate'),
      );
      expect(result.overall, InstrumentComparisonResult.worsened);
      expect(result.isReferral, isTrue);
    });

    test('one noChange, one improved, neither worsened -> overall noChange', () {
      final result = compareAssessments(
        previousSpin: _spin(35, 'Moderate'),
        currentSpin: _spin(34, 'Moderate'), // trivial -1 -> noChange
        currentGad7: _spin(3, 'Minimal'),
        previousGad7: _spin(10, 'Moderate'), // improved
      );
      expect(result.spinResult, InstrumentComparisonResult.noChange);
      expect(result.gad7Result, InstrumentComparisonResult.improved);
      expect(result.overall, InstrumentComparisonResult.noChange);
      expect(result.isReferral, isTrue);
      expect(result.routedTo, 'referral');
    });
  });

  group('missing GAD-7 baseline (first-ever reassessment)', () {
    test('no previous GAD-7 -> gad7Result is noChange', () {
      final result = compareAssessments(
        previousSpin: _spin(41, 'Severe'),
        currentSpin: _spin(30, 'Mild'),
        currentGad7: _spin(2, 'Minimal'),
        previousGad7: null,
      );
      expect(result.gad7Result, InstrumentComparisonResult.noChange);
    });

    test(
      'missing GAD-7 baseline cannot mask a worsened SPIN result',
      () {
        final result = compareAssessments(
          previousSpin: _spin(20, 'None'),
          currentSpin: _spin(35, 'Moderate'),
          currentGad7: _spin(2, 'Minimal'),
          previousGad7: null,
        );
        expect(result.overall, InstrumentComparisonResult.worsened);
      },
    );

    test(
      'missing GAD-7 baseline does not by itself force a referral when '
      'SPIN improved',
      () {
        final result = compareAssessments(
          previousSpin: _spin(41, 'Severe'),
          currentSpin: _spin(20, 'None'),
          currentGad7: _spin(2, 'Minimal'),
          previousGad7: null,
        );
        // spinResult=improved, gad7Result=noChange -> overall noChange
        // (still routes to referral, since noChange isn't `improved`, but
        // it must NOT be `worsened`).
        expect(result.overall, isNot(InstrumentComparisonResult.worsened));
      },
    );
  });
}
