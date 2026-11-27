import 'dart:math';

import 'card_data.dart';
import 'rand.dart';

/// Une carte dans une partie : elle s'affaiblit à chaque mauvaise réponse.
///
/// Au départ, 3 des 5 fausses réponses sont affichées (4 propositions), les 2 autres
/// sont en réserve. Chaque échec retire la fausse proposition choisie (4 → 3 → 2).
/// À 2 propositions (minimum), la fausse proposition choisie est remplacée par une
/// fausse réponse de la réserve ; réserve vide, elle ne change plus.
class CardInPlay {
  static const initialWrongs = 3;

  final CardData data;
  final List<String> shownWrongs;
  final List<String> reserve;

  CardInPlay._(this.data, this.shownWrongs, this.reserve);

  factory CardInPlay(CardData card, Random rng) {
    final pool = [...card.wrongs];
    shuffleWith(pool, rng);
    final cut = min(initialWrongs, pool.length);
    return CardInPlay._(card, pool.sublist(0, cut), pool.sublist(cut));
  }

  /// Carte dans un état donné (scénarios de test, état reçu du serveur).
  CardInPlay.withState(this.data, List<String> shown, List<String> reserve)
      : shownWrongs = [...shown],
        reserve = [...reserve];

  int get optionCount => shownWrongs.length + 1;

  /// Propositions à présenter, dans un ordre mélangé à chaque passage.
  List<String> options(Random rng) {
    final result = [data.answer, ...shownWrongs];
    shuffleWith(result, rng);
    return result;
  }

  bool isCorrect(String choice) => choice == data.answer;

  void weaken(String chosenWrong) {
    final i = shownWrongs.indexOf(chosenWrong);
    if (i == -1) throw ArgumentError('Proposition inconnue : $chosenWrong');
    if (shownWrongs.length > 1) {
      shownWrongs.removeAt(i);
    } else if (reserve.isNotEmpty) {
      shownWrongs[i] = reserve.removeAt(0);
    }
  }

  String randomWrong(Random rng) => pickWith(shownWrongs, rng);
}
