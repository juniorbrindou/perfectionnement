import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/state/quiz.dart';
import 'package:perfectionnement/state/session.dart';
import 'package:perfectionnement/ui/adventure/quiz_screen.dart';

import 'aventure_test.dart' show loadIcons;
import 'local_match_test.dart' show loadFonts, settle;

/// Partie jouée sans serveur : deux questions, la première ratée.
class _FakeQuiz extends Quiz {
  int asked = 1;
  _FakeQuiz() : super(1, 'lait');

  @override
  Future<QuizQuestion> next() async =>
      QuizQuestion(++asked, 2, 0, 'Quel jour Dieu créa-t-il les luminaires ?', 'lieux_evenements',
          const ['Le premier', 'Le quatrième', 'Le sixième', 'Le septième'], 30);

  @override
  Future<QuizAnswer> answer(String choice) async => asked == 1
      ? QuizAnswer(false, false, choice, 'La lumière', 'Genèse 1:3-5',
          'Dieu dit : Que la lumière soit ! Et la lumière fut.', 0, null)
      : QuizAnswer(true, false, choice, 'Le quatrième', 'Genèse 1:14-19', 'Le soleil, la lune et les étoiles.', 1,
          const QuizEnd(1, 2, 0, 1, 0, 3, 0, 1, 1));

  @override
  Future<void> quit() async {}
}

void main() {
  testWidgets('quiz : question, réponse expliquée, question suivante, résultat', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    await tester.runAsync(loadIcons);
    await tester.runAsync(() => Session.instance.loadIllustrations());
    final quiz = _FakeQuiz();
    const first = QuizQuestion(1, 2, 0, 'Qu’est-ce que Dieu créa au premier jour ?', 'lieux_evenements',
        ['Les étoiles', 'La lumière', 'Les poissons', 'L’homme'], 30);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: QuizScreen(quiz: quiz, first: first, levelName: 'Niveau 1 · La création'),
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await settle(tester, frames: 6);
    Future<void> capture(String name) async {
      if (Platform.environment['CAPTURE'] == '1') {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/$name.png'));
      }
    }

    expect(find.text('Question 1 sur 2'), findsOneWidget);
    await capture('quiz_question');
    await tester.tap(find.text('Les étoiles'));
    await settle(tester, frames: 4);
    expect(find.text('Ce n’était pas ça.'), findsOneWidget);
    expect(find.text('Réponse : La lumière'), findsOneWidget);
    expect(find.text('Genèse 1:3-5'), findsOneWidget);
    await capture('quiz_reponse');
    await tester.tap(find.text('Question suivante'));
    await settle(tester, frames: 4);
    expect(find.text('Question 2 sur 2'), findsOneWidget);
    await tester.tap(find.text('Le quatrième'));
    await settle(tester, frames: 4);
    expect(find.text('Bonne réponse !'), findsOneWidget);
    await tester.tap(find.text('Voir le résultat'));
    await settle(tester, frames: 6);
    expect(find.text('1 bonne réponse sur 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('quiz_fin');
    await tester.pumpWidget(const SizedBox());
  });
}
