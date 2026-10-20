import '../../models/schedule_response.dart';

abstract class IScheduleRepository {
  Future<ScheduleResponse> getSchedule(int groupId, {int? week});
  Future<ScheduleResponse> getActualSchedule(int groupId, {int? week});
  Future<int> getCurrentWeek();
  Future<ScheduleResponse> forceRefreshSchedule(int groupId, {int? week});
  Future<void> clearCache();

  /// Расписание отдано из сохранённого снимка: сети не было.
  bool get isOffline;

  /// Когда был сохранён снимок, который сейчас показан.
  DateTime? get offlineSnapshotAt;
}
