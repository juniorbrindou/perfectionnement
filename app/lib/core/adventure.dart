/// Étoiles de l'Aventure : pour chaque étape, de 0 à 3 étoiles par difficulté (« 1 » → {lait: 2}),
/// comme le serveur les renvoie (server/src/aventure.ts).
typedef AdventureStars = Map<String, Map<String, int>>;

abstract final class Adventure {
  static const difficulties = ['lait', 'manne', 'solide'];

  /// Lit les étoiles reçues ou gardées. L'ancien format (une liste des difficultés gagnées contre le
  /// Scribe) donne une étoile par difficulté, comme sur le serveur.
  static AdventureStars parse(Object? data) {
    final r = <String, Map<String, int>>{};
    if (data is! Map) return r;
    data.forEach((level, v) {
      if (v is Map) {
        r['$level'] = {for (final e in v.entries) '${e.key}': e.value is num ? (e.value as num).toInt() : 0};
      } else if (v is List) {
        r['$level'] = {for (final d in v) '$d': 1};
      }
    });
    return r;
  }

  static int stars(AdventureStars s, int level, String difficulty) => s['$level']?[difficulty] ?? 0;

  /// Étoiles d'une étape, toutes difficultés (9 au plus).
  static int levelTotal(AdventureStars s, int level) =>
      difficulties.fold(0, (n, d) => n + stars(s, level, d));

  /// Difficultés où l'étape a au moins une étoile (0 à 3).
  static int difficultiesWon(AdventureStars s, int level) =>
      difficulties.where((d) => stars(s, level, d) > 0).length;

  /// Une étape est ouverte si c'est la première, ou si la précédente a au moins une étoile.
  static bool isOpen(AdventureStars s, int level) => level == 1 || levelTotal(s, level - 1) > 0;

  /// L'étape à jouer : la première ouverte sans étoile, sinon la dernière ouverte.
  static int currentLevel(AdventureStars s, int count) {
    var last = 1;
    for (var level = 1; level <= count; level++) {
      if (!isOpen(s, level)) break;
      last = level;
      if (levelTotal(s, level) == 0) return level;
    }
    return last;
  }

  /// Difficulté proposée : la première sans étoile, sinon la première pas encore parfaite.
  static String suggestedDifficulty(AdventureStars s, int level) =>
      difficulties.firstWhere((d) => stars(s, level, d) == 0,
          orElse: () => difficulties.firstWhere((d) => stars(s, level, d) < 3, orElse: () => 'lait'));
}
