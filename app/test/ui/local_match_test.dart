import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/ui/game/card_face.dart';
import 'package:perfectionnement/ui/game/local_match_screen.dart';
import 'package:perfectionnement/ui/game/table.dart';

Future<void> loadFonts() async {
  for (final (family, file) in [
    ('Lilita', 'LilitaOne-Regular.ttf'),
    ('Nunito', 'Nunito.ttf'),
    ('Garamond', 'EBGaramond.ttf'),
  ]) {
    final loader = FontLoader(family)..addFont(rootBundle.load('assets/fonts/$file'));
    await loader.load();
  }
}

final capture = Platform.environment['CAPTURE'] == '1';

/// Décode les images à l'écran (hors du temps simulé), puis avance un peu.
Future<void> settle(WidgetTester tester, {int frames = 6}) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  if (capture) await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/$name.png'));
}

void main() {
  testWidgets('partie à deux : départ, carte posée, réponse', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);

    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: LocalMatchScreen(rng: Random(3))));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await settle(tester);

    // Question de départ : deux moitiés, cinq propositions chacune.
    expect(find.byType(AnswerPill), findsNWidgets(10));
    await shot(tester, 'partie_depart');
    await tester.tap(find.byType(AnswerPill).last);
    await tester.pump(const Duration(milliseconds: 2300));

    // Passage du téléphone.
    expect(find.textContaining('Passe le téléphone'), findsOneWidget);
    await settle(tester);
    await shot(tester, 'partie_passe');
    await tester.tap(find.textContaining('Je suis'));
    await settle(tester);

    // Ton tour : la main ouverte, rien de choisi.
    expect(find.text('Poser cette carte'), findsOneWidget);
    expect(find.byType(HandFan), findsOneWidget);
    final hand = find.descendant(of: find.byType(HandFan), matching: find.byType(CardFace));
    expect(hand, findsNWidgets(5));
    await tester.tap(hand.at(2));
    await settle(tester);
    // La carte touchée s'affiche en grand, avec la bonne réponse marquée.
    expect(find.byType(CardFace), findsNWidgets(6));
    await shot(tester, 'partie_choix');

    await tester.tap(find.text('Poser cette carte'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('Je suis'));
    await settle(tester);

    // L'autre répond : la carte au centre, sans livre ni illustration.
    expect(find.text('Touche la bonne réponse'), findsOneWidget);
    await shot(tester, 'partie_reponse');
    final pills = find.descendant(of: find.byType(CardFace).first, matching: find.byType(AnswerPill));
    expect(pills, findsNWidgets(4));
    await tester.tap(pills.first);
    await tester.pump(const Duration(milliseconds: 900));
    await settle(tester, frames: 8);
    expect(find.textContaining('Continuer'), findsOneWidget);
    await shot(tester, 'partie_resultat');
    await tester.pump(const Duration(seconds: 3));
  });
}
