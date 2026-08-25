import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/emotiondetection/themed_scenario/shared_widgets.dart';

void main() {
  testWidgets('HatiSpeakingBlock fires onSequenceComplete after intro + persistent finish',
      (tester) async {
    var completed = false;

    const introMessage =
        "You've just entered the department office. The professor is at "
        "their desk, talking to another student. They look focused, maybe "
        "a bit impatient. You need their signature on your class "
        "requirement form. You're waiting for your turn.";
    const persistentMessage =
        "You need their signature. You'll have to approach and ask if "
        "now is a good time.\n\nBefore we do anything, let's do a P.I.E.S. check.";

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HatiSpeakingBlock(
              introMessage: introMessage,
              persistentMessage: persistentMessage,
              frogSize: 180,
              onSequenceComplete: () => completed = true,
            ),
          ),
        ),
      ),
    );

    // Pump forward in chunks well past the intro's typing + 5s hold + 400ms
    // fade, then the persistent bubble's own typing + 2s-per-sentence holds.
    var elapsedSeconds = 0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
      elapsedSeconds++;
      if (completed) break;
    }

    // ignore: avoid_print
    print('onSequenceComplete fired after ~$elapsedSeconds pumped seconds');

    expect(completed, isTrue,
        reason: 'onSequenceComplete should have fired well within 60 pumped seconds');
  });
}
