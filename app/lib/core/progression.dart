/// XP, niveaux et rangs (PRD §7). Même table que server/src/regles.ts : le serveur
/// attribue l'XP, le client l'affiche. Les tests des deux côtés vérifient les mêmes seuils.
abstract final class Progression {
  static const ranks = [
    (1, 'Débutant'),
    (6, 'Explorateur'),
    (11, 'Connaisseur'),
    (21, 'Expert'),
    (36, 'Maître biblique'),
  ];

  /// Les 10 premiers du classement général portent le Rang S (PRD §7).
  static const rankSPlaces = 10;

  /// XP à gagner pour passer du niveau n au niveau n + 1 : 100, puis 50 de plus à chaque niveau.
  static int xpToLevelUp(int n) => 100 + 50 * (n - 1);

  /// Niveau atteint, XP gagnée dans ce niveau, XP du niveau.
  static ({int level, int inLevel, int toNext}) fromXp(int xp) {
    var level = 1;
    var rest = xp < 0 ? 0 : xp;
    while (rest >= xpToLevelUp(level)) {
      rest -= xpToLevelUp(level);
      level++;
    }
    return (level: level, inLevel: rest, toNext: xpToLevelUp(level));
  }

  static String rank(int level) {
    var name = ranks.first.$2;
    for (final (min, label) in ranks) {
      if (level >= min) name = label;
    }
    return name;
  }

  /// Rang S : être dans les 10 premiers du classement général (place 0 : pas classé).
  static bool hasRankS(int place) => place >= 1 && place <= rankSPlaces;
}
