import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfectionnement/core/card_data.dart';
import 'package:perfectionnement/core/card_in_play.dart';
import 'package:perfectionnement/core/duel.dart';

/// Rejoue les scénarios communs tests/scenarios/*.json, que les tests du serveur
/// (server/test/run.js) rejouent aussi : les deux versions du duel doivent concorder.
void main() {
  final files = Directory('../tests/scenarios')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  test('des scénarios existent', () => expect(files, isNotEmpty));

  for (final file in files) {
    final s = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    test(s['nom'], () {
      final d = Duel(const [], const [], Random(42));
      for (var p = 0; p < 2; p++) {
        for (final c in (s['mains'] as List)[p] as List) {
          final shown = [for (final w in c['montrees'] as List) '$w'];
          final reserve = [for (final w in c['reserve'] as List) '$w'];
          final data = CardData(id: c['id'], answer: c['reponse'], wrongs: [...shown, ...reserve]);
          d.hands[p].add(CardInPlay.withState(data, shown, reserve));
        }
      }
      d.startWith(s['commence']);
      for (final coup in s['coups'] as List) {
        d.play(coup['jouer']);
        d.answer(coup['repondre']);
      }
      final expected = s['attendu'] as Map<String, dynamic>;
      expect(d.winner, expected['gagnant']);
      for (var p = 0; p < 2; p++) {
        final got = [
          for (final c in d.hands[p]) {'id': c.data.id, 'montrees': c.shownWrongs, 'reserve': c.reserve},
        ];
        expect(got, (expected['mains'] as List)[p], reason: 'main $p');
        expect([for (final c in d.destroyed[p]) c.id], (expected['detruites'] as List)[p],
            reason: 'cartes détruites $p');
      }
    });
  }
}
