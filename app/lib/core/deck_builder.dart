import 'dart:math';

import 'card_data.dart';
import 'duel.dart';
import 'rand.dart';

/// Distribution des mains (PRD §2.1) : tirage au hasard, sans doublon,
/// en évitant les cartes vues récemment tant que la réserve le permet.
abstract final class DeckBuilder {
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
    final ordered = [...fresh, ...seen];
    return (ordered.sublist(0, handSize), ordered.sublist(handSize, handSize * 2));
  }
}
