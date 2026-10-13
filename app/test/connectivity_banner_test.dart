import 'package:app/shared/offline/connectivity_banner.dart';
import 'package:app/shared/offline/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final connectivity = ConnectivityService.instance;

  tearDown(() => connectivity.setOnlineForTesting(true));

  Widget app() => MaterialApp(
    builder: (context, child) => ConnectivityBanner(child: child!),
    home: const _Counter(),
  );

  testWidgets('shows offline strip, confirms reconnection, then hides', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.textContaining("You're offline"), findsNothing);

    connectivity.setOnlineForTesting(false);
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsOneWidget);

    connectivity.setOnlineForTesting(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Back online'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Back online'), findsNothing);
  });

  testWidgets('toggling the strip keeps the screen state underneath', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('taps: 1'), findsOneWidget);

    connectivity.setOnlineForTesting(false);
    await tester.pumpAndSettle();
    expect(find.text('taps: 1'), findsOneWidget);

    connectivity.setOnlineForTesting(true);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('taps: 1'), findsOneWidget);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => setState(() => _taps++),
        child: Text('taps: $_taps'),
      ),
    ),
  );
}
