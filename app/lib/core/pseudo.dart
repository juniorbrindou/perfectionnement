import 'dart:math';

import 'rand.dart';

/// Pseudos lisibles proposés aux invités (PRD §5), et règles de saisie.
abstract final class Pseudo {
  static const words = [
    'Colombe', 'Olivier', 'Cedre', 'Berger', 'Semeur', 'Lampe', 'Sentinelle', 'Pelerin',
    'Psalmiste', 'Vigneron', 'Pecheur', 'Scribe', 'Etoile', 'Rocher', 'Source', 'Moisson',
    'Grenade', 'Figuier', 'Agneau', 'Lion', 'Harpe', 'Trompette', 'Manne', 'Sel',
  ];
  static const minLength = 3;
  static const maxLength = 16;
  static final _allowed = RegExp(r'^[A-Za-z0-9_.-]+$');

  static String generate(Random rng) => '${pickWith(words, rng)}${rangeWith(rng, 10, 999)}';

  /// Message d'erreur, ou null si le pseudo est acceptable.
  static String? problem(String name) {
    final n = name.trim();
    if (n.length < minLength) return 'Le pseudo doit faire au moins $minLength caractères.';
    if (n.length > maxLength) return 'Le pseudo doit faire au plus $maxLength caractères.';
    if (!_allowed.hasMatch(n)) {
      return 'Lettres sans accents, chiffres, point, tiret ou soulignement seulement.';
    }
    return null;
  }
}
