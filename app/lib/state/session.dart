import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/content_filter.dart';
import '../core/local_history.dart';
import '../core/question_bank.dart';

/// Ce que les écrans partagent pendant une session : la banque de questions, les réglages
/// de la partie à deux et les illustrations disponibles.
class Session {
  static final instance = Session();

  QuestionBank? _bank;
  Set<String> _illustrations = {};

  List<String> playerNames = ['Joueur 1', 'Joueur 2'];
  ContentFilter filter = const ContentFilter.bible('lait');

  /// Cartes des dernières parties (gardé en mémoire tant que le stockage n'est pas porté).
  final LocalHistory history = LocalHistory();

  /// Banque chargée une fois ; les brouillons ne servent qu'en version de test, comme sous Godot.
  Future<QuestionBank> bank() async {
    final ready = _bank;
    if (ready != null) return ready;
    final texts = await Future.wait([
      rootBundle.loadString('data/cartes.json'),
      rootBundle.loadString('data/questions_depart.json'),
      rootBundle.loadString('data/recits.json'),
    ]);
    final server = await _serverCards();
    if (server != null) {
      texts[0] = jsonEncode(server['cartes']);
      texts[1] = jsonEncode(server['depart']);
    }
    await loadIllustrations();
    return _bank = QuestionBank.parse(
      cardsJson: texts[0],
      startersJson: texts[1],
      storiesJson: texts[2],
      // --dart-define=BROUILLONS=true : version β, tant que les cartes ne sont pas validées.
      // Les cartes du serveur sont déjà celles qu'il autorise à jouer (réglage « brouillons »).
      includeDrafts: server != null || kDebugMode || kProfileMode || const bool.fromEnvironment('BROUILLONS'),
    );
  }

  /// Lit les cartes de la partie à deux gardées sur le téléphone, ou null.
  Future<String?> Function()? readServerCards;

  /// Oublie la banque chargée : de nouvelles cartes sont arrivées.
  void reload() => _bank = null;

  Future<Map<String, dynamic>?> _serverCards() async {
    try {
      final text = await readServerCards?.call();
      if (text == null) return null;
      final d = jsonDecode(text) as Map<String, dynamic>;
      final cards = d['cartes'] as List, starters = d['depart'] as List;
      return cards.isEmpty || starters.isEmpty ? null : d;
    } catch (e) {
      debugPrint('Cartes du serveur illisibles : $e');
      return null;
    }
  }

  /// Liste des illustrations présentes : nécessaire à tout écran qui montre un livre.
  Future<void> loadIllustrations() async {
    if (_illustrations.isNotEmpty) return;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    _illustrations = {
      for (final a in manifest.listAssets())
        if (a.startsWith('assets/illustrations/') && a.endsWith('.jpg')) a,
    };
  }

  /// Illustration d'un livre (« 1 Rois » → assets/illustrations/1_rois.jpg), ou null s'il n'en a pas.
  String? illustration(List<String> books) {
    if (books.isEmpty) return null;
    final path = 'assets/illustrations/${bookSlug(books.first)}.jpg';
    return _illustrations.contains(path) ? path : null;
  }

  static String bookSlug(String book) {
    var s = book.toLowerCase();
    const pairs = {
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'à': 'a', 'â': 'a', 'î': 'i', 'ï': 'i',
      'ô': 'o', 'û': 'u', 'ù': 'u', 'ç': 'c', ' ': '_', "'": '',
    };
    pairs.forEach((a, b) => s = s.replaceAll(a, b));
    return s;
  }
}
