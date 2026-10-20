class ApiConstants{
  /// Базовый адрес страницы расписания НИУ БелГУ.
  /// Переопределяется: --dart-define=API_URL=https://...
  static final String apiServerUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://bsuedu.ru/bsu/education/schedule',
  );
}
