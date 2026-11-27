import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/core/card_data.dart';
import 'package:perfectionnement/ui/game/card_face.dart';

import 'local_match_test.dart' show loadFonts;

void main() {
  testWidgets('la question tient dans sa place, même avec un grand texte Android', (tester) async {
    await tester.runAsync(loadFonts);
    const q = 'Quel disciple a renié Jésus trois fois avant le chant du coq ?';
    const data = CardData(
      id: 'T',
      difficulty: 'lait',
      testament: 'NT',
      books: ['Matthieu'],
      category: 'personnages',
      question: q,
      answer: 'Pierre',
      wrongs: ['Thomas', 'Judas', 'Jacques'],
    );
    const width = 300.0;
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: CardFace(data: data, options: ['Thomas', 'Judas', 'Jacques', 'Pierre'], width: width, hideBook: true),
        ),
      ),
    ));
    final u = width / 85;
    // Hauteur réelle du texte (la boîte, elle, est bornée et cacherait le débordement).
    final paragraph = tester.renderObject<RenderParagraph>(find.text(q));
    expect(paragraph.textSize.height, lessThanOrEqualTo(25.5 * u + 0.5));
  });
}
