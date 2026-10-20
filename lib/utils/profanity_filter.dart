/// Фильтр нецензурной лексики для того, что пользователь публикует:
/// запросы помощи, отклики, имя и подпись в профиле.
///
/// Устроен просто и работает офлайн:
///  * текст приводится к «плоскому» виду — латиница, похожая на кириллицу,
///    становится русскими буквами, символы внутри слова (`х*у*й`, `xyй`)
///    убираются, повторы букв схлопываются («хуууй» → «хуй»);
///  * явные матерные корни ищутся как часть слова — так ловятся производные;
///  * неоднозначные слова («лох», «гад», «хер») сверяются целиком, чтобы
///    не ругаться на «лохматый» или «Херсон».
///
/// Русские слова сверяются по кириллической копии текста, английские —
/// по латинской, поэтому `fuck` не превращается в «фукк».
class ProfanityFilter {
  const ProfanityFilter._();

  /// Сообщение для интерфейса — одно на все формы.
  static const String message = 'Уберите недопустимые слова';

  /// Корни, которые можно искать внутри слова — они однозначны.
  static const List<String> _roots = <String>[
    // мат
    'хуй', 'хуи', 'хуе', 'хую', 'хуя',
    'пизд', 'пизж',
    'бляд', 'блят',
    'мудак', 'мудил', 'мудач',
    'гандон', 'гондон',
    'дроч',
    'шлюх', 'шлюш',
    'заеб', 'наеб', 'уеб', 'выеб', 'доеб', 'приеб', 'отъеб',
    'подъеб', 'разъеб', 'перееб', 'долбоеб', 'ебан', 'ебуч',
    // «ъ» и «ь» из текста вырезаются, поэтому формы со «съ-» и «объ-»
    // пишем как после вырезания: съебать → себат, объебать → обебат.
    'себат', 'себал', 'себут', 'себет', 'обебат', 'обебал',
    'сучк', 'пидор', 'пидар', 'педик', 'педир',
    'жоп', 'говн', 'дерьм', 'срат', 'сран', 'срал', 'засра',
    'мраз', 'твар', 'гнид',
    // английские
    'fuck', 'shit', 'bitch', 'asshole', 'cunt', 'dickhead',
    'whore', 'slut', 'bastard', 'nigg', 'retard', 'dumbass',
  ];

  /// Слова, которые нельзя искать внутри слова: сверяем целиком.
  static const List<String> _words = <String>[
    'бля', 'хер', 'херня', 'сука', 'суки', 'жопа',
    'лох', 'лохи', 'чмо', 'гад', 'гады', 'урод', 'уроды',
    'дурак', 'дура', 'дуры', 'дебил', 'дебилы', 'идиот', 'идиоты',
    'кретин', 'кретины', 'свинья', 'тупица', 'ничтожество',
    'козел', 'козлы', 'мразь', 'тварь',
    // английские
    'idiot', 'stupid', 'moron', 'dumb', 'fool', 'loser',
  ];

  /// Готовые к сверке списки: повторы букв схлопнуты так же, как в тексте.
  static final List<String> _cyrillicRoots =
      _roots.where(_isCyrillic).map(_squeeze).toList(growable: false);
  static final List<String> _latinRoots =
      _roots.where((root) => !_isCyrillic(root)).map(_squeeze).toList(growable: false);
  static final Set<String> _cyrillicWords =
      _words.where(_isCyrillic).map(_squeeze).toSet();
  static final Set<String> _latinWords =
      _words.where((word) => !_isCyrillic(word)).map(_squeeze).toSet();

  static bool _isCyrillic(String value) =>
      value.isNotEmpty && value.codeUnitAt(0) >= 0x400;

  /// Латинские буквы, которыми чаще всего подменяют кириллицу.
  static const Map<String, String> _latinToCyrillic = <String, String>{
    'a': 'а', 'b': 'в', 'c': 'с', 'e': 'е', 'h': 'н', 'k': 'к', 'm': 'м',
    'o': 'о', 'p': 'р', 't': 'т', 'u': 'и', 'x': 'х', 'y': 'у',
    '0': 'о', '3': 'з', '4': 'ч', '6': 'б', '9': 'д',
  };

  /// «Замена букв на цифры» в английских словах.
  static const Map<String, String> _leet = <String, String>{
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't',
    '8': 'b', '9': 'g', '!': 'i', '\$': 's', '@': 'a',
  };

  /// Символы внутри слова (`х*у*й`) просто вырезаем, а пробелы — это
  /// границы слов, их не трогаем: иначе «ху й» склеится в мат.
  static final RegExp _symbols = RegExp(r'[^a-zа-яё0-9\s]+');

  /// Схлопнуть повторы: «хуууй» → «хуй», «asshole» → «ashole» (корни
  /// схлопнуты так же, поэтому сравнение остаётся честным).
  static String _squeeze(String input) {
    final buffer = StringBuffer();
    String? previous;
    for (final char in input.split('')) {
      if (char != previous) buffer.write(char);
      previous = char;
    }
    return buffer.toString();
  }

  static String _flatten(String input, Map<String, String> replacements) {
    final mapped = StringBuffer();
    for (final char in input.toLowerCase().split('')) {
      mapped.write(replacements[char] ?? char);
    }
    return mapped
        .toString()
        .replaceAll('ё', 'е')
        .replaceAll('й', 'и')
        .replaceAll('ъ', '')
        .replaceAll('ь', '')
        .replaceAll(_symbols, '');
  }

  static List<String> _tokens(String flat) => flat
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(_squeeze)
      .toList(growable: false);

  /// Текст в кириллическом «плоском» виде — для проверки русских слов.
  static String normalizeCyrillic(String input) =>
      _flatten(input, _latinToCyrillic);

  /// Текст в латинском «плоском» виде — для проверки английских слов.
  static String normalizeLatin(String input) => _flatten(input, _leet);

  /// Найти недопустимое слово. null — текст чистый.
  static String? find(String text) {
    if (text.trim().isEmpty) return null;

    for (final part in _tokens(normalizeCyrillic(text))) {
      for (final root in _cyrillicRoots) {
        if (part.contains(root)) return part;
      }
      if (_cyrillicWords.contains(part)) return part;
    }

    for (final part in _tokens(normalizeLatin(text))) {
      for (final root in _latinRoots) {
        if (part.contains(root)) return part;
      }
      if (_latinWords.contains(part)) return part;
    }

    return null;
  }

  /// Есть ли в тексте недопустимые слова.
  static bool contains(String text) => find(text) != null;
}
