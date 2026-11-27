import 'dart:convert';

/// Cartes vues lors des dernières parties sur cet appareil (PRD §2.1).
///
/// Ne gère que le contenu ; la lecture et l'écriture sont confiées à l'appelant
/// (fichier, préférences…), ce qui garde ces règles testables sans disque.
class LocalHistory {
  static const maxGames = 5;

  final List<List<String>> games;

  LocalHistory([List<List<String>>? games]) : games = games ?? [];

  factory LocalHistory.decode(String? text) {
    if (text == null || text.isEmpty) return LocalHistory();
    try {
      final parsed = jsonDecode(text);
      if (parsed is! List) return LocalHistory();
      return LocalHistory([
        for (final g in parsed)
          if (g is List) [for (final id in g) '$id'],
      ]);
    } on FormatException {
      return LocalHistory();
    }
  }

  String encode() => jsonEncode(games);

  Set<String> get recentIds => {for (final g in games) ...g};

  void record(List<String> cardIds) {
    games.add([...cardIds]);
    while (games.length > maxGames) {
      games.removeAt(0);
    }
  }
}
