import 'package:flutter/foundation.dart';

/// Réglages du jeu en vigueur (RPC « reglages », modifiables depuis le back-office, voir
/// docs/SERVEUR.md). Les valeurs par défaut sont celles du serveur, pour l'affichage hors ligne.
class Reglages extends ChangeNotifier {
  static final instance = Reglages();

  static const defauts = {
    'capital_depart': 100,
    'pain_quotidien': 10,
    'mise_arcade_lait': 2,
    'mise_arcade_manne': 5,
    'mise_arcade_solide': 10,
    'mise_duel_lait': 5,
    'mise_duel_manne': 20,
    'mise_duel_solide': 50,
    'salon_cout': 30,
    'arcade_depart_s': 20,
    'arcade_choisir_s': 20,
    'arcade_repondre_s': 30,
    'duel_depart_s': 30,
    'duel_choisir_s': 30,
    'duel_repondre_s': 45,
    'duel_resultat_s': 10,
    'duel_reconnexion_s': 30,
    'duel_revanche_s': 15,
    'xp_victoire': 30,
    'xp_defaite': 10,
    'salon_membres_max': 50,
    'salon_questions_min': 10,
    'salon_score_victoire': 10,
    'salon_score_defaite': 5,
    'salon_inactif_jours': 7,
    'aventure_questions': 10,
    'aventure_delai_s': 30,
  };

  final Map<String, int> _valeurs = {};

  int operator [](String cle) => _valeurs[cle] ?? defauts[cle] ?? 0;

  int get salonCout => this['salon_cout'];
  int miseDuel(String difficulte) => this['mise_duel_$difficulte'];
  int miseArcade(String difficulte) => this['mise_arcade_$difficulte'];

  /// Valeurs reçues du serveur (ou gardées sur le téléphone).
  void appliquer(Map<String, dynamic> valeurs) {
    var change = false;
    valeurs.forEach((cle, v) {
      final n = v is num ? v.toInt() : int.tryParse('$v');
      if (n != null && _valeurs[cle] != n) {
        _valeurs[cle] = n;
        change = true;
      }
    });
    if (change) notifyListeners();
  }

  Map<String, int> get valeurs => Map.unmodifiable(_valeurs);
}
