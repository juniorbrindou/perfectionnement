import 'package:perfectionnement/core/card_data.dart';

CardData makeCard(String id, {String difficulty = 'lait', String testament = 'NT', List<String>? books}) =>
    CardData(
      id: id,
      difficulty: difficulty,
      testament: testament,
      books: books ?? const ['Matthieu'],
      category: 'personnages',
      question: 'Q $id',
      answer: 'bonne',
      wrongs: const ['f1', 'f2', 'f3', 'f4', 'f5'],
      reference: 'Matthieu 1:1',
      story: 'test',
      status: 'valide',
    );

List<CardData> makeHand(String prefix, [int count = 5]) =>
    [for (var i = 0; i < count; i++) makeCard('$prefix$i')];
