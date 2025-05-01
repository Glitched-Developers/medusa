import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';

class SettingsController with ChangeNotifier {
  final SettingsService _settingsService;
  int? _selectedGroup;

  SettingsController(this._settingsService) {
    _loadSelectedGroup();
  }

  int? get selectedGroup => _selectedGroup;

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
}