import 'dart:math';

import 'card_data.dart';
import 'card_in_play.dart';

enum Phase { starter, choosing, answering, finished }

/// Résultat d'une réponse.
class AnswerResult {
  final bool correct;
  final CardInPlay card;
  final int owner;

  const AnswerResult(this.correct, this.card, this.owner);
}

/// Règles d'un duel, sans affichage ni minuteur (PRD §2).
///
/// Alternance stricte : le poseur choisit une carte, l'autre répond.
/// Bonne réponse → la carte du poseur est détruite. Mauvaise réponse → elle revient,
/// affaiblie. Le joueur qui n'a plus de cartes perd.
class Duel {
  static const handSize = 5;

  Phase phase = Phase.starter;
  final List<List<CardInPlay>> hands;
  final List<List<CardData>> destroyed = [[], []];
  int poser = -1;
  int winner = -1;
  CardInPlay? played;
  List<String> presented = [];

  int _playedIndex = -1;
  final Random _rng;

  Duel(List<CardData> handA, List<CardData> handB, this._rng)
      : hands = [
          [for (final c in handA) CardInPlay(c, _rng)],
          [for (final c in handB) CardInPlay(c, _rng)],
        ];

  int get answerer => 1 - poser;

  int get loser => winner == -1 ? -1 : 1 - winner;

  void startWith(int player) {
    _expect(Phase.starter);
    poser = player;
    phase = Phase.choosing;
  }

  void play(int index) {
    _expect(Phase.choosing);
    _playedIndex = index;
    final card = hands[poser].removeAt(index);
    played = card;
    presented = card.options(_rng);
    phase = Phase.answering;
  }

  int playRandom() {
    final index = _rng.nextInt(hands[poser].length);
    play(index);
    return index;
  }

  /// Applique la réponse.
  AnswerResult answer(String choice) {
    _expect(Phase.answering);
    if (!presented.contains(choice)) throw ArgumentError('Réponse hors propositions : $choice');
    final card = played!;
    final owner = poser;
    final correct = card.isCorrect(choice);
    if (correct) {
      destroyed[owner].add(card.data);
      if (hands[owner].isEmpty) winner = answerer;
    } else {
      card.weaken(choice);
      hands[owner].insert(_playedIndex, card);
    }
    played = null;
    presented = [];
    _playedIndex = -1;
    if (winner != -1) {
      phase = Phase.finished;
    } else {
      poser = 1 - owner;
      phase = Phase.choosing;
    }
    return AnswerResult(correct, card, owner);
  }

  /// Temps écoulé : compté comme une mauvaise réponse prise au hasard.
  AnswerResult answerTimeout() {
    _expect(Phase.answering);
    return answer(played!.randomWrong(_rng));
  }

  void _expect(Phase p) {
    if (phase != p) throw StateError('Phase $phase au lieu de $p');
  }
}
