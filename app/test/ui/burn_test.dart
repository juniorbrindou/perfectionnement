import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/core/card_data.dart';
import 'package:perfectionnement/ui/game/burn.dart';
import 'package:perfectionnement/ui/game/card_face.dart';

import 'local_match_test.dart' show loadFonts, settle;

void main() {
  testWidgets('feu doré : la carte brûle', (tester) async {
    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    const data = CardData(
      id: 'T',
      difficulty: 'lait',
      testament: 'AT',
      books: ['Exode'],
      category: 'personnages',
      question: 'Quel frère de Moïse Dieu désigna-t-il pour parler à sa place ?',
      answer: 'Aaron',
      wrongs: ['Caleb', 'Josué', 'Hur'],
    );
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFF06122F),
        child: Center(
          child: FeuDore(
            size: const Size(220, 220 * cardRatio),
            duration: const Duration(milliseconds: 1100),
            child: CardFace(data: data, options: const ['Caleb', 'Aaron', 'Josué', 'Hur'], width: 220, marks: const {'Aaron': Mark.right}),
          ),
        ),
      ),
    ));
    await settle(tester);
    // Photo de la carte et chargement du shader, hors du temps simulé.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
    expect(find.byType(FeuDore), findsOneWidget);
    if (Platform.environment['CAPTURE'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/feu_dore.png'));
    }
  });
}
