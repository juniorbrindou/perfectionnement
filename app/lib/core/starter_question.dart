import 'dart:math';

import 'card_data.dart';
import 'rand.dart';

/// Question de départ (data/questions_depart.json) : facile, 5 propositions.
class StarterQuestion {
  static const wrongCount = 4;

  final String id;
  final String question;
  final String answer;
  final List<String> wrongs;
  final String reference;
  final String status;

  const StarterQuestion({
    required this.id,
    required this.question,
    required this.answer,
    required this.wrongs,
    this.reference = '',
    this.status = 'brouillon',
  });

  factory StarterQuestion.fromJson(Map<String, dynamic> d) => StarterQuestion(
        id: '${d['id'] ?? ''}',
        question: '${d['question'] ?? ''}',
        answer: '${d['answer'] ?? ''}',
        wrongs: [for (final w in (d['wrongs'] as List? ?? const [])) '$w'],
        reference: '${d['reference'] ?? ''}',
        status: '${d['status'] ?? 'brouillon'}',
      );

  bool get isValidated => status == 'valide';

  List<String> problems() {
    final errors = <String>[];
    if (id.isEmpty || question.isEmpty || answer.isEmpty || reference.isEmpty) {
      errors.add('champ manquant');
    }
    if (wrongs.length != wrongCount) {
      errors.add('${wrongs.length} fausses réponses au lieu de $wrongCount');
    }
    errors.addAll(duplicateProblems(answer, wrongs));
    return errors;
  }
}

/// Question de départ posée aux deux joueurs (PRD §2.4).
/// Le premier qui répond décide : juste → il commence ; faux → l'autre commence.
class StarterRound {
  final StarterQuestion question;
  final List<String> options;

  StarterRound(this.question, Random rng) : options = [question.answer, ...question.wrongs] {
    shuffleWith(options, rng);
  }

  /// Renvoie le joueur qui commence.
  int resolve(int player, String choice) => choice == question.answer ? player : 1 - player;
}
