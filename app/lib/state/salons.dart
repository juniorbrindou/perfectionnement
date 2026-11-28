import 'online.dart';

/// Un salon tel que le serveur le décrit (server/src/salons.ts).
class SalonInfo {
  final String id;
  final String name;
  final String motto;
  final int color;
  final String theme;
  final String difficulty;
  final String contentType;
  final List<String> contentValues;
  final int members;
  final int max;
  final String shepherd;
  final List<String> preview;

  // Fiche seulement.
  final int stake;
  final List<SalonRank> ranking;
  final bool member;
  final bool isShepherd;
  final bool requested;
  final bool otherSalon;
  final List<SalonRequest> requests;

  const SalonInfo({
    required this.id,
    required this.name,
    this.motto = '',
    this.color = 0,
    this.theme = 'fete',
    this.difficulty = 'lait',
    this.contentType = 'bible',
    this.contentValues = const [],
    this.members = 0,
    this.max = 50,
    this.shepherd = '',
    this.preview = const [],
    this.stake = 0,
    this.ranking = const [],
    this.member = false,
    this.isShepherd = false,
    this.requested = false,
    this.otherSalon = false,
    this.requests = const [],
  });

  factory SalonInfo.fromJson(Map<String, dynamic> d) {
    final c = (d['contenu'] as Map?) ?? const {};
    return SalonInfo(
      id: '${d['id'] ?? ''}',
      name: '${d['nom'] ?? ''}',
      motto: '${d['devise'] ?? ''}',
      color: _int(d['couleur']),
      theme: '${d['theme'] ?? 'fete'}',
      difficulty: '${d['difficulte'] ?? 'lait'}',
      contentType: '${c['type'] ?? 'bible'}',
      contentValues: [for (final v in (c['valeurs'] as List? ?? const [])) '$v'],
      members: _int(d['membres']),
      max: _int(d['max'], 50),
      shepherd: '${d['berger'] ?? ''}',
      preview: [for (final v in (d['apercu'] as List? ?? const [])) '$v'],
      stake: _int(d['mise']),
      ranking: [
        for (final r in (d['classement'] as List? ?? const []))
          SalonRank('${r['pseudo']}', _int(r['score']), [for (final x in (r['roles'] as List? ?? const [])) '$x'], r['moi'] == true),
      ],
      member: d['membre'] == true,
      isShepherd: d['estBerger'] == true,
      requested: d['demandeEnvoyee'] == true,
      otherSalon: d['autreSalon'] == true,
      requests: [
        for (final r in (d['demandes'] as List? ?? const []))
          SalonRequest('${r['joueur']}', '${r['pseudo']}', _int(r['niveau']), _int(r['quand'])),
      ],
    );
  }

  /// « Psaumes, Proverbes », « Ancien Testament », « Toute la Bible »…
  String get contentLabel => switch (contentType) {
        'testament' => contentValues.map((t) => t == 'AT' ? 'Ancien Testament' : 'Nouveau Testament').join(', '),
        'livres' => contentValues.join(', '),
        'categorie' => contentValues.map((c) => _categories[c] ?? c).join(', '),
        _ => 'Toute la Bible',
      };

  String get difficultyLabel => _difficulties[difficulty] ?? difficulty;
  bool get full => members >= max;
}

class SalonRank {
  final String name;
  final int score;
  final List<String> roles;
  final bool me;

  const SalonRank(this.name, this.score, this.roles, this.me);

  String get roleLabel => [
        if (roles.contains('berger')) 'Berger',
        if (roles.contains('heros')) 'Vaillant héros',
        if (roles.contains('sentinelle')) 'Sentinelle',
      ].join(' · ');
}

class SalonRequest {
  final String player;
  final String name;
  final int level;
  final int when;

  const SalonRequest(this.player, this.name, this.level, this.when);
}

const _difficulties = {'lait': 'Lait', 'manne': 'Manne', 'solide': 'Solide'};
const _categories = {
  'personnages': 'Personnages',
  'miracles': 'Miracles',
  'paraboles': 'Paraboles',
  'lieux_evenements': 'Lieux et événements',
  'structure': 'Structure de la Bible',
};

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

/// Appels au serveur pour les salons.
abstract final class Salons {
  static Future<Map<String, dynamic>> _call(String action, [Map<String, dynamic> more = const {}]) =>
      Online.instance.rpc('salon', {'action': action, ...more});

  static Future<({List<SalonInfo> salons, String mine, String request})> list({String search = '', String? difficulty}) async {
    final r = await _call('lister', {'recherche': search, 'difficulte': ?difficulty});
    return (
      salons: [for (final s in (r['salons'] as List? ?? const [])) SalonInfo.fromJson(s as Map<String, dynamic>)],
      mine: '${r['monSalon'] ?? ''}',
      request: '${r['maDemande'] ?? ''}',
    );
  }

  static Future<SalonInfo> view(String id) async => SalonInfo.fromJson(await _call('voir', {'id': id}));
  static Future<SalonInfo> request(String id) async => SalonInfo.fromJson(await _call('demander', {'id': id}));
  static Future<void> cancelRequest() => _call('annuler_demande');
  static Future<void> leave() => _call('quitter');

  static Future<SalonInfo> answer(String id, String player, bool accept) async =>
      SalonInfo.fromJson(await _call('repondre', {'id': id, 'joueur': player, 'accepte': accept}));

  /// Seuils et nombre de questions par critère, pour la création.
  static Future<Map<String, dynamic>> options() => _call('options');

  static Future<SalonInfo> create({
    required String name,
    required String motto,
    required int color,
    required String theme,
    required String difficulty,
    required String contentType,
    required List<String> contentValues,
  }) async =>
      SalonInfo.fromJson(await _call('creer', {
        'nom': name,
        'devise': motto,
        'couleur': color,
        'theme': theme,
        'difficulte': difficulty,
        'contenu': {'type': contentType, 'valeurs': contentValues},
      }));
}
