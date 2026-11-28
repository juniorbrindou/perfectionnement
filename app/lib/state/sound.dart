import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Effets sonores et musique de fond (PRD §9), portés de scripts/sound.gd. Les deux se coupent
/// séparément ; les choix sont gardés sur le téléphone.
///
/// Tant que [start] n'a pas été appelé (tests), tout est muet.
class Sound extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = Sound();

  static const effects = ['carte', 'tic', 'juste', 'faux', 'victoire', 'defaite', 'feu', 'tonnerre'];
  static const _music = 'sons/musique/musique_1.mp3';
  static const _musicVolume = 0.18; // La musique reste discrète sous les effets.
  static const _voices = 6;

  bool effectsOn = true;
  bool musicOn = true;

  bool _ready = false;
  bool _intro = false; // Animation de démarrage : la musique attend sa fin.
  final List<AudioPlayer> _players = [];
  AudioPlayer? _loop;
  int _next = 0;
  File? _file;

  /// À appeler une fois au lancement.
  Future<void> start() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/sons.json');
      if (await _file!.exists()) {
        final d = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        effectsOn = d['effets'] != false;
        musicOn = d['musique'] != false;
      }
      // Les effets se superposent à la musique au lieu de la couper.
      await AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
      for (var i = 0; i < _voices; i++) {
        _players.add(AudioPlayer());
      }
      _loop = AudioPlayer();
      await _loop!.setReleaseMode(ReleaseMode.loop);
      _ready = true;
      WidgetsBinding.instance.addObserver(this);
      notifyListeners();
      await _playMusic();
    } catch (e) {
      debugPrint('Sons indisponibles : $e');
    }
  }

  Future<void> play(String effect, {double volume = 0.8}) async {
    if (!_ready || !effectsOn || !effects.contains(effect)) return;
    final p = _players[_next];
    _next = (_next + 1) % _players.length;
    try {
      await p.stop();
      await p.play(AssetSource('sons/$effect.wav'), volume: volume);
    } catch (e) {
      debugPrint('Son $effect : $e');
    }
  }

  void beginIntro() {
    _intro = true;
    _loop?.stop();
  }

  void endIntro() {
    _intro = false;
    _playMusic();
  }

  void setEffects(bool on) {
    effectsOn = on;
    _save();
    notifyListeners();
    if (on) play('juste');
  }

  void setMusic(bool on) {
    musicOn = on;
    _save();
    notifyListeners();
    if (on) {
      _playMusic();
    } else {
      _loop?.stop();
    }
  }

  Future<void> _playMusic() async {
    if (!_ready || !musicOn || _intro) return;
    try {
      await _loop!.play(AssetSource(_music), volume: _musicVolume);
    } catch (e) {
      debugPrint('Musique : $e');
    }
  }

  /// Rien ne joue quand le jeu est en arrière-plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _loop?.pause();
    } else if (state == AppLifecycleState.resumed && musicOn && !_intro) {
      _loop?.resume();
    }
  }

  Future<void> _save() async {
    try {
      await _file?.writeAsString(jsonEncode({'effets': effectsOn, 'musique': musicOn}), flush: true);
    } catch (e) {
      debugPrint('Réglages du son : $e');
    }
  }
}
