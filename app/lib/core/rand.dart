import 'dart:math';

/// Utilitaires aléatoires reproductibles (un [Random] injecté).
void shuffleWith<T>(List<T> list, Random rng) {
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
}

T pickWith<T>(List<T> list, Random rng) => list[rng.nextInt(list.length)];

/// Entier entre [min] et [max] inclus.
int rangeWith(Random rng, int min, int max) => min + rng.nextInt(max - min + 1);
