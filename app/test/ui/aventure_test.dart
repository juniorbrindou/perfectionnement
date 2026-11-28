import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/state/player.dart';
import 'package:perfectionnement/state/session.dart';
import 'package:perfectionnement/ui/adventure/adventure_screen.dart';

import 'local_match_test.dart' show loadFonts, settle;

/// Les icônes Material, pour que les captures les montrent (le SDK les garde dans son cache).
Future<void> loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final file = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

Future<void> open(WidgetTester tester, Map<String, List> stars) async {
  // Un fichier lu par un test précédent resterait attendu dans son horloge simulée.
  rootBundle.clear();
  await tester.runAsync(loadFonts);
  await tester.runAsync(loadIcons);
  // Comme main() : seules les illustrations sont chargées. L'écran ne doit rien attendre d'autre.
  await tester.runAsync(() => Session.instance.loadIllustrations());
  Player.instance.update((p) {
    p.talents = 90;
    p.adventureStars = stars;
  });
  await tester.pumpWidget(const MaterialApp(debugShowCheckedModeBanner: false, home: AdventureScreen()));
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 900)));
  await settle(tester, frames: 10);
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['CAPTURE'] == '1') {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/$name.png'));
  }
}

void main() {
  testWidgets('aventure : niveaux du chapitre et panneau du niveau en cours', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await open(tester, {
      '1': ['lait', 'manne', 'solide'],
      '2': ['lait', 'manne'],
    });
    expect(find.text('La Genèse'), findsOneWidget);
    expect(find.text('Niveau 3 · L\'arche de Noé'), findsOneWidget);
    expect(find.text('5 étoiles sur 24'), findsOneWidget);
    expect(find.text('bientôt'), findsNothing);
    expect(Session.instance.illustration(const ['Genèse']), isNotNull);
    await capture(tester, 'aventure');

    // Choisir un niveau ouvert : la première difficulté pas encore gagnée est proposée.
    await tester.tap(find.text('Le jardin d\'Éden'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Niveau 2 · Le jardin d\'Éden'), findsOneWidget);
    expect(find.text('★ gagnée'), findsNWidgets(2));
    await capture(tester, 'aventure_niveau_2');

    // Un niveau fermé ne se choisit pas.
    await tester.tap(find.text('Abraham'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Niveau 2 · Le jardin d\'Éden'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  // Petits téléphones (360 de large), barres Android en haut et en bas, texte normal puis agrandi.
  for (final (height, scale) in [(740, 1.0), (740, 1.3), (640, 1.0)]) {
    testWidgets('aventure 360 × $height, texte × $scale : tout tient sans défiler', (tester) async {
      tester.view.physicalSize = Size(1080, height * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 84, bottom: 144);
      tester.view.viewPadding = const FakeViewPadding(top: 84, bottom: 144);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await open(tester, {});
      expect(tester.takeException(), isNull);
      expect(find.text('0 étoile sur 24'), findsOneWidget);

      // Rien à faire défiler.
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.maxScrollExtent, 0);
      // Aucun nom de niveau tronqué, et aucun cadenas sur un nom.
      final names = [
        'La création', 'Le jardin d\'Éden', 'L\'arche de Noé', 'La tour de Babel', //
        'Abraham', 'Isaac et Rébecca', 'Jacob', 'Joseph',
      ];
      final locks = find.byIcon(Icons.lock_rounded);
      expect(locks, findsNWidgets(7));
      for (final name in names) {
        expect(tester.renderObject<RenderParagraph>(find.text(name)).didExceedMaxLines, isFalse, reason: name);
        for (var i = 0; i < 7; i++) {
          expect(tester.getRect(find.text(name)).overlaps(tester.getRect(locks.at(i))), isFalse, reason: name);
        }
      }
      // Le bouton reste au-dessus de la barre de navigation.
      expect(tester.getRect(find.text('Jouer')).bottom, lessThan(height - 48));
      await capture(tester, 'aventure_360x${height}_${(scale * 100).round()}');
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
