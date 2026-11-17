// Экран обратной связи: к обращению можно приложить скриншот,
// а отправить его — через «Поделиться» или готовым issue в GitHub.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/controllers/bug_reports_controller.dart';
import 'package:medusa/services/bug_report_service.dart';
import 'package:medusa/view/screens/reports_screen_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('на экране есть скриншот и кнопка GitHub', (tester) async {
    // Высокий экран, чтобы весь список поместился без прокрутки.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = BugReportsController(BugReportService());

    await tester.pumpWidget(
      ChangeNotifierProvider<BugReportsController>.value(
        value: controller,
        child: const MaterialApp(home: ReportsScreenView()),
      ),
    );
    await tester.pump();

    expect(find.text('Прикрепить скриншот'), findsOneWidget);
    expect(find.text('Открыть issue на GitHub'), findsOneWidget);
    expect(find.text('Отправить отчёт'), findsOneWidget);
  });
}
