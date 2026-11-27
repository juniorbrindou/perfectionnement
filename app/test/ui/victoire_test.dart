import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/ui/game/celebration.dart';

void main() {
  testWidgets('victoire : confettis et feux d’artifice', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: Color(0xFF06122F),
        child: Stack(children: [Center(child: GloryRays(size: 400)), Positioned.fill(child: Celebration())]),
      ),
    ));
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
    expect(find.byType(Celebration), findsOneWidget);
    if (Platform.environment['CAPTURE'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/victoire.png'));
    }
    await tester.pumpWidget(const SizedBox());
  });
}
