import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/utils/profanity_filter.dart';

void main() {
  group('фильтр ловит оскорбления', () {
    const dirty = <String>[
      'ты дурак',
      'хуй',
      'Х*У*Й',
      'xyй',
      'пиздец',
      'блядь',
      'заебал',
      'долбоёб',
      'ты мразь',
      'fuck you',
      'you are an asshole',
      'sh1t',
    ];

    for (final text in dirty) {
      test('«$text»', () {
        expect(ProfanityFilter.contains(text), isTrue);
      });
    }
  });

  group('обычные слова не задевает', () {
    const clean = <String>[
      'Иванов Иван',
      'Перетащить вещи в ауд. 213',
      'хлебать суп',
      'дебаты',
      'стратегия',
      'гребать сено',
      'урожай собрали',
      'Херсон',
      'бляшка на двери',
      'лохматый кот',
      'гадание на картах',
      'сукно для пальто',
      'класс',
      'group 90002493',
      'Помогите донести документы',
    ];

    for (final text in clean) {
      test('«$text»', () {
        expect(ProfanityFilter.find(text), isNull);
      });
    }
  });
}
