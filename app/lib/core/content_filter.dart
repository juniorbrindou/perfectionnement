import 'card_data.dart';

enum Scope { bible, testament, books }

/// Critères de contenu d'une partie : difficulté + portée (toute la Bible,
/// un Testament ou une liste de livres).
class ContentFilter {
  final String difficulty;
  final Scope scope;
  final String testament;
  final List<String> books;

  const ContentFilter.bible(this.difficulty)
      : scope = Scope.bible,
        testament = 'AT',
        books = const [];

  const ContentFilter.forTestament(this.difficulty, this.testament)
      : scope = Scope.testament,
        books = const [];

  ContentFilter.forBooks(this.difficulty, List<String> list)
      : scope = Scope.books,
        testament = 'AT',
        books = List.unmodifiable(list);

  bool matches(CardData card) {
    if (card.difficulty != difficulty) return false;
    return switch (scope) {
      Scope.testament => card.testament == testament,
      Scope.books => card.books.any(books.contains),
      Scope.bible => true,
    };
  }

  String describe() {
    final diff = CardData.difficultyLabels[difficulty] ?? difficulty;
    return switch (scope) {
      Scope.testament => '$diff · ${testament == 'AT' ? 'Ancien Testament' : 'Nouveau Testament'}',
      Scope.books => '$diff · ${books.join(', ')}',
      Scope.bible => '$diff · Toute la Bible',
    };
  }
}
