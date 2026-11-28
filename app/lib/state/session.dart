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
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    _illustrations = {
      for (final a in manifest.listAssets())
        if (a.startsWith('assets/illustrations/') && a.endsWith('.jpg')) a,
    };
    return _bank = QuestionBank.parse(
      cardsJson: texts[0],
      startersJson: texts[1],
      storiesJson: texts[2],
      // --dart-define=BROUILLONS=true : version β, tant que les cartes ne sont pas validées.
      includeDrafts: kDebugMode || kProfileMode || const bool.fromEnvironment('BROUILLONS'),
    );
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
