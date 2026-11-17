// Чистка текста с сайта: одна функция для парсера, поиска и новостей.
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/utils/text_normalize.dart';

void main() {
  test('схлопывает пробелы и убирает неразрывные', () {
    expect(
      normalizeSpaces('  ауд.\u00a0 6-12 ,\n корпус  '),
      'ауд. 6-12 , корпус',
    );
  });

  test('пустая строка остаётся пустой', () {
    expect(normalizeSpaces('   '), '');
  });

  test('не трогает обычный текст', () {
    expect(normalizeSpaces('8:30 - 10:05'), '8:30 - 10:05');
  });
}
