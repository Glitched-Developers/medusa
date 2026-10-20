// Проверка фильтра лексики: что должно ловиться, а что — нет.
// Запуск: dart run tool/check_profanity.dart
import 'package:medusa/utils/profanity_filter.dart';

void main() {
  const bad = <String>[
    'ты дурак',
    'хуй',
    'Х*У*Й',
    'xyй',
    'пиздец',
    'блядь',
    'заебал',
    'иди нахуй',
    'ДЕБИЛ',
    'fuck you',
    'you are an asshole',
    'sh1t',
    'мразь',
    'долбоёб',
  ];

  const good = <String>[
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

  var failures = 0;
  for (final text in bad) {
    final found = ProfanityFilter.find(text);
    final ok = found != null;
    if (!ok) failures++;
    print('${ok ? 'OK  ' : 'ПРОПУСТИЛ'} | $text');
  }
  for (final text in good) {
    final found = ProfanityFilter.find(text);
    final ok = found == null;
    if (!ok) failures++;
    print('${ok ? 'OK  ' : 'ЛОЖНОЕ  '} | $text -> $found');
  }
  print(failures == 0 ? 'Все проверки пройдены' : 'Ошибок: $failures');
}
