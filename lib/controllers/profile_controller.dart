import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';

/// Профиль пользователя: читаем при запуске, сохраняем при правке.
class ProfileController extends ChangeNotifier {
  ProfileController(this._service) {
    _load();
  }

  final ProfileService _service;

  UserProfile _profile = const UserProfile();
  bool _ready = false;

  UserProfile get profile => _profile;
  bool get isReady => _ready;
  bool get hasProfile => _profile.name.trim().isNotEmpty;

  Future<void> _load() async {
    _profile = await _service.load();
    _ready = true;
    notifyListeners();
  }

  Future<void> save(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _service.save(profile);
  }
}
