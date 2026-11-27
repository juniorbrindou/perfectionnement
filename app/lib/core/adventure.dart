/// Progression de l'aventure : étoiles gagnées par niveau (« 1 » → [étoiles]), comme le serveur
/// les renvoie (server/src/arcade.ts).
abstract final class Adventure {
  /// Un niveau est ouvert si c'est le premier, ou si le précédent a au moins une étoile.
  static bool isOpen(Map<String, List> stars, int level) =>
      level == 1 || (stars['${level - 1}'] ?? const []).isNotEmpty;

  /// Le niveau à jouer : le premier ouvert sans étoile, sinon le dernier ouvert.
  static int currentLevel(Map<String, List> stars, int count) {
    var last = 1;
    for (var level = 1; level <= count; level++) {
      if (!isOpen(stars, level)) break;
      last = level;
      if ((stars['$level'] ?? const []).isEmpty) return level;
    }
    return last;
  }
}
