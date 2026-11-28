import '../core/adventure.dart';
import 'online.dart';
import 'player.dart';

/// Une question de l'Aventure telle que le serveur l'envoie : sans sa réponse.
class QuizQuestion {
  final int number;
  final int total;
  final int correct;
  final String text;
  final String category;
  final List<String> options;
  final int seconds;

  const QuizQuestion(this.number, this.total, this.correct, this.text, this.category, this.options, this.seconds);

  factory QuizQuestion.fromJson(Map d) => QuizQuestion(
        _int(d['numero']),
        _int(d['total']),
        _int(d['bonnes']),
        '${d['question'] ?? ''}',
        '${d['category'] ?? ''}',
        [for (final p in (d['propositions'] as List? ?? const [])) '$p'],
        _int(d['temps']),
      );
}

/// Résultat d'une réponse : la bonne réponse et de quoi apprendre.
class QuizAnswer {
  final bool correct;
  final bool timedOut;
  final String choice;
  final String answer;
  final String reference;
  final String explanation;
  final int score;
  final QuizEnd? end;

  const QuizAnswer(this.correct, this.timedOut, this.choice, this.answer, this.reference, this.explanation, this.score, this.end);
}

/// Fin de partie : étoiles obtenues, meilleur résultat gardé, gains.
class QuizEnd {
  final int correct;
  final int total;
  final int stars;
  final int best;
  final int newStars;
  final int xp;
  final int talents;
  final int levelBefore;
  final int levelAfter;

  const QuizEnd(this.correct, this.total, this.stars, this.best, this.newStars, this.xp, this.talents, this.levelBefore,
      this.levelAfter);
}

/// Une partie d'Aventure, tenue par le serveur (RPC « aventure », server/src/aventure.ts).
class Quiz {
  final int level;
  final String difficulty;

  Quiz(this.level, this.difficulty);

  Future<Map<String, dynamic>> _call(String action, [Map<String, dynamic> more = const {}]) =>
      Online.instance.rpc('aventure', {'action': action, ...more});

  /// Progression et nombre de questions par étape, depuis le serveur.
  static Future<({AdventureStars stars, Map questions})> state() async {
    final r = await Online.instance.rpc('aventure', {'action': 'etat'});
    final stars = Adventure.parse(r['etoiles']);
    await Online.instance.setAdventureStars(stars);
    return (stars: stars, questions: (r['questions'] as Map?) ?? const {});
  }

  Future<QuizQuestion> start() async =>
      QuizQuestion.fromJson((await _call('commencer', {'niveau': level, 'difficulte': difficulty}))['question'] as Map);

  Future<QuizQuestion> next() async => QuizQuestion.fromJson((await _call('question'))['question'] as Map);

  /// Répond ("" : temps écoulé).
  Future<QuizAnswer> answer(String choice) async {
    final r = await _call('repondre', {'choix': choice});
    final f = r['fin'] as Map?;
    QuizEnd? end;
    if (f != null) {
      end = QuizEnd(_int(f['bonnes']), _int(f['total']), _int(f['etoiles']), _int(f['meilleur']), _int(f['nouvelles']),
          _int(f['xp']), _int(f['talents']), _int(f['niveauAvant']), _int(f['niveau']));
      Online.instance.applyEnd(talents: _int(f['talentsTotal']), xp: _int(f['xpTotal']));
      await Online.instance.setAdventureStars(Adventure.parse(f['progression']));
    }
    return QuizAnswer(r['juste'] == true, r['tempsEcoule'] == true, '${r['choix'] ?? ''}', '${r['bonne'] ?? ''}',
        '${r['reference'] ?? ''}', '${r['explication'] ?? ''}', _int(r['bonnes']), end);
  }

  Future<void> quit() async {
    try {
      await _call('abandonner');
    } catch (_) {}
  }

  static AdventureStars get stars => Player.instance.adventureStars;
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
