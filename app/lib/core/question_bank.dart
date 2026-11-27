import 'dart:convert';

import 'bible_books.dart';
import 'card_data.dart';
import 'content_filter.dart';
import 'starter_question.dart';

/// Banque de questions. Les brouillons ne sont inclus que si [includeDrafts] est vrai
/// (versions de développement).
///
/// La réserve « téléphone » (mode 2 joueurs, hors ligne) est dans l'APK. La réserve
/// « en ligne » (data/en_ligne/) reste sur le serveur : elle n'entre jamais dans l'APK.
class QuestionBank {
  final List<CardData> cards;
  final List<StarterQuestion> starters;

  /// id du récit → titre
  final Map<String, String> stories;

  const QuestionBank(this.cards, this.starters, this.stories);

  /// Construit la banque à partir du texte des trois fichiers JSON.
  factory QuestionBank.parse({
    required String cardsJson,
    required String startersJson,
    required String storiesJson,
    required bool includeDrafts,
  }) {
    final cards = [
      for (final d in jsonDecode(cardsJson) as List) CardData.fromJson(d as Map<String, dynamic>),
    ].where((c) => includeDrafts || c.isValidated).toList();
    final starters = [
      for (final d in jsonDecode(startersJson) as List)
        StarterQuestion.fromJson(d as Map<String, dynamic>),
    ].where((q) => includeDrafts || q.isValidated).toList();
    final stories = {
      for (final e in (jsonDecode(storiesJson) as Map<String, dynamic>).entries) e.key: '${e.value}',
    };
    return QuestionBank(cards, starters, stories);
  }

  List<CardData> filter(ContentFilter criteria) => cards.where(criteria.matches).toList();

  /// Livres présents pour une difficulté, dans l'ordre canonique.
  List<String> booksFor(String difficulty) => {
        for (final c in cards)
          if (c.difficulty == difficulty) ...c.books,
      }.toList()
        ..sort((a, b) => BibleBooks.canonicalIndex(a).compareTo(BibleBooks.canonicalIndex(b)));

  String storyTitle(String storyId) => stories[storyId] ?? storyId;
}
