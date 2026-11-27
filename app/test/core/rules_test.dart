import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/core/card_in_play.dart';
import 'package:perfectionnement/core/content_filter.dart';
import 'package:perfectionnement/core/deck_builder.dart';
import 'package:perfectionnement/core/duel.dart';
import 'package:perfectionnement/core/local_history.dart';
import 'package:perfectionnement/core/progression.dart';
import 'package:perfectionnement/core/pseudo.dart';
import 'package:perfectionnement/core/starter_question.dart';

import 'helpers.dart';

Random rng([int seed = 42]) => Random(seed);

void main() {
  group('CardInPlay', () {
    test('commence avec 4 propositions et 2 en réserve', () {
      final c = CardInPlay(makeCard('a'), rng());
      expect(c.optionCount, 4);
      expect(c.reserve.length, 2);
      expect(c.options(rng()), contains('bonne'));
    });

    test('chaque échec retire la fausse proposition choisie, jusqu\'à 2', () {
      final c = CardInPlay(makeCard('a'), rng());
      final first = c.shownWrongs[0];
      c.weaken(first);
      expect(c.optionCount, 3);
      expect(c.shownWrongs, isNot(contains(first)));
      c.weaken(c.shownWrongs[0]);
      expect(c.optionCount, 2);
    });

    test('à 2 propositions, la fausse choisie est remplacée par la réserve', () {
      final c = CardInPlay(makeCard('a'), rng());
      c.weaken(c.shownWrongs[0]);
      c.weaken(c.shownWrongs[0]);
      final reserveBefore = [...c.reserve];
      final chosen = c.shownWrongs[0];
      c.weaken(chosen);
      expect(c.optionCount, 2);
      expect(c.shownWrongs[0], isNot(chosen));
      expect(c.shownWrongs[0], reserveBefore[0]);
    });

    test('réserve vide : la dernière fausse proposition reste', () {
      final c = CardInPlay(makeCard('a'), rng());
      for (var i = 0; i < 4; i++) {
        c.weaken(c.shownWrongs[0]);
      }
      expect(c.reserve, isEmpty);
      final last = c.shownWrongs[0];
      c.weaken(last);
      expect(c.shownWrongs[0], last);
      expect(c.optionCount, 2);
    });

    test('ne montre jamais une fausse proposition déjà éliminée', () {
      final c = CardInPlay(makeCard('a'), rng(7));
      final eliminated = <String>{};
      for (var i = 0; i < 4; i++) {
        final w = c.shownWrongs[0];
        eliminated.add(w);
        c.weaken(w);
        for (final o in c.options(rng(i))) {
          expect(eliminated, isNot(contains(o)));
        }
      }
    });
  });

  group('Duel', () {
    Duel newDuel() => Duel(makeHand('a'), makeHand('b'), rng())..startWith(0);
    String wrongChoice(Duel d) => d.presented.firstWhere((o) => o != 'bonne');

    test('bonne réponse : la carte du poseur est détruite et le tour passe', () {
      final d = newDuel()..play(0);
      final r = d.answer('bonne');
      expect(r.correct, isTrue);
      expect(d.hands[0].length, 4);
      expect(d.destroyed[0].length, 1);
      expect(d.poser, 1);
      expect(d.phase, Phase.choosing);
    });

    test('mauvaise réponse : la carte revient affaiblie à la même place', () {
      final d = newDuel();
      final card = d.hands[0][2];
      d.play(2);
      d.answer(wrongChoice(d));
      expect(d.hands[0].length, 5);
      expect(identical(d.hands[0][2], card), isTrue);
      expect(card.optionCount, 3);
      expect(d.poser, 1);
    });

    test('le joueur sans cartes perd', () {
      final d = newDuel();
      for (var turn = 0; turn < 9; turn++) {
        d.play(0);
        d.answer(d.poser == 1 ? 'bonne' : wrongChoice(d));
      }
      d.play(0);
      d.answer('bonne');
      expect(d.phase, Phase.finished);
      expect(d.hands[1], isEmpty);
      expect(d.winner, 0);
    });

    test('temps écoulé = mauvaise réponse', () {
      final d = newDuel()..play(0);
      final r = d.answerTimeout();
      expect(r.correct, isFalse);
      expect(d.hands[0].length, 5);
      expect(d.hands[0][0].optionCount, 3);
    });

    test('playRandom joue une carte de la main du poseur', () {
      final d = newDuel()..playRandom();
      expect(d.phase, Phase.answering);
      expect(d.hands[0].length, 4);
      expect(d.presented.length, 4);
    });
  });

  group('Mise en place', () {
    test('question de départ : la première réponse juste commence', () {
      const q = StarterQuestion(
          id: 's', question: '?', answer: 'oui', wrongs: ['a', 'b', 'c', 'd'], reference: 'x');
      final starter = StarterRound(q, rng());
      expect(starter.options.length, 5);
      expect(starter.resolve(1, 'oui'), 1);
      expect(starter.resolve(1, 'a'), 0, reason: 'une erreur fait commencer l\'autre');
    });

    test('distribution sans doublon, cartes récentes évitées', () {
      final pool = makeHand('c', 14);
      final recent = {for (var i = 0; i < 4; i++) 'c$i'};
      final (a, b) = DeckBuilder.deal(pool, recent, rng());
      final ids = <String>{};
      for (final hand in [a, b]) {
        expect(hand.length, 5);
        for (final c in hand) {
          expect(ids.add(c.id), isTrue, reason: 'doublon ${c.id}');
          expect(recent, isNot(contains(c.id)));
        }
      }
    });

    test('distribution : cartes récentes reprises si la réserve est petite', () {
      final (a, b) = DeckBuilder.deal(makeHand('c', 10), {'c0', 'c1'}, rng());
      expect(a.length + b.length, 10);
    });

    test('filtre par portée', () {
      final at = makeCard('x', difficulty: 'manne', testament: 'AT', books: ['Ruth']);
      expect(const ContentFilter.bible('manne').matches(at), isTrue);
      expect(const ContentFilter.bible('lait').matches(at), isFalse);
      expect(const ContentFilter.forTestament('manne', 'AT').matches(at), isTrue);
      expect(const ContentFilter.forTestament('manne', 'NT').matches(at), isFalse);
      expect(ContentFilter.forBooks('manne', ['Ruth', 'Esther']).matches(at), isTrue);
    });

    test('historique : seules les 5 dernières parties sont gardées', () {
      var h = LocalHistory();
      for (var g = 0; g < 7; g++) {
        h.record(['g$g']);
        h = LocalHistory.decode(h.encode());
      }
      final recent = h.recentIds;
      expect(recent.length, 5);
      expect(recent, isNot(contains('g0')));
      expect(recent, isNot(contains('g1')));
      expect(recent, contains('g6'));
    });
  });

  group('Progression (même table que server/test/run.js)', () {
    test('niveaux selon l\'XP totale', () {
      expect(Progression.fromXp(0), (level: 1, inLevel: 0, toNext: 100));
      expect(Progression.fromXp(99), (level: 1, inLevel: 99, toNext: 100));
      expect(Progression.fromXp(100), (level: 2, inLevel: 0, toNext: 150));
      expect(Progression.fromXp(700), (level: 5, inLevel: 0, toNext: 300));
      expect(Progression.fromXp(33250).level, 36);
    });

    test('rangs du PRD', () {
      expect(Progression.rank(1), 'Débutant');
      expect(Progression.rank(5), 'Débutant');
      expect(Progression.rank(6), 'Explorateur');
      expect(Progression.rank(11), 'Connaisseur');
      expect(Progression.rank(21), 'Expert');
      expect(Progression.rank(36), 'Maître biblique');
    });
  });

  group('Pseudo', () {
    test('les pseudos générés sont valides', () {
      final r = rng(3);
      for (var i = 0; i < 50; i++) {
        final p = Pseudo.generate(r);
        expect(Pseudo.problem(p), isNull, reason: p);
      }
    });

    test('refuse les mauvais pseudos', () {
      expect(Pseudo.problem('ab'), isNotNull);
      expect(Pseudo.problem('abcdefghijklmnopq'), isNotNull);
      expect(Pseudo.problem('Élie'), isNotNull);
      expect(Pseudo.problem('deux mots'), isNotNull);
      expect(Pseudo.problem('Ruth_42'), isNull);
    });
  });
}
