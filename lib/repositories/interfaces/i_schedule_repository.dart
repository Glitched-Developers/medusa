import '../../models/schedule_response.dart';

abstract class IScheduleRepository {
  Future<ScheduleResponse> getSchedule(int groupId, {int? week});
  Future<ScheduleResponse> getTodaySchedule(int groupId, {int? week});
  Future<int> getCurrentWeek();
}