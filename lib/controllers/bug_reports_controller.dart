import 'package:flutter/foundation.dart';

import '../models/bug_report.dart';
import '../services/bug_report_service.dart';
import '../services/device_info_service.dart';

/// Обращения пользователя: баги и пожелания.
///
/// Каждое обращение сохраняется на телефоне вместе с моделью устройства,
/// версией Android и меткой сборки — по ним видно, где именно не сложилось.
class BugReportsController extends ChangeNotifier {
  BugReportsController(
    this._service, {
    DeviceInfoService? deviceInfo,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoService() {
    _load();
  }

  final BugReportService _service;
  final DeviceInfoService _deviceInfo;

  List<BugReport> _reports = const <BugReport>[];
  bool _ready = false;

  /// Новые сверху.
  List<BugReport> get reports => _reports;
  bool get isReady => _ready;

  Future<void> _load() async {
    final loaded = await _service.load();
    loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _reports = loaded;
    _ready = true;
    notifyListeners();
  }

  /// Сохранить обращение. [screen] — размер экрана вида «1080x2400».
  Future<BugReport> submit({
    required ReportKind kind,
    required String text,
    String screen = '',
  }) async {
    final device = await _deviceInfo.collect(screen: screen);
    final report = BugReport(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      text: text.trim(),
      createdAt: DateTime.now(),
      device: device,
    );
    _reports = <BugReport>[report, ..._reports];
    await _service.save(_reports);
    notifyListeners();
    return report;
  }

  /// Пользователь отправил обращение — помечаем, чтобы это было видно.
  Future<void> markSent(String id) async {
    _reports = _reports
        .map((report) => report.id == id ? report.copyWith(sent: true) : report)
        .toList();
    await _service.save(_reports);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _reports = _reports.where((report) => report.id != id).toList();
    await _service.save(_reports);
    notifyListeners();
  }
}
