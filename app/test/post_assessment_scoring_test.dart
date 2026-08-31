import 'package:app/features/postAssessment/data/post_assessment_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('spinSeverity', () {
    test('bottom of the range', () {
      expect(spinSeverity(0), 'None');
    });

    test('None/Mild boundary — 20 is None, 21 is Mild', () {
      expect(spinSeverity(20), 'None');
      expect(spinSeverity(21), 'Mild');
    });

    test('Mild/Moderate boundary — 30 is Mild, 31 is Moderate', () {
      expect(spinSeverity(30), 'Mild');
      expect(spinSeverity(31), 'Moderate');
    });

    test('Moderate/Severe boundary — 40 is Moderate, 41 is Severe', () {
      expect(spinSeverity(40), 'Moderate');
      expect(spinSeverity(41), 'Severe');
    });

    test('Severe/Very Severe boundary — 50 is Severe, 51 is Very Severe', () {
      expect(spinSeverity(50), 'Severe');
      expect(spinSeverity(51), 'Very Severe');
    });

    test('top of the range', () {
      expect(spinSeverity(68), 'Very Severe');
    });
  });

  group('gad7Severity', () {
    test('bottom of the range', () {
      expect(gad7Severity(0), 'Minimal');
    });

    test('Minimal/Mild boundary — 4 is Minimal, 5 is Mild', () {
      expect(gad7Severity(4), 'Minimal');
      expect(gad7Severity(5), 'Mild');
    });

    test('Mild/Moderate boundary — 9 is Mild, 10 is Moderate', () {
      expect(gad7Severity(9), 'Mild');
      expect(gad7Severity(10), 'Moderate');
    });

    test('Moderate/Severe boundary — 14 is Moderate, 15 is Severe', () {
      expect(gad7Severity(14), 'Moderate');
      expect(gad7Severity(15), 'Severe');
    });

    test('top of the range', () {
      expect(gad7Severity(21), 'Severe');
    });
  });

  group('severity improvement ordering', () {
    test('SPIN: Severe -> Moderate is an improvement', () {
      expect(spinSeverityImproved('Severe', 'Moderate'), isTrue);
    });

    test('SPIN: same band is not an improvement', () {
      expect(spinSeverityImproved('Moderate', 'Moderate'), isFalse);
    });

    test('SPIN: Moderate -> Severe is not an improvement', () {
      expect(spinSeverityImproved('Moderate', 'Severe'), isFalse);
    });

    test('GAD-7: Moderate -> Mild is an improvement', () {
      expect(gad7SeverityImproved('Moderate', 'Mild'), isTrue);
    });

    test('GAD-7: Mild -> Moderate is not an improvement', () {
      expect(gad7SeverityImproved('Mild', 'Moderate'), isFalse);
    });
  });
}
