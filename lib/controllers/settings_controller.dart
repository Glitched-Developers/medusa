import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';

class SettingsController with ChangeNotifier {
  final SettingsService _settingsService;
  int? _selectedGroup;
  bool _isFirstLaunchCompleted = false;

  SettingsController(this._settingsService) {
    _loadSelectedGroup();
    _loadFirstLaunchStatus();
  }

  int? get selectedGroup => _selectedGroup;
  bool get isFirstLaunchCompleted => _isFirstLaunchCompleted;

  Future<void> _loadSelectedGroup() async {
    _selectedGroup = await _settingsService.getSelectedGroup();
    notifyListeners();
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
}