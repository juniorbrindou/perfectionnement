import 'dart:async';

import 'package:flutter/foundation.dart';

import 'duel_online.dart';
import 'online.dart';
import 'player.dart';

/// Une partie d'arcade contre le Scribe, jouée sur le serveur (RPC « arcade », voir
/// server/src/arcade.ts). Traduit les réponses du serveur en vues de duel, pour que la même
/// table de jeu (DuelMatchScreen) serve aux deux modes.
class ArcadeMatch extends MatchSource {
  static const scribe = 'Le Scribe';

  final int level;
  final String difficulty;

  ArcadeMatch(this.level, this.difficulty);

  Map<String, dynamic> _view = const {};
  DateTime _viewAt = DateTime.now();

  /// Dernière vue du serveur (main, cartes détruites, étape).
  Map<String, dynamic> _server = const {};
  Map<String, dynamic>? _fin;
  bool _busy = false;
  bool _closed = false;
  Timer? _timeout;

  @override
  Map<String, dynamic> get view => _view;

  @override
  DateTime get viewAt => _viewAt;

  Future<Map<String, dynamic>> _call(String action, [Map<String, dynamic> more = const {}]) =>
      Online.instance.rpc('arcade', {'action': action, ...more});

  /// Commence la partie (prélève la mise). Renvoie un message d'erreur, ou null.
  Future<String?> start() async {
    try {
      final r = await _call('commencer', {'niveau': level, 'difficulte': difficulty});
      final talents = (r['talents'] as num?)?.toInt();
      if (talents != null) Online.instance.applyEnd(talents: talents);
      _fromServer(r['vue'] as Map<String, dynamic>? ?? const {});
      return null;
    } catch (e) {
      return Online.describe(e);
    }
  }

  // ---------------------------------------------------------------- Vues

  void _publish(Map<String, dynamic> v) {
    if (_closed) return;
    _view = v;
    _viewAt = DateTime.now();
    notifyListeners();
  }

  Map<String, dynamic> _base(String step, {String poser = '', int time = 0}) => {
        'etape': step,
        'mode': 'arcade',
        'difficulte': difficulty,
        'mise': _server['mise'],
        'adversaire': {'pseudo': scribe, 'present': true},
        'poseur': poser,
        'main': _server['main'] ?? const [],
        'mainAdverse': _server['mainIA'] ?? 0,
        'detruites': _server['detruites'],
        'temps': time,
      };

  /// Vue envoyée par le serveur : question de départ, à toi de poser, ou carte du Scribe.
  void _fromServer(Map<String, dynamic> v) {
    _server = v;
    final step = '${v['etape']}';
    final time = (v['temps'] as num?)?.toInt() ?? 0;
    _timeout?.cancel();
    switch (step) {
      case 'depart':
        _publish({..._base('depart', time: time), 'depart': v['depart']});
        _armTimeout(time, () => send(DuelOp.depart, {'choix': ''}));
      case 'choisir':
        _publish(_base('choisir', poser: 'moi', time: time));
        _armTimeout(time, () => send(DuelOp.jouer, {'index': -1}));
      case 'repondre':
        _publish({..._base('repondre', poser: 'adversaire', time: time), 'carte': v['carte']});
        _armTimeout(time, () => send(DuelOp.repondre, {'choix': ''}));
      case 'suite':
        _next();
      case 'finie':
        _end();
    }
  }

  /// Le serveur tient ses délais (avec une marge) ; on lui signale le temps écoulé.
  void _armTimeout(int seconds, VoidCallback onTimeout) {
    if (seconds <= 0) return;
    _timeout = Timer(Duration(seconds: seconds), onTimeout);
  }

  Future<void> _next() async {
    try {
      final r = await _call('suite');
      _fromServer(r['vue'] as Map<String, dynamic>? ?? const {});
    } catch (e) {
      _error(e);
    }
  }

  void _end() {
    final f = _fin ?? const {};
    _publish({
      ..._base('finie'),
      'fin': {
        'gagne': f['gagne'] == true,
        'raison': 'cartes',
        'gain': f['gain'] ?? 0,
        'xp': f['xp'] ?? 0,
        'etoile': f['nouvelleEtoile'] == true,
        'talents': f['talents'],
        'xpTotal': f['xpTotal'],
      },
      'revanche': {'possible': false},
    });
  }

  void _error(Object e) => _publish({..._base('annulee'), 'annulation': Online.describe(e)});

  // ---------------------------------------------------------------- Choix du joueur

  @override
  Future<void> send(int op, [Map<String, dynamic> data = const {}]) async {
    if (_busy || _closed) return;
    _busy = true;
    _timeout?.cancel();
    try {
      switch (op) {
        case DuelOp.depart:
          await _starter('${data['choix'] ?? ''}');
        case DuelOp.jouer:
          await _play((data['index'] as num?)?.toInt() ?? -1);
        case DuelOp.repondre:
          await _answer('${data['choix'] ?? ''}');
        case DuelOp.continuer:
          if ('${_server['etape']}' == 'finie') {
            _end();
          } else {
            await _next();
          }
        case DuelOp.abandonner:
          await _call('abandonner');
          _closed = true;
      }
    } catch (e) {
      _error(e);
    } finally {
      _busy = false;
    }
  }

  Future<void> _starter(String choice) async {
    final r = await _call('depart', {'choix': choice});
    if (r['nouvelle'] == true) {
      _fromServer(r['vue'] as Map<String, dynamic>? ?? const {});
      return;
    }
    _server = r['vue'] as Map<String, dynamic>? ?? _server;
    final scribeFirst = r['iaPremiere'] == true;
    _publish({
      ..._base('annonce'),
      'coup': {
        'type': 'depart',
        'parMoi': !scribeFirst,
        'juste': scribeFirst ? r['iaJuste'] == true : r['choix'] == r['bonne'],
        'jeCommence': r['commence'] == 0,
      },
    });
    await Future.delayed(const Duration(milliseconds: 2500));
    await _next();
  }

  Future<void> _play(int index) async {
    final hand = (_server['main'] as List?) ?? const [];
    final played = index >= 0 && index < hand.length ? hand[index] as Map : null;
    final r = await _call('jouer', {'index': index});
    final coup = (r['coup'] as Map?) ?? const {};
    // Le Scribe réfléchit un instant sur ta carte, puis le résultat.
    _publish({
      ..._base('repondre', poser: 'moi'),
      'carte': {...((coup['carte'] as Map?) ?? played?['carte'] ?? const {}), 'propositions': coup['presentees']},
    });
    await Future.delayed(const Duration(milliseconds: 1600));
    _server = r['vue'] as Map<String, dynamic>? ?? _server;
    _fin = r['fin'] as Map<String, dynamic>?;
    _publish({
      ..._base('resultat'),
      'coup': {
        'type': 'coup',
        'mienne': true,
        'carte': coup['carte'],
        'presentees': coup['presentees'],
        'choix': coup['choix'],
        'juste': coup['juste'] == true,
        'tempsEcoule': false,
      },
      'continuer': {'moi': false, 'adversaire': true},
    });
    _saveStars();
  }

  Future<void> _answer(String choice) async {
    final asked = (_view['carte'] as Map?) ?? const {};
    final r = await _call('repondre', {'choix': choice});
    final coup = (r['coup'] as Map?) ?? const {};
    _server = r['vue'] as Map<String, dynamic>? ?? _server;
    _fin = r['fin'] as Map<String, dynamic>?;
    _publish({
      ..._base('resultat'),
      'coup': {
        'type': 'coup',
        'mienne': false,
        // Une carte ratée reste secrète : on garde la question sans la réponse.
        'carte': coup['carte'] ?? asked,
        'presentees': asked['propositions'] ?? const [],
        'choix': coup['choix'],
        'juste': coup['juste'] == true,
        'tempsEcoule': coup['tempsEcoule'] == true,
      },
      'continuer': {'moi': false, 'adversaire': true},
    });
    _saveStars();
  }

  /// Étoiles du niveau après une victoire, gardées pour la carte d'aventure.
  void _saveStars() {
    final stars = _fin?['etoiles'];
    if (stars is! List) return;
    final all = {...Player.instance.adventureStars, '$level': stars};
    Online.instance.setAdventureStars(all);
  }

  @override
  Future<void> leave() async {
    _closed = true;
    _timeout?.cancel();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }
}
