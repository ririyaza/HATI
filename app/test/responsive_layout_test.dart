import 'dart:io';

import 'package:app/features/auth/screen/login_screen.dart';
import 'package:app/features/auth/screen/signup_screen.dart';
import 'package:app/features/postAssessment/screen/post_assessment_intro_screen.dart';
import 'package:app/features/postAssessment/screen/post_gad7_intro_screen.dart';
import 'package:app/features/postAssessment/widgets/likert_assessment_flow.dart';
import 'package:app/features/spinAssessment/models/spin_question_model.dart';
import 'package:app/features/spinAssessment/screen/spin_assessment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Flutter tests render every glyph as a full-em square (the "Ahem" font),
// which exaggerates horizontal overflow ~2x versus a real device. Loading the
// SDK's Roboto — the actual Android default — makes widths realistic.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/src/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final file in const [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]) {
    final bytes = await File('$dir/$file').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

const _sizes = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'phone 360x640': Size(360, 640),
  'tall phone 411x891': Size(411, 891),
  'tablet 800x1280': Size(800, 1280),
};
const _textScales = [1.0, 1.5, 2.0];

Future<void> _pumpAt(
  WidgetTester tester,
  Widget screen,
  Size size,
  double textScale,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void _overflowSuite(
  String name,
  Widget Function() build, {
  Future<void> Function(WidgetTester)? afterPump,
}) {
  group(name, () {
    for (final entry in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets('${entry.key} @ ${scale}x text', (tester) async {
          // Capture full details (incl. the overflowing widget's creator
          // chain), which takeException() alone drops.
          final reported = <FlutterErrorDetails>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            reported.add(details);
            previous?.call(details);
          };

          await _pumpAt(tester, build(), entry.value, scale);
          if (afterPump != null) {
            await afterPump(tester);
            await tester.pump(const Duration(milliseconds: 300));
          }
          FlutterError.onError = previous;
          tester.takeException();
          if (reported.isNotEmpty) {
            fail(reported.map((d) => d.toString()).join('\n---\n'));
          }
        });
      }
    }
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Hati's sound effects talk to the audioplayers plugin, which has no
    // implementation under flutter test.
    for (final channel in const [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    await _loadRoboto();
  });

  _overflowSuite(
    'SPIN assessment intro',
    () => const SpinAssessmentScreen(isRetake: true),
  );
  _overflowSuite(
    'SPIN assessment question',
    () => const SpinAssessmentScreen(isRetake: true),
    afterPump: (tester) async {
      await tester.ensureVisible(find.text('Begin Check-in'));
      await tester.pump();
      await tester.tap(find.text('Begin Check-in'));
    },
  );

  _overflowSuite(
    'Post-assessment intro',
    () => const PostAssessmentIntroScreen(),
  );
  _overflowSuite(
    'Post GAD-7 intro',
    () => const PostGad7IntroScreen(spinTotal: 20),
  );
  _overflowSuite(
    'Likert flow',
    () => LikertAssessmentFlow(
      questions: [
        SpinQuestion(
          question:
              'I avoid speaking up in meetings or group discussions even '
              'when I have something useful to add',
          theme: 'x',
        ),
      ],
      options: const [
        'Not at all',
        'A little bit',
        'Somewhat',
        'Very much',
        'Extremely',
      ],
      promptSentence:
          'Over the past week, how much did this statement describe you?',
      startIndex: 0,
      totalInFlow: 24,
      onComplete: (_) {},
    ),
  );
  _overflowSuite('Login', () => const LoginScreen());
  _overflowSuite('Signup', () => const SignupScreen());

  // ConsentIntroScreen (Rive mascot) isn't covered here: Rive's native library
  // can't load under `flutter test`, which fails whichever case runs first.
  // Its layout was verified with this same harness, minus that first case.
}
