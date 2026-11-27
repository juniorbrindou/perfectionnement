import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nakama/nakama.dart';
// ignore: implementation_imports
import 'package:nakama/src/models/response_error.dart';
import 'package:path_provider/path_provider.dart';

import '../core/pseudo.dart';
import 'player.dart';

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

  /// Même fichier que le greffon Nakama de la version Godot (user://nakama_device_id) :
  /// installée par-dessus, la version Flutter retrouve le même compte invité.
  static const deviceIdFile = 'nakama_device_id';
  static const _sessionFile = 'session.json';
  static const _cacheFile = 'compte.json';

  /// Code gRPC « déjà existant » : le pseudo tiré au sort est pris.
  static const _alreadyExists = 6;

  final Player _player = Player.instance;
  final _rng = Random();
  late final NakamaBaseClient _client =
      NakamaRestApiClient.init(host: host, serverKey: serverKey, port: port, ssl: true);

  Session? _session;
  Directory? _dir;
  Map<String, dynamic> wallet = {};
  String email = '';
  bool googleLinked = false;
  String lastError = '';
  String _breadDate = '';

  bool get isOnline => _player.connection == Connection.online;
  bool get hasAccount => email.isNotEmpty || googleLinked;
  String? get userId => _session?.userId;

  /// À appeler une fois au lancement : compte gardé, puis connexion en invité.
  Future<void> start() async {
    try {
      _dir = await getApplicationSupportDirectory();
    } catch (e) {
      debugPrint('Dossier de l’app indisponible : $e'); // Connexion quand même, sans rien garder.
    }
    await _loadCache();
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

  /// Appel d'une fonction du serveur ; renvoie sa réponse décodée.
  Future<Map<String, dynamic>> rpc(String id, [Map<String, dynamic>? payload]) async {
    if (!await _ensureSession()) throw StateError(lastError.isEmpty ? 'Pas de connexion au serveur.' : lastError);
    final r = await _client.rpc(session: _session!, id: id, payload: payload == null ? null : jsonEncode(payload));
    final data = r == null || r.isEmpty ? null : jsonDecode(r);
    return data is Map<String, dynamic> ? data : {};
  }

  /// Nouvelles étoiles de l'aventure, gardées pour le prochain lancement.
  Future<void> setAdventureStars(Map<String, List> stars) async {
    _player.update((p) => p.adventureStars = stars);
    await _saveCache();
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
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
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
      _player.update((p) {
        p.username = '${d['pseudo'] ?? ''}';
        p.xp = _int(wallet['xp']);
        p.talents = _int(wallet['talents']);
        p.rankPlace = _int(d['place']);
        p.adventureStars = (d['etoiles'] as Map?)?.map((k, v) => MapEntry('$k', v as List)) ?? {};
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

  static String _message(Object e) => switch (e) {
        ResponseError(:final code, :final message) => 'Erreur du serveur ($code) : $message',
        DioException() => 'Pas de connexion au serveur.',
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
