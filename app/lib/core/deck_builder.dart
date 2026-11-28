import 'dart:math';

import 'card_data.dart';
import 'duel.dart';
import 'rand.dart';

/// Distribution des mains (PRD §2.1) : tirage au hasard, sans doublon,
/// en évitant les cartes vues récemment tant que la réserve le permet.
abstract final class DeckBuilder {
  /// Cartes « Structure de la Bible » au plus par main (comme le serveur).
  static const structurePerHand = 1;

  /// Sert deux mains dans l'ordre donné, en limitant les cartes Structure tant que la réserve le permet.
  static (List<CardData>, List<CardData>) _hands(List<CardData> ordered, int handSize) {
    final left = [...ordered];
    final hands = [<CardData>[], <CardData>[]];
    for (final hand in hands) {
      var structure = 0;
      for (var i = 0; i < left.length && hand.length < handSize;) {
        final isStructure = left[i].category == 'structure';
        if (isStructure && structure >= structurePerHand) {
          i++;
          continue;
        }
        if (isStructure) structure++;
        hand.add(left.removeAt(i));
      }
    }
    for (final hand in hands) {
      while (hand.length < handSize) {
        hand.add(left.removeAt(0));
      }
    }
    return (hands[0], hands[1]);
  }

  static int minPoolSize([int handSize = Duel.handSize]) => handSize * 2;

  static (List<CardData>, List<CardData>) deal(
    List<CardData> pool,
    Set<String> recentIds,
    Random rng, [
    int handSize = Duel.handSize,
  ]) {
    if (pool.length < minPoolSize(handSize)) throw ArgumentError('Pas assez de cartes');
    final fresh = [for (final c in pool) if (!recentIds.contains(c.id)) c];
    final seen = [for (final c in pool) if (recentIds.contains(c.id)) c];
    shuffleWith(fresh, rng);
    shuffleWith(seen, rng);
    return _hands([...fresh, ...seen], handSize);
  }
}
