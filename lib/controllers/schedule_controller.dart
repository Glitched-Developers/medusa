// lib/controllers/schedule_controller.dart
import 'package:flutter/material.dart';
import 'package:medusa/models/lesson.dart';
import '../models/schedule_response.dart';
import '../repositories/interfaces/i_schedule_repository.dart';

class ScheduleController extends ChangeNotifier {
  final IScheduleRepository _repository;
  ScheduleController(this._repository);

  ScheduleResponse? _scheduleResponse;
  int? _currentWeek;

  bool _isLoading = false;
  String? _error;

  ScheduleResponse? get scheduleResponse => _scheduleResponse;
  Map<String, List<Lesson>>? get schedule => _scheduleResponse?.schedule;
  int? get currentWeek => _currentWeek;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSchedule(int groupId, {int? week}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentWeek = await _repository.getCurrentWeek();
      _scheduleResponse = await _repository.getSchedule(groupId, week: week);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTodaySchedule(int groupId, {int? week}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentWeek = await _repository.getCurrentWeek();
      _scheduleResponse = await _repository.getTodaySchedule(groupId, week: week);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


}