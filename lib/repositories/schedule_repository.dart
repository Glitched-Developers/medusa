import '../models/schedule_response.dart';
import 'interfaces/i_schedule_repository.dart';
import '../services/bsu_api_service.dart';

class ScheduleRepository implements IScheduleRepository {
  final BsuApiService _apiService;

  ScheduleRepository(this._apiService);

  @override
  Future<ScheduleResponse> getSchedule(int groupId, {int? week}) async {
    final data = await _apiService.getSchedule(groupId, week: week);
    return ScheduleResponse.fromJson(data);
  }

  @override
  Future<ScheduleResponse> getTodaySchedule(int groupId, {int? week}) async {
    final data = await _apiService.getTodaySchedule(groupId);
    return ScheduleResponse.fromJson(data);
  }

  @override
  Future<int> getCurrentWeek() async {
    return await _apiService.getWeek(WeekActions.this_);
  }

}