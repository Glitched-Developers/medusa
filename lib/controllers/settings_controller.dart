import 'dart:async';

import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';

class SettingsController with ChangeNotifier {
  final SettingsService _settingsService;
  int? _selectedGroup;
  bool _isFirstLaunchCompleted = false;
  int _offlineRetentionDays = SettingsService.defaultOfflineRetentionDays;
  final Completer<void> _ready = Completer<void>();

  SettingsController(this._settingsService) {
    _load();
  }

  int? get selectedGroup => _selectedGroup;
  bool get isFirstLaunchCompleted => _isFirstLaunchCompleted;

  /// Сколько дней расписание хранится на телефоне и открывается без сети.
  int get offlineRetentionDays => _offlineRetentionDays;

  /// Настройки прочитаны из хранилища.
  Future<void> get ready => _ready.future;

  Future<void> _load() async {
    _selectedGroup = await _settingsService.getSelectedGroup();
    _isFirstLaunchCompleted = await _settingsService.getFirstLaunchStatus();
    _offlineRetentionDays =
        await _settingsService.getOfflineRetentionDays();
    notifyListeners();
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> setSelectedGroup(int group) async {
    await _settingsService.saveSelectedGroup(group);
    _selectedGroup = group;
    notifyListeners();
  }

  Future<bool> hasSelectedGroup() async {
    return await _settingsService.hasSelectedGroup();
  }

  Future<void> _loadFirstLaunchStatus() async {
    _isFirstLaunchCompleted = await _settingsService.getFirstLaunchStatus();
  }

  Future<void> setFirstLaunchCompleted() async {
    await _settingsService.setFirstLaunchCompleate();
    notifyListeners();
  }

  Future<void> setOfflineRetentionDays(int days) async {
    final value = days.clamp(1, 365);
    _offlineRetentionDays = value;
    notifyListeners();
    await _settingsService.saveOfflineRetentionDays(value);
  }
}
