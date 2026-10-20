import 'dart:convert';

import 'base_services/base_storage_service.dart';
import '../models/bug_report.dart';

/// Обращения пользователя (баги и пожелания) на телефоне.
///
/// Сервера у приложения нет, поэтому обращения складываются в хранилище:
/// их видно в списке «Мои обращения», оттуда можно отправить текст
/// разработчику (поделиться / скопировать).
class BugReportService extends BaseStorageService {
  static const String _reportsKey = 'bug_reports_v1';

  @override
  Set<String> getAllowedKeys() => <String>{_reportsKey};

  Future<List<BugReport>> load() async {
    final raw = await getString(_reportsKey);
    if (raw == null) return <BugReport>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((item) => BugReport.fromJson(Map<String, dynamic>.from(item)))
          .where((report) => report.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <BugReport>[];
    }
  }

  Future<void> save(List<BugReport> reports) async {
    await setString(
      _reportsKey,
      jsonEncode(reports.map((report) => report.toJson()).toList()),
    );
  }
}
