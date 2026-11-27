import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/main.dart';
import 'package:perfectionnement/state/player.dart';

/// Charge les vraies polices, pour que les captures ressemblent au téléphone.
Future<void> loadFonts() async {
  for (final (family, file) in [('Lilita', 'LilitaOne-Regular.ttf'), ('Nunito', 'Nunito.ttf')]) {
    final loader = FontLoader(family)..addFont(rootBundle.load('assets/fonts/$file'));
    await loader.load();
  }
}

void main() {
  testWidgets('accueil : textes vivants et compte affichés', (tester) async {
    // Téléphone de référence : 1080 × 2340, densité 2,75.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);

    Player.instance.update((p) {
      p.username = 'juniorbrindou';
      p.xp = 180;
      p.talents = 120;
      p.breadToday = true;
      p.breadGain = 10;
      p.adventureStars = {'1': [1, 2, 3], '2': [1]};
    });

    await tester.pumpWidget(const PerfectionnementApp());
    // L'image d'accueil se décode hors du temps simulé.
    await tester.runAsync(() async {
      await Future.delayed(const Duration(seconds: 2));
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    // Fin de l'arrivée des cartes.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('juniorbrindou'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Niveau 2'), findsOneWidget);
    expect(find.text('Genèse, niveau 3/8'), findsOneWidget);
    expect(find.text('Tu as reçu 10 talents !'), findsOneWidget);

    // Capture : CAPTURE=1 flutter test test/ui --update-goldens
    if (Platform.environment['CAPTURE'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/accueil.png'));
    }
  });
}
