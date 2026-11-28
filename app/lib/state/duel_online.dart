import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nakama/nakama.dart';

import 'online.dart';

/// Messages du duel en ligne (server/src/duel_en_ligne.ts).
abstract final class DuelOp {
  static const depart = 1;
  static const jouer = 2;
  static const repondre = 3;
  static const continuer = 4;
  static const abandonner = 5;
  static const revanche = 6;
  static const vue = 10;
}

/// Ce qu'un écran de partie lit et envoie : la dernière vue, l'instant de son arrivée, l'état du
/// lien, et les choix du joueur (codes DuelOp). Duel en ligne (DuelOnline) ou arcade (ArcadeMatch).
abstract class MatchSource extends ChangeNotifier {
  Map<String, dynamic> get view;
  DateTime get viewAt;
  bool get linkLost => false;
  void send(int op, [Map<String, dynamic> data = const {}]);
  Future<void> leave();
}

/// Connexion temps réel des duels en ligne : recherche d'un adversaire, partie en cours, vues
/// envoyées par le serveur, reconnexion après une coupure (portée de scripts/online.gd).
class DuelOnline extends MatchSource {
  static final instance = DuelOnline();

  /// Une tentative toutes les 2 s : le serveur attend 30 s avant de déclarer l'absent perdant.
  static const reconnectTries = 14;

  NakamaWebsocketClient? _socket;
  int _socketCount = 0;
  final List<StreamSubscription> _subs = [];

  String _ticket = '';
  String matchId = '';

  /// Dernière vue de la partie envoyée par le serveur.
  @override
  Map<String, dynamic> view = const {};

  /// Instant où la vue est arrivée (pour décompter son temps restant).
  @override
  DateTime viewAt = DateTime.now();

  /// Connexion perdue pendant une partie, reconnexion en cours.
  @override
  bool linkLost = false;

  /// Adversaire trouvé (duel rapide) : la partie est rejointe.
  final _matched = StreamController<void>.broadcast();
  Stream<void> get onMatched => _matched.stream;

  bool get searching => _ticket.isNotEmpty;

  Future<bool> _ready() async {
    if (_socket != null) return true;
    final token = await Online.instance.sessionToken();
    if (token == null) return false;
    final key = 'duel-${_socketCount++}';
    final socket = NakamaWebsocketClient.init(
      key: key,
      host: Online.host,
      port: Online.port,
      ssl: true,
      token: token,
      onDone: () => _onClosed(key),
      onError: (e) => debugPrint('Socket : $e'),
    );
    _socket = socket;
    _subs
      ..add(socket.onMatchmakerMatched.listen(_onMatched))
      ..add(socket.onMatchData.listen(_onData));
    return true;
  }

  /// Duel rapide : entre dans la file du serveur. Renvoie un message d'erreur, ou null.
  Future<String?> search(String difficulty) async {
    if (!await _ready()) return 'Pas de connexion au serveur.';
    try {
      final t = await _socket!.addMatchmaker(
        minCount: 2,
        maxCount: 2,
        query: '+properties.difficulte:$difficulty',
        stringProperties: {'difficulte': difficulty},
      );
      _ticket = t.ticket;
      return null;
    } catch (e) {
      return Online.describe(e);
    }
  }

  /// Partie de salon : un autre membre du même salon qui cherche aussi (PRD §6.4). Le serveur
  /// vérifie l'appartenance ; la difficulté et les cartes sont celles du salon.
  Future<String?> searchSalon(String salonId) async {
    if (!await _ready()) return 'Pas de connexion au serveur.';
    try {
      final mark = salonId.replaceAll('-', '');
      final t = await _socket!.addMatchmaker(
        minCount: 2,
        maxCount: 2,
        query: '+properties.salon:$mark',
        stringProperties: {'salon': mark},
      );
      _ticket = t.ticket;
      return null;
    } catch (e) {
      return Online.describe(e);
    }
  }

  Future<void> cancelSearch() async {
    final ticket = _ticket;
    _ticket = '';
    if (ticket.isNotEmpty) {
      try {
        await _socket?.removeMatchmaker(ticket);
      } catch (_) {}
    }
  }

  /// Rejoint une partie. Renvoie un message d'erreur, ou null.
  Future<String?> join(String id) async {
    if (!await _ready()) return 'Pas de connexion au serveur.';
    view = const {};
    matchId = id; // Avant la réponse : les premières vues peuvent arriver avant elle.
    try {
      await _socket!.joinMatch(id);
      return null;
    } catch (e) {
      matchId = '';
      return Online.describe(e);
    }
  }

  @override
  void send(int op, [Map<String, dynamic> data = const {}]) {
    if (matchId.isEmpty) return;
    try {
      _socket?.sendMatchData(matchId: matchId, opCode: op, data: utf8.encode(jsonEncode(data)));
    } catch (e) {
      debugPrint('Envoi : $e');
    }
  }

  /// Quitte la partie (le serveur annule une partie pas encore commencée).
  @override
  Future<void> leave() async {
    final id = matchId;
    matchId = '';
    view = const {};
    if (id.isNotEmpty) {
      try {
        await _socket?.leaveMatch(id);
      } catch (_) {}
    }
  }

  Future<void> _onMatched(MatchmakerMatched m) async {
    _ticket = '';
    final id = m.matchId ?? '';
    if (id.isEmpty) return;
    final error = await join(id);
    if (error == null) {
      _matched.add(null);
    } else {
      debugPrint('Duel rapide : $error');
    }
  }

  void _onData(MatchData d) {
    if (d.matchId != matchId || d.opCode != DuelOp.vue) return;
    try {
      final v = jsonDecode(utf8.decode(d.data ?? const []));
      if (v is Map<String, dynamic>) {
        view = v;
        viewAt = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Vue illisible : $e');
    }
  }

  /// Le téléphone a perdu le réseau en pleine partie : on se reconnecte et on rejoint la même
  /// partie (le serveur la met en pause).
  Future<void> _onClosed(String key) async {
    if (_socketCount == 0 || key != 'duel-${_socketCount - 1}') return;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _socket = null;
    _ticket = '';
    if (matchId.isEmpty || linkLost) return;
    linkLost = true;
    notifyListeners();
    for (var i = 0; i < reconnectTries && matchId.isNotEmpty; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (matchId.isEmpty) break;
      if (await _ready()) {
        try {
          await _socket!.joinMatch(matchId);
          linkLost = false;
          notifyListeners();
          return;
        } catch (_) {}
      }
    }
    linkLost = false;
    matchId = '';
    view = const {'etape': 'annulee', 'annulation': 'Connexion perdue.'};
    notifyListeners();
  }
}
