import 'bible_books.dart';

/// Une carte Question telle qu'elle est stockée dans data/cartes.json.
class CardData {
  static const difficulties = ['lait', 'manne', 'solide'];
  static const difficultyLabels = {'lait': 'Lait', 'manne': 'Manne', 'solide': 'Nourriture solide'};
  static const categories = ['personnages', 'miracles', 'paraboles', 'lieux_evenements', 'structure'];
  static const categoryLabels = {
    'personnages': 'Personnages',
    'miracles': 'Miracles',
    'paraboles': 'Paraboles',
    'lieux_evenements': 'Lieux et événements',
    'structure': 'Structure de la Bible',
  };
  static const testaments = ['AT', 'NT'];
  static const wrongCount = 5;

  final String id;
  final String difficulty;
  final String testament;
  final List<String> books;
  final String category;
  final String question;
  final String answer;
  final List<String> wrongs;
  final String reference;
  final String explanation;
  final String story;
  final String status;

  const CardData({
    required this.id,
    this.difficulty = '',
    this.testament = '',
    this.books = const [],
    this.category = '',
    this.question = '',
    required this.answer,
    required this.wrongs,
    this.reference = '',
    this.explanation = '',
    this.story = '',
    this.status = 'brouillon',
  });

  factory CardData.fromJson(Map<String, dynamic> d) => CardData(
        id: '${d['id'] ?? ''}',
        difficulty: '${d['difficulty'] ?? ''}',
        testament: '${d['testament'] ?? ''}',
        books: [for (final b in (d['books'] as List? ?? const [])) '$b'],
        category: '${d['category'] ?? ''}',
        question: '${d['question'] ?? ''}',
        answer: '${d['answer'] ?? ''}',
        wrongs: [for (final w in (d['wrongs'] as List? ?? const [])) '$w'],
        reference: '${d['reference'] ?? ''}',
        explanation: '${d['explanation'] ?? ''}',
        story: '${d['story'] ?? ''}',
        status: '${d['status'] ?? 'brouillon'}',
      );

  bool get isValidated => status == 'valide';

  String get difficultyLabel => difficultyLabels[difficulty] ?? difficulty;

  String get categoryLabel => categoryLabels[category] ?? category;

  /// Liste des problèmes de la carte (vide si la carte est correcte).
  List<String> problems() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('id manquant');
    if (!difficulties.contains(difficulty)) errors.add('difficulté inconnue : $difficulty');
    // Une question sur la structure de la Bible peut n'appartenir à aucun livre ni testament.
    final general = category == 'structure';
    if (!testaments.contains(testament) && !(general && testament.isEmpty)) errors.add('testament inconnu : $testament');
    if (books.isEmpty && !general) errors.add('aucun livre');
    for (final b in books) {
      if (!BibleBooks.exists(b)) errors.add('livre inconnu : $b');
    }
    if (!categories.contains(category)) errors.add('catégorie inconnue : $category');
    if (question.isEmpty || answer.isEmpty || reference.isEmpty || story.isEmpty) {
      errors.add('champ texte manquant');
    }
    if (wrongs.length != wrongCount) {
      errors.add('${wrongs.length} fausses réponses au lieu de $wrongCount');
    }
    errors.addAll(duplicateProblems(answer, wrongs));
    return errors;
  }
}

/// Propositions en double parmi la bonne réponse et les fausses.
List<String> duplicateProblems(String answer, List<String> wrongs) {
  final seen = {answer};
  return [
    for (final w in wrongs)
      if (!seen.add(w)) 'proposition en double : $w',
  ];
}
