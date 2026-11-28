import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nakama/nakama.dart';
// ignore: implementation_imports
import 'package:nakama/src/models/response_error.dart';
import 'package:path_provider/path_provider.dart';

import '../core/adventure.dart';
import '../core/pseudo.dart';
import 'player.dart';
import 'reglages.dart';
import 'session.dart' as game;

/// Connexion au serveur Nakama (docs/SERVEUR.md), portée de scripts/online.gd.
///
/// Au lancement, le joueur est connecté en invité, sans rien saisir : identifiant de
/// l'appareil et pseudo lisible tiré au sort. La session est gardée sur le téléphone et
/// rafraîchie avant expiration. Les dernières infos du compte sont gardées aussi, pour
/// s'afficher dès le lancement et hors ligne.
class Online {
  static final instance = Online();

  static const serverKey = '09a9f6f81f2ea5533b3c0cdb';
  static const host = 'brindoujunior.com';
  static const port = 443;
  static const leaderboardId = 'xp';

  /// Identifiant OAuth « Application Web » (public, il est dans chaque APK) : l'audience des
  /// jetons Google que le serveur accepte.
  static const googleWebClientId = '492954893860-3abik9silaiiea1toaf5nt473dj9bc1d.apps.googleusercontent.com';

  /// Même fichier que le greffon Nakama de la version Godot (user://nakama_device_id) :
  /// installée par-dessus, la version Flutter retrouve le même compte invité.
  static const deviceIdFile = 'nakama_device_id';
  static const _sessionFile = 'session.json';
  static const _cacheFile = 'compte.json';
  static const _phoneCardsFile = 'cartes_telephone.json';

  /// Code gRPC « déjà existant » : le pseudo tiré au sort est pris.
  static const _alreadyExists = 6;
  static const _notFound = 5;
  static const _unauthenticated = 16;

  final Player _player = Player.instance;
  final _rng = Random();
  late final NakamaBaseClient _client = NakamaRestApiClient.init(
    host: host,
    serverKey: serverKey,
    port: port,
    ssl: true,
  );

  Session? _session;
  Directory? _dir;
  Map<String, dynamic> wallet = {};
  String email = '';
  bool googleLinked = false;
  String lastError = '';
  String _breadDate = '';
  bool _googleReady = false;

  bool get isOnline => _player.connection == Connection.online;
  bool get hasAccount => email.isNotEmpty || googleLinked;
  String? get userId => _session?.userId;

  /// Jeton de session valide (rafraîchi si besoin), pour la connexion temps réel ; null hors ligne.
  Future<String?> sessionToken() async => await _ensureSession() ? _session?.token : null;

  /// Talents et XP reçus en fin de partie, sans relire le compte.
  void applyEnd({int? talents, int? xp}) {
    if (talents != null) wallet['talents'] = talents;
    if (xp != null) wallet['xp'] = xp;
    _player.update((p) {
      if (talents != null) p.talents = talents;
      if (xp != null) p.xp = xp;
    });
    _saveCache();
  }

  /// À appeler une fois au lancement : compte gardé, puis connexion en invité.
  Future<void> start() async {
    try {
      _dir = await getApplicationSupportDirectory();
    } catch (e) {
      debugPrint('Dossier de l’app indisponible : $e'); // Connexion quand même, sans rien garder.
    }
    await _loadCache();
    game.Session.instance.readServerCards = () => _read(_phoneCardsFile);
    await connectGuest();
  }

  /// Connexion en invité : session gardée si possible, sinon authentification par appareil.
  Future<bool> connectGuest() async {
    _setConnection(Connection.connecting);
    try {
      _session = await _restoreSession();
      if (_session == null) {
        final id = await _deviceId();
        for (var attempt = 0; attempt < 5 && _session == null; attempt++) {
          try {
            _session = await _client.authenticateDevice(deviceId: id, create: true, username: Pseudo.generate(_rng));
          } on ResponseError catch (e) {
            if (e.code != _alreadyExists) rethrow; // Sinon le pseudo est pris : on en tire un autre.
          }
        }
      }
      if (_session == null) return _fail(null);
      await _saveSession();
      await refreshAccount();
      _setConnection(Connection.online);
      unawaited(loadReglages());
      unawaited(loadPhoneCards());
      unawaited(claimBread());
      return true;
    } catch (e) {
      return _fail(e);
    }
  }

  /// Relit le compte : pseudo, e-mail, Google, portefeuille, place au classement.
  Future<bool> refreshAccount() async {
    if (!await _ensureSession()) return false;
    try {
      final acc = await _client.getAccount(_session!);
      email = acc.email ?? '';
      googleLinked = (acc.user.googleId ?? '').isNotEmpty;
      final parsed = acc.wallet == null || acc.wallet!.isEmpty ? null : jsonDecode(acc.wallet!);
      wallet = parsed is Map<String, dynamic> ? parsed : {};
      final place = await _rankPlace();
      _player.update((p) {
        p.username = acc.user.username ?? '';
        p.xp = _int(wallet['xp']);
        p.talents = _int(wallet['talents']);
        if (place != null) p.rankPlace = place;
      });
      await _saveCache();
      return true;
    } catch (e) {
      return _fail(e);
    }
  }

  /// Place du joueur au classement général (0 : pas classé), ou null en cas d'erreur.
  Future<int?> _rankPlace() async {
    try {
      final r = await _client.listLeaderboardRecords(
        session: _session!,
        leaderboardName: leaderboardId,
        ownerIds: [_session!.userId],
        limit: 1,
      );
      return r.ownerRecords.isEmpty ? 0 : r.ownerRecords.first.rank;
    } catch (_) {
      return null;
    }
  }

  /// Classement général : les [limit] premiers et ta propre ligne, ou null hors ligne.
  Future<({List<RankRow> top, RankRow? me})?> leaderboard({int limit = 50}) async {
    if (!await _ensureSession()) return null;
    try {
      final r = await _client.listLeaderboardRecords(
        session: _session!,
        leaderboardName: leaderboardId,
        ownerIds: [_session!.userId],
        limit: limit,
      );
      RankRow row(LeaderboardRecord rec) =>
          RankRow(rec.rank, rec.username ?? '', rec.score, rec.ownerId == _session!.userId);
      final me = r.ownerRecords.isEmpty ? null : row(r.ownerRecords.first);
      final place = me?.place ?? 0;
      if (place != _player.rankPlace) {
        _player.update((p) => p.rankPlace = place);
        await _saveCache();
      }
      return (top: [for (final rec in r.records) row(rec)], me: me);
    } catch (e) {
      lastError = _message(e);
      return null;
    }
  }

  /// Pain quotidien : +10 talents une fois par jour, décidé par le serveur.
  Future<void> claimBread() async {
    if (!await _ensureSession()) return;
    try {
      final payload = await _client.rpc(session: _session!, id: 'pain_quotidien');
      final data = payload == null ? null : jsonDecode(payload);
      if (data is! Map) return;
      _breadDate = _today();
      final granted = data['accorde'] == true;
      if (granted) wallet['talents'] = _int(data['talents'] ?? wallet['talents']);
      _player.update((p) {
        p.breadToday = true;
        if (granted) {
          p.talents = _int(wallet['talents']);
          p.breadGain = _int(data['gain']);
        }
      });
      await _saveCache();
    } catch (e) {
      debugPrint('Pain quotidien : ${_message(e)}');
    }
  }

  /// Cartes de la partie à deux (back-office), gardées pour jouer hors ligne.
  Future<void> loadPhoneCards() async {
    try {
      final data = await rpc('cartes_telephone');
      if ((data['cartes'] as List?)?.isEmpty ?? true) return;
      await _write(_phoneCardsFile, jsonEncode(data));
      game.Session.instance.reload();
    } catch (e) {
      debugPrint('Cartes : ${_message(e)}');
    }
  }

  /// Réglages du jeu en vigueur (back-office), gardés pour le prochain lancement.
  Future<void> loadReglages() async {
    try {
      Reglages.instance.appliquer(await rpc('reglages'));
      await _saveCache();
    } catch (e) {
      debugPrint('Réglages : ${_message(e)}');
    }
  }

  /// Appel d'une fonction du serveur ; renvoie sa réponse décodée.
  Future<Map<String, dynamic>> rpc(String id, [Map<String, dynamic>? payload]) async {
    if (!await _ensureSession()) throw StateError(lastError.isEmpty ? 'Pas de connexion au serveur.' : lastError);
    final r = await _client.rpc(session: _session!, id: id, payload: payload == null ? null : jsonEncode(payload));
    final data = r == null || r.isEmpty ? null : jsonDecode(r);
    return data is Map<String, dynamic> ? data : {};
  }

  /// Nouvelles étoiles de l'aventure, gardées pour le prochain lancement.
  Future<void> setAdventureStars(AdventureStars stars) async {
    _player.update((p) => p.adventureStars = stars);
    await _saveCache();
  }

  // ---------------------------------------------------------------- Compte
  // Chaque fonction renvoie un message d'erreur à afficher, ou null si c'est fait.

  /// Change le pseudo.
  Future<String?> changeUsername(String name) async {
    final problem = Pseudo.problem(name);
    if (problem != null) return problem;
    if (!await _ensureSession()) return 'Pas de connexion au serveur.';
    try {
      await _client.updateAccount(session: _session!, username: name.trim());
    } catch (e) {
      // Nakama ne renvoie pas ici le code « déjà existant » : seul le texte le dit.
      final message = _message(e);
      return message.contains('already in use') ? 'Ce pseudo est déjà pris.' : message;
    }
    await refreshAccount();
    return null;
  }

  /// Rattache une adresse e-mail au compte invité : pseudo, talents et XP sont conservés.
  Future<String?> linkEmail(String address, String password) async {
    if (!address.contains('@')) return 'Cette adresse e-mail n’est pas valide.';
    if (password.length < 8) return 'Le mot de passe doit faire au moins 8 caractères.';
    if (!await _ensureSession()) return 'Pas de connexion au serveur.';
    try {
      await _client.linkEmail(session: _session!, email: address.trim(), password: password);
    } on ResponseError catch (e) {
      return e.code == _alreadyExists ? 'Cette adresse est déjà utilisée par un autre compte.' : _message(e);
    } catch (e) {
      return _message(e);
    }
    await refreshAccount();
    return null;
  }

  /// Retrouve un compte e-mail existant (nouveau téléphone). Ne crée jamais de compte.
  Future<String?> loginEmail(String address, String password) async {
    if (address.trim().isEmpty || password.isEmpty) return 'Saisis ton adresse et ton mot de passe.';
    try {
      await _adopt(await _client.authenticateEmail(email: address.trim(), password: password, create: false));
      return null;
    } on ResponseError catch (e) {
      return e.code == _notFound || e.code == _unauthenticated ? 'Adresse ou mot de passe incorrect.' : _message(e);
    } catch (e) {
      return _message(e);
    }
  }

  /// Connexion Google : le compte invité du téléphone est rattaché à Google. Si ce compte
  /// Google a déjà son compte de jeu, on bascule dessus (cas d'un nouveau téléphone).
  Future<String?> signInGoogle() async {
    final String token;
    try {
      final google = GoogleSignIn.instance;
      if (!_googleReady) {
        await google.initialize(serverClientId: googleWebClientId);
        _googleReady = true;
      }
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      await google.signOut(); // Le choix du compte reste proposé la prochaine fois.
      if (idToken == null) return 'Google n’a pas renvoyé de jeton.';
      token = idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return 'Connexion Google annulée.';
      return 'Connexion Google impossible : ${e.description ?? e.code.name}';
    } catch (e) {
      return 'Connexion Google impossible sur cet appareil.';
    }
    try {
      if (await _ensureSession()) {
        try {
          await _client.linkGoogle(session: _session!, token: token);
          await refreshAccount();
          return null;
        } on ResponseError catch (e) {
          if (e.code != _alreadyExists) rethrow;
        }
      }
      await _adopt(await _client.authenticateGoogle(token: token, create: false));
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  /// Bascule sur un autre compte : rien de l'ancien ne doit rester affiché.
  Future<void> _adopt(Session session) async {
    _session = session;
    await _saveSession();
    wallet = {};
    email = '';
    googleLinked = false;
    _breadDate = '';
    _player.update((p) {
      p.username = '';
      p.xp = 0;
      p.talents = 0;
      p.rankPlace = 0;
      p.adventureStars = {};
      p.breadToday = false;
      p.breadGain = 0;
    });
    await refreshAccount();
    _setConnection(Connection.online);
    unawaited(claimBread());
  }

  // ---------------------------------------------------------------- Session

  Future<bool> _ensureSession() async {
    final s = _session;
    if (s == null) return false;
    final soon = DateTime.now().add(const Duration(minutes: 5));
    if (!s.hasExpired(soon)) return true;
    if (s.hasRefreshExpired(DateTime.now())) return connectGuest();
    try {
      _session = await _client.sessionRefresh(session: s);
      await _saveSession();
      return true;
    } catch (_) {
      return connectGuest();
    }
  }

  Future<Session?> _restoreSession() async {
    final text = await _read(_sessionFile);
    if (text == null) return null;
    try {
      final d = jsonDecode(text) as Map<String, dynamic>;
      final s = Session.restore(token: '${d['token']}', refreshToken: '${d['refresh_token']}');
      final now = DateTime.now();
      if (s == null || s.hasRefreshExpired(now)) return null;
      if (s.hasExpired(now.add(const Duration(minutes: 5)))) return await _client.sessionRefresh(session: s);
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSession() async {
    final s = _session;
    if (s == null) return;
    await _write(_sessionFile, jsonEncode({'token': s.token, 'refresh_token': s.refreshToken}));
  }

  /// Identifiant de l'appareil : celui de la version Godot s'il existe, sinon un nouveau.
  Future<String> _deviceId() async {
    final stored = (await _read(deviceIdFile))?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final b = List.generate(16, (_) => Random.secure().nextInt(256));
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
    await _write(deviceIdFile, id);
    return id;
  }

  // ---------------------------------------------------------------- Compte gardé

  Future<void> _loadCache() async {
    final text = await _read(_cacheFile);
    if (text == null) return;
    try {
      final d = jsonDecode(text) as Map<String, dynamic>;
      email = '${d['email'] ?? ''}';
      googleLinked = d['google'] == true;
      wallet = (d['portefeuille'] as Map?)?.cast<String, dynamic>() ?? {};
      _breadDate = '${d['pain'] ?? ''}';
      Reglages.instance.appliquer((d['reglages'] as Map?)?.cast<String, dynamic>() ?? const {});
      _player.update((p) {
        p.username = '${d['pseudo'] ?? ''}';
        p.xp = _int(wallet['xp']);
        p.talents = _int(wallet['talents']);
        p.rankPlace = _int(d['place']);
        p.adventureStars = Adventure.parse(d['etoiles']);
        p.breadToday = _breadDate == _today();
      });
    } catch (_) {
      // Cache illisible : il sera réécrit à la prochaine connexion.
    }
  }

  Future<void> _saveCache() async {
    if (_player.username.isEmpty) return;
    await _write(
      _cacheFile,
      jsonEncode({
        'pseudo': _player.username,
        'email': email,
        'google': googleLinked,
        'portefeuille': wallet,
        'place': _player.rankPlace,
        'etoiles': _player.adventureStars,
        'pain': _breadDate,
        'reglages': Reglages.instance.valeurs,
      }),
    );
  }

  // ---------------------------------------------------------------- Outils

  Future<String?> _read(String name) async {
    final dir = _dir;
    if (dir == null) return null;
    final f = File('${dir.path}/$name');
    return await f.exists() ? f.readAsString() : null;
  }

  Future<void> _write(String name, String text) async {
    final dir = _dir;
    if (dir == null) return;
    await File('${dir.path}/$name').writeAsString(text, flush: true);
  }

  void _setConnection(Connection c) {
    if (_player.connection != c) _player.update((p) => p.connection = c);
  }

  bool _fail(Object? e) {
    lastError = e == null ? 'Connexion impossible.' : _message(e);
    debugPrint('Nakama : $lastError');
    _setConnection(Connection.offline);
    return false;
  }

  /// Message lisible d’une erreur du serveur.
  static String describe(Object e) => _message(e);

  static String _message(Object e) => switch (e) {
    ResponseError(:final message) when (message ?? '').isNotEmpty => message!,
    ResponseError(:final code) => 'Erreur du serveur ($code).',
    DioException() => 'Pas de connexion au serveur.',
    StateError(:final message) => message,
    _ => '$e',
  };

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}

/// Une ligne du classement.
class RankRow {
  final int place;
  final String name;
  final int xp;
  final bool me;

  const RankRow(this.place, this.name, this.xp, this.me);
}
