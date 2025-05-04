import 'package:flex_color_scheme/flex_color_scheme.dart';

/// Утилитарный класс для преобразования технических названий тем
/// в удобочитаемые названия для пользователей
class ThemeMapper {
  /// Возвращает понятные пользователю названия тем на русском языке
  static String getDisplayName(FlexScheme scheme) {
    switch (scheme) {
      case FlexScheme.material:
        return 'Материал';
      case FlexScheme.materialHc:
        return 'Материал (высокий контраст)';
      case FlexScheme.blue:
        return 'Синяя';
      case FlexScheme.indigo:
        return 'Индиго';
      case FlexScheme.hippieBlue:
        return 'Лазурная';
      case FlexScheme.bahamaBlue:
        return 'Багама Блю';
      case FlexScheme.aquaBlue:
        return 'Аква';
      case FlexScheme.brandBlue:
        return 'Фирменная синяя';
      case FlexScheme.deepBlue:
        return 'Глубокая синяя';
      case FlexScheme.sakura:
        return 'Сакура';
      case FlexScheme.mandyRed:
        return 'Алая';
      case FlexScheme.red:
        return 'Красная';
      case FlexScheme.redWine:
        return 'Бордовая';
      case FlexScheme.purpleBrown:
        return 'Пурпурно-коричневая';
      case FlexScheme.green:
        return 'Зелёная';
      case FlexScheme.money:
        return 'Мятная';
      case FlexScheme.jungle:
        return 'Джунгли';
      case FlexScheme.greyLaw:
        return 'Серая';
      case FlexScheme.gold:
        return 'Золотая';
      case FlexScheme.mango:
        return 'Манго';
      case FlexScheme.amber:
        return 'Янтарная';
      case FlexScheme.vesuviusBurn:
        return 'Вулканическая';
      case FlexScheme.deepPurple:
        return 'Глубокая пурпурная';
      case FlexScheme.ebonyClay:
        return 'Чёрный камень';
      case FlexScheme.barossa:
        return 'Бароссо';
      case FlexScheme.mallardGreen:
        return 'Малахитовая';
      case FlexScheme.espresso:
        return 'Эспрессо';
      case FlexScheme.outerSpace:
        return 'Космическая';
      case FlexScheme.blueWhale:
        return 'Синий кит';
      case FlexScheme.sanJuanBlue:
        return 'Сан-Хуан';
      case FlexScheme.rosewood:
        return 'Розовое дерево';
      case FlexScheme.blumineBlue:
        return 'Лазурно-синяя';
      case FlexScheme.materialBaseline:
        return 'Базовый материал';
      case FlexScheme.verdunHemlock:
        return 'Тёмно-зелёная';
      case FlexScheme.dellGenoa:
        return 'Генуя';
      case FlexScheme.redM3:
        return 'Красная M3';
      case FlexScheme.pinkM3:
        return 'Розовая M3';
      case FlexScheme.purpleM3:
        return 'Фиолетовая M3';
      case FlexScheme.indigoM3:
        return 'Индиго M3';
      case FlexScheme.blueM3:
        return 'Синяя M3';
      case FlexScheme.cyanM3:
        return 'Бирюзовая M3';
      case FlexScheme.tealM3:
        return 'Изумрудная M3';
      case FlexScheme.greenM3:
        return 'Зелёная M3';
      case FlexScheme.limeM3:
        return 'Лаймовая M3';
      case FlexScheme.yellowM3:
        return 'Жёлтая M3';
      case FlexScheme.orangeM3:
        return 'Оранжевая M3';
      case FlexScheme.deepOrangeM3:
        return 'Тёмно-оранжевая M3';
      case FlexScheme.wasabi:
        return 'Васаби';
      case FlexScheme.shark:
        return 'Акула';
      case FlexScheme.bigStone:
        return 'Большой камень';
      case FlexScheme.damask:
        return 'Дамаск';
      case FlexScheme.flutterDash:
        return 'Флютер';
      case FlexScheme.blackWhite:
        return 'Чёрно-белая';
      case FlexScheme.greys:
        return 'Серая';
      case FlexScheme.sepia:
        return 'Сепия';
      case FlexScheme.shadBlue:
        return 'Тёмно-Синия';
      case FlexScheme.shadGray:
        return 'Тёмно-Серая';
      case FlexScheme.shadGreen:
        return 'Тёмно-Зелёная';
      case FlexScheme.shadNeutral:
        return 'Тёмно-нейтральная';
      case FlexScheme.shadOrange:
        return 'Тёмно-оранжевая';
      case FlexScheme.shadRed:
        return 'Тёмно-красная';
      case FlexScheme.shadRose:
        return 'Тёмно-розовая';
      case FlexScheme.shadSlate:
        return 'Тёмный шифер';
      case FlexScheme.shadStone:
        return 'Тёмный камень';
      case FlexScheme.shadViolet:
        return 'Тёмно-фиолетовый';
      case FlexScheme.shadYellow:
        return 'Тёмный-жёлтый';
      case FlexScheme.shadZinc:
        return 'Тёмный цинк';

      case FlexScheme.custom:
        return 'Необычная';
      default:
        return scheme.name; // Если вдруг добавят новые, которых у нас нет в списке
    }
  }

  /// Преобразует пользовательское имя темы обратно в FlexScheme
  /// Если соответствие не найдено, возвращает FlexScheme.material
  static FlexScheme getSchemeFromDisplayName(String displayName) {
    for (var scheme in FlexScheme.values) {
      if (getDisplayName(scheme) == displayName) {
        return scheme;
      }
    }
    return FlexScheme.material; // Значение по умолчанию
  }
}