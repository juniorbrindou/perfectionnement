import 'package:flutter/foundation.dart';

enum Connection { offline, connecting, online }

/// Le joueur tel que l'interface l'affiche : compte, progression, talents, pain quotidien.
///
/// Rempli par la connexion au serveur (à venir) et par le compte gardé sur le téléphone ;
/// les écrans l'écoutent pour se mettre à jour seuls.
class Player extends ChangeNotifier {
  static final instance = Player();

  Connection connection = Connection.offline;
  String username = '';
  int xp = 0;
  int talents = 0;

  /// Place au classement général (0 : pas classé).
  int rankPlace = 0;
  bool breadToday = false;
  int breadGain = 0;

  /// Étoiles de l'aventure, par niveau (« 1 » → [étoiles]).
  Map<String, List> adventureStars = {};

  /// Compte connu : reçu du serveur ou gardé sur le téléphone.
  bool get isKnown => username.isNotEmpty;

  void update(void Function(Player p) change) {
    change(this);
    notifyListeners();
  }
}
