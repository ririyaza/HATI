import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/emotiondetection/themed_scenario/shared_widgets.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 500,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('shows the scroll-down hint when the body overflows the viewport',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        HatiSceneShell(
          showCoach: false,
          body: Column(
            children: List.generate(
              20,
              (i) => Container(
                height: 60,
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.grey.shade200,
                child: Text('Option $i'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(); // let the post-frame callback run
    await tester.pump();

    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget,
        reason: 'Hint should appear when there is more content below the fold');

    // Scroll all the way to the bottom.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -5000));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing,
        reason: 'Hint should disappear once scrolled to the bottom');
  });

  testWidgets('does not show the hint when the body already fits with no scrolling',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        HatiSceneShell(
          showCoach: false,
          body: const Text('Just one short option'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing,
        reason: 'Short content that already fits should never show the hint');
  });
}
