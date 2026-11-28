import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/state/player.dart';
import 'package:perfectionnement/state/session.dart';
import 'package:perfectionnement/ui/adventure/adventure_screen.dart';

import 'local_match_test.dart' show loadFonts, settle;

void main() {
  testWidgets('aventure : niveaux du chapitre et panneau du niveau en cours', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    await tester.runAsync(() => Session.instance.bank());
    Player.instance.update((p) {
      p.talents = 90;
      p.adventureStars = {
        '1': ['lait', 'manne', 'solide'],
        '2': ['lait', 'manne'],
      };
    });
    await tester.pumpWidget(const MaterialApp(debugShowCheckedModeBanner: false, home: AdventureScreen()));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 900)));
    await settle(tester, frames: 10);
    expect(find.text('La Genèse'), findsOneWidget);
    expect(find.text('Niveau 3 · L\'arche de Noé'), findsOneWidget);
    expect(find.text('5 étoiles sur 24'), findsOneWidget);
    if (Platform.environment['CAPTURE'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/aventure.png'));
    }
    await tester.pump(const Duration(seconds: 3));
  });
}
