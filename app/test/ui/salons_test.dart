import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/state/salons.dart';
import 'package:perfectionnement/ui/salons/salon_create_screen.dart';
import 'package:perfectionnement/ui/salons/salon_page.dart';
import 'package:perfectionnement/ui/salons/salons_screen.dart';

import 'local_match_test.dart' show loadFonts;

final capture = Platform.environment['CAPTURE'] == '1';

Future<void> show(WidgetTester tester, Widget screen, String name) async {
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: screen));
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 800)));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (capture) await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/$name.png'));
  await tester.pump(const Duration(seconds: 3)); // fin des messages éphémères
}

void main() {
  test('initiale d’un salon sans son article', () {
    expect(salonInitial('Les Psalmistes'), 'P');
    expect(salonInitial('L’Arche'), 'A');
    expect(salonInitial('Lesbos'), 'L');
    expect(salonInitial('Bérée'), 'B');
    expect(salonInitial('Les'), 'L');
  });

  testWidgets('salons : liste, fiche et création s’affichent hors ligne', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);

    await show(tester, const SalonsScreen(), 'salons_liste');
    expect(find.text('Les salons'), findsOneWidget);

    const preview = SalonInfo(
      id: 's1',
      name: 'Les Psalmistes',
      motto: 'Que tout ce qui respire loue l’Éternel !',
      theme: 'paturages',
      difficulty: 'manne',
      contentType: 'livres',
      contentValues: ['Psaumes', 'Proverbes'],
      members: 38,
      shepherd: 'David_77',
    );
    await show(tester, const SalonPage(id: 's1', preview: preview), 'salon_fiche');
    expect(find.text('Les Psalmistes'), findsOneWidget);
    expect(find.text('Psaumes, Proverbes'), findsOneWidget);

    await show(tester, const SalonCreateScreen(), 'salon_creation');
    expect(find.text('Créer un salon'), findsOneWidget);
    await tester.tap(find.text('Jardin au matin'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Continuer'), findsOneWidget);
  });
}
