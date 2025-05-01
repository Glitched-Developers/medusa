import 'dart:convert';
import 'package:http/http.dart' as http;

enum WeekActions {
  this_("this"),
  next("next"),
  last("last");

  final String value;
  const WeekActions(this.value);

  @override
  String toString() => value;
}

class BsuApiService {
  final String baseUrl;
  final http.Client _client;

  BsuApiService(this.baseUrl) : _client = http.Client();

  BsuApiService.withClient(this.baseUrl, this._client);

  void dispose() {
    _client.close();
  }

  Future<int> getWeek(WeekActions action, {int? week}) async {
    final url = Uri.parse('$baseUrl/week');
    final payload = {
      'action': action.toString(),
      if (week != null) 'week': week,
    };

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Безопасное преобразование из String в int
        final weekValue = data['week'];
        if (weekValue is int) {
          return weekValue; // Уже int
        } else if (weekValue is String) {
          // Пытаемся преобразовать строку в число
          try {
            return int.parse(weekValue);
          } catch (e) {
            throw ApiException('Failed to convert week value to integer: $weekValue');
          }
        } else {
          throw ApiException('Unexpected week value type: ${weekValue.runtimeType}');
        }
      } else {
        throw ApiException('Failed to get week: ${response.statusCode}', response);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }


  Future<Map<String, dynamic>> getTodaySchedule(int group) async {
    final url = Uri.parse('$baseUrl/actual');
    final payload = {
      'group': group,
    };

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, charset=utf-8', // явно указываем кодировку
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['schedule'] as Map<String, dynamic>;
      } else {
        throw ApiException('Failed to get today schedule: ${response.statusCode}', response);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getSchedule(int group, {int? week}) async {
    final url = Uri.parse('$baseUrl/schedule');
    final payload = {
      'group': group,
      if (week != null) 'week': week,
    };

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, charset=utf-8', // явно указываем кодировку
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['schedule'] as Map<String, dynamic>;
      } else {
        throw ApiException('Failed to get schedule: ${response.statusCode}', response);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }
}

class ApiException implements Exception {
  final String message;
  final http.Response? response;

  ApiException(this.message, [this.response]);

  @override
  String toString() => 'ApiException: $message';
}