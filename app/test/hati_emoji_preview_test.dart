import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preview Hati emoji pngs', (tester) async {
    const assets = [
      'assets/Hati_emojis/hati_anxious.png',
      'assets/Hati_emojis/hati_happy.png',
      'assets/Hati_emojis/hati_neutral.png',
      'assets/Hati_emojis/hati_sad.png',
      'assets/Hati_emojis/hati_mad.png',
      'assets/Hati_emojis/hati_disgust.png',
      'assets/Hati_emojis/hati_surprised.png',
    ];

    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B28D9),
          body: RepaintBoundary(
            key: key,
            child: Wrap(
              children: [
                for (final asset in assets)
                  Container(
                    width: 140,
                    height: 140,
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4C2E8F),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(asset),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/hati_emoji_preview.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(byteData!.buffer.asUint8List());
  });
}
