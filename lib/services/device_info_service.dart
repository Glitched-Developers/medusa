import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../models/bug_report.dart';

/// Собирает краткие данные об устройстве для обращения.
///
/// Пишем только то, что помогает найти причину: модель, версия системы,
/// размер экрана, метка сборки. Ничего личного.
class DeviceInfoService {
  static const String _buildTag = String.fromEnvironment('APP_BUILD');

  Future<DeviceInfo> collect({String screen = ''}) async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return DeviceInfo(
          model: info.model,
          manufacturer: info.manufacturer,
          android: '${info.version.release} (SDK ${info.version.sdkInt})',
          appBuild: _buildTag,
          screen: screen,
        );
      }
      if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return DeviceInfo(
          model: info.utsname.machine,
          manufacturer: 'Apple',
          android: info.systemVersion,
          appBuild: _buildTag,
          screen: screen,
        );
      }
      return DeviceInfo(
        model: Platform.operatingSystem,
        manufacturer: '',
        android: Platform.operatingSystemVersion,
        appBuild: _buildTag,
        screen: screen,
      );
    } catch (_) {
      return DeviceInfo(
        model: 'неизвестно',
        manufacturer: '',
        android: '',
        appBuild: _buildTag,
        screen: screen,
      );
    }
  }
}
