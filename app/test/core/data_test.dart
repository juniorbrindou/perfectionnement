import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/core/card_data.dart';
import 'package:perfectionnement/core/content_filter.dart';
import 'package:perfectionnement/core/deck_builder.dart';
import 'package:perfectionnement/core/question_bank.dart';

/// Intégrité des fichiers de contenu de data/ : la réserve « téléphone » (dans l'APK)
/// et la réserve « en ligne » (data/en_ligne/, sur le serveur seulement).
QuestionBank load(String dir) => QuestionBank.parse(
      cardsJson: File('$dir/cartes.json').readAsStringSync(),
      startersJson: File('$dir/questions_depart.json').readAsStringSync(),
      storiesJson: File('../data/recits.json').readAsStringSync(),
      includeDrafts: true,
    );

void main() {
  final banks = {'téléphone': load('../data'), 'en ligne': load('../data/en_ligne')};

  test('chaque carte est bien formée', () {
    banks.forEach((name, bank) {
      expect(bank.cards, isNotEmpty, reason: name);
      for (final c in bank.cards) {
        expect(c.problems(), isEmpty, reason: '$name ${c.id}');
        expect(bank.stories.containsKey(c.story), isTrue, reason: '${c.id} : récit inconnu ${c.story}');
      }
    });
  });

  test('chaque question de départ est bien formée', () {
    banks.forEach((name, bank) {
      expect(bank.starters, isNotEmpty, reason: name);
      for (final q in bank.starters) {
        expect(q.problems(), isEmpty, reason: '$name ${q.id}');
      }
    });
  });

  // Une carte présente dans l'APK peut être lue par un tricheur : elle ne doit jamais sortir en ligne.
  test('les deux réserves n\'ont aucune carte en commun', () {
    final ids = <String>{};
    for (final bank in banks.values) {
      for (final id in [...bank.cards.map((c) => c.id), ...bank.starters.map((q) => q.id)]) {
        expect(ids.add(id), isTrue, reason: 'dans les deux réserves, ou en double : $id');
      }
    }
  });

  test('chaque réserve peut distribuer deux mains dans chaque difficulté', () {
    banks.forEach((name, bank) {
      for (final diff in CardData.difficulties) {
        final n = bank.filter(ContentFilter.bible(diff)).length;
        expect(n, greaterThanOrEqualTo(DeckBuilder.minPoolSize()), reason: '$name $diff');
      }
    });
  });
}
