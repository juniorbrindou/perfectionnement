import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/state/duel_online.dart';
import 'package:perfectionnement/ui/game/card_face.dart';
import 'package:perfectionnement/ui/online/duel_match_screen.dart';
import 'package:perfectionnement/ui/online/online_screen.dart';

import 'local_match_test.dart' show loadFonts;

final capture = Platform.environment['CAPTURE'] == '1';

Map<String, dynamic> carte(String q, String a, List<String> w, String livre) => {
      'id': 'X',
      'difficulty': 'manne',
      'testament': 'AT',
      'books': [livre],
      'category': 'personnages',
      'question': q,
      'answer': a,
      'wrongs': w,
      'reference': '$livre 1:1',
      'explanation': 'Explication.',
    };

final hand = [
  {'carte': carte('Qui a vaincu le géant Goliath ?', 'David', ['Saül', 'Samson', 'Jonathan', 'Gédéon', 'Salomon'], '1 Samuel'), 'fausses': ['Saül', 'Samson', 'Jonathan'], 'reserve': 2},
  {'carte': carte('Quel prophète a été englouti par un grand poisson ?', 'Jonas', ['Élie', 'Daniel', 'Jérémie', 'Ésaïe', 'Osée'], 'Jonas'), 'fausses': ['Élie', 'Daniel'], 'reserve': 1},
  {'carte': carte('Qui a été jeté dans la fosse aux lions ?', 'Daniel', ['Joseph', 'Jérémie', 'Élisée', 'Néhémie', 'Ézéchiel'], 'Daniel'), 'fausses': ['Joseph', 'Jérémie', 'Élisée'], 'reserve': 2},
];

Map<String, dynamic> base(String etape, {String poseur = ''}) => {
      'etape': etape,
      'mode': 'rapide',
      'difficulte': 'manne',
      'mise': 20,
      'adversaire': {'pseudo': 'Esdras42', 'niveau': 4, 'present': true},
      'poseur': poseur,
      'main': hand,
      'mainAdverse': 4,
      'temps': 25,
    };

Future<void> show(WidgetTester tester, Widget w, String name, {Map<String, dynamic>? view}) async {
  if (view != null) {
    DuelOnline.instance.view = view;
    DuelOnline.instance.viewAt = DateTime.now();
  }
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: w));
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 700)));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (capture) await expectLater(find.byType(MaterialApp), matchesGoldenFile('captures/$name.png'));
}


void main() {
  testWidgets('duel en ligne : salon, choix, réponse, raté, victoire', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);

    await show(tester, const OnlineScreen(), 'en_ligne');
    expect(find.text('Trouver un adversaire'), findsOneWidget);

    await show(tester, const DuelMatchScreen(), 'duel_depart', view: {
      ...base('depart'),
      'depart': {'question': 'Quel est le premier livre de la Bible ?', 'propositions': ['Exode', 'Genèse', 'Psaumes', 'Matthieu', 'Apocalypse']},
    });
    expect(find.byType(AnswerPill), findsNWidgets(5));

    await show(tester, const DuelMatchScreen(), 'duel_choix', view: base('choisir', poseur: 'moi'));
    expect(find.text('Choisis une question à poser à Esdras42'), findsOneWidget);

    await show(tester, const DuelMatchScreen(), 'duel_reponse', view: {
      ...base('repondre', poseur: 'adversaire'),
      'carte': {'difficulty': 'manne', 'category': 'personnages', 'question': 'Quel frère de Moïse parla à sa place ?', 'propositions': ['Caleb', 'Aaron', 'Josué', 'Hur']},
    });
    expect(find.text('Touche la bonne réponse'), findsOneWidget);

    await show(tester, const DuelMatchScreen(), 'duel_rate', view: {
      ...base('resultat'),
      'coup': {
        'type': 'coup',
        'mienne': false,
        'carte': {'difficulty': 'manne', 'category': 'personnages', 'question': 'Quel frère de Moïse parla à sa place ?', 'propositions': ['Caleb', 'Aaron', 'Josué', 'Hur']},
        'presentees': ['Caleb', 'Aaron', 'Josué', 'Hur'],
        'choix': 'Caleb',
        'juste': false,
        'tempsEcoule': false,
      },
      'continuer': {'moi': false, 'adversaire': false},
    });
    expect(find.text('Continuer'), findsOneWidget);

    await show(tester, const DuelMatchScreen(), 'duel_victoire', view: {
      ...base('finie'),
      'fin': {'gagne': true, 'raison': 'cartes', 'gain': 20, 'xp': 30},
      'revanche': {'moi': false, 'adversaire': true, 'possible': true},
    });
    expect(find.text('Victoire !'), findsOneWidget);
    expect(find.text('Esdras42 veut une revanche !'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
