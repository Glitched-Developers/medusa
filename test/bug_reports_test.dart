// Обратная связь: баги и пожелания сохраняются на телефоне вместе
// с данными об устройстве — по ним видно, где именно не сложилось.
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/controllers/bug_reports_controller.dart';
import 'package:medusa/models/bug_report.dart';
import 'package:medusa/services/bug_report_service.dart';
import 'package:medusa/services/device_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDeviceInfo extends DeviceInfoService {
  @override
  Future<DeviceInfo> collect({String screen = ''}) async => DeviceInfo(
        model: 'Pixel 7',
        manufacturer: 'Google',
        android: '14 (SDK 34)',
        appBuild: '20.10-test',
        screen: screen,
      );
}

Future<BugReportsController> _controller() async {
  final controller = BugReportsController(
    BugReportService(),
    deviceInfo: _FakeDeviceInfo(),
  );
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Хранилище в тестах общее: чистим, чтобы обращения не копились.
    final prefs = await BugReportService().getPrefs();
    await prefs.clear();
  });

  group('Обращения', () {
    test('баг-репорт сохраняет текст и данные устройства', () async {
      final controller = await _controller();
      final report = await controller.submit(
        kind: ReportKind.bug,
        text: 'Не открывается пара при нажатии на название',
        screen: '1080x2400',
      );

      expect(controller.reports, hasLength(1));
      expect(report.kind, ReportKind.bug);
      expect(report.device.model, 'Pixel 7');
      expect(report.device.android, contains('14'));
      expect(report.device.screen, '1080x2400');
      expect(report.device.summary, contains('Google Pixel 7'));
      expect(report.device.summary, contains('сборка 20.10-test'));
    });

    test('сообщение для отправки содержит текст и устройство', () async {
      final controller = await _controller();
      final report = await controller.submit(
        kind: ReportKind.idea,
        text: 'Хочу расписание звонков',
      );

      final message = report.asMessage();
      expect(message, contains('Пожелание'));
      expect(message, contains('Хочу расписание звонков'));
      expect(message, contains('Google Pixel 7'));
    });

    test('обращения переживают перезапуск приложения', () async {
      final first = await _controller();
      await first.submit(kind: ReportKind.bug, text: 'Падает при поиске');

      final second = await _controller();
      expect(second.reports, hasLength(1));
      expect(second.reports.first.text, 'Падает при поиске');
    });

    test('новые обращения сверху, отправленные помечаются', () async {
      final controller = await _controller();
      final old = await controller.submit(kind: ReportKind.bug, text: 'Первое');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final fresh =
          await controller.submit(kind: ReportKind.idea, text: 'Второе');

      expect(controller.reports.first.id, fresh.id);
      expect(controller.reports.last.id, old.id);

      await controller.markSent(fresh.id);
      expect(controller.reports.first.sent, isTrue);
    });

    test('удаление убирает обращение из хранилища', () async {
      final controller = await _controller();
      final report =
          await controller.submit(kind: ReportKind.bug, text: 'Удалить меня');
      await controller.remove(report.id);

      expect(controller.reports, isEmpty);
      final again = await _controller();
      expect(again.reports, isEmpty);
    });
  });
}
