// Мини-сервер для передачи собранного APK на телефон по Wi-Fi.
//
// Запуск:  dart run tool/serve_apk.dart 8081
// На телефоне (в той же Wi-Fi сети) открыть напечатанный адрес —
// откроется страничка со ссылкой на скачивание APK.
//
// Сервер не падает, если APK ещё не собран: он просто сообщает,
// что файл готовится, и отдаёт его, как только тот появится.

import 'dart:io';

const _apkPath = 'build/app/outputs/flutter-apk/app-release.apk';
// Имя файла содержит ревизию: браузер кеширует скачивания по имени,
// и без смены имени телефон может получить старый APK с тем же адресом.
const _apkName = 'meduzka-news4.apk';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args.first) ?? 8081 : 8081;
  final apk = File(_apkPath);

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Сервер запущен (порт $port).');
  stdout.writeln('Откройте на телефоне (тот же Wi-Fi):');
  for (final address in await _lanAddresses()) {
    stdout.writeln('  http://$address:$port/');
  }

  await for (final request in server) {
    final path = request.uri.path;
    stdout.writeln('${request.connectionInfo?.remoteAddress.address} -> $path');

    if (path == '/' || path == '/index.html') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-store, no-cache, must-revalidate')
        ..headers.set('Pragma', 'no-cache')
        ..write(_page(apk));
    } else if (path == '/$_apkName' || path == '/app-release.apk') {
      if (apk.existsSync()) {
        final bytes = apk.readAsBytesSync();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType =
              ContentType('application', 'vnd.android.package-archive')
          ..headers.contentLength = bytes.length
          ..headers.set('Content-Disposition',
              'attachment; filename="$_apkName"')
          ..headers.set('Cache-Control', 'no-store, no-cache, must-revalidate')
          ..headers.set('Pragma', 'no-cache')
          ..add(bytes);
        stdout.writeln('  отдан APK: ${(bytes.length / 1024 / 1024).toStringAsFixed(1)} МБ');
      } else {
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.contentType = ContentType.html
          ..write(_page(apk));
      }
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Не найдено: $path');
    }
    await request.response.close();
  }
}

String _page(File apk) {
  final ready = apk.existsSync();
  final size = ready
      ? '${(apk.lengthSync() / 1024 / 1024).toStringAsFixed(1)} МБ'
      : '';
  return '''
<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Медузка — установка</title>
<style>
  body { font-family: -apple-system, Roboto, sans-serif; margin: 0;
         background: #f3f7f4; color: #14301f; display: flex;
         min-height: 100vh; align-items: center; justify-content: center; }
  .card { background: #fff; border-radius: 18px; padding: 28px 24px;
          max-width: 420px; box-shadow: 0 8px 30px rgba(0,0,0,.08);
          text-align: center; margin: 16px; }
  h1 { color: #27844A; margin: 0 0 8px; font-size: 26px; }
  p { line-height: 1.5; color: #41544a; }
  a.btn { display: inline-block; margin-top: 14px; background: #27844A;
          color: #fff; text-decoration: none; padding: 14px 22px;
          border-radius: 12px; font-size: 17px; font-weight: 600; }
  .hint { font-size: 13px; color: #6b7d73; margin-top: 16px; }
  .pending { background: #fff7e0; color: #7a5b00; padding: 12px;
             border-radius: 10px; }
</style>
</head>
<body>
  <div class="card">
    <h1>Медузка</h1>
    <p>Расписание НИУ БелГУ</p>
    ${ready
        ? '<a class="btn" href="/$_apkName">Скачать APK ($size)</a>'
        : '<p class="pending">APK ещё собирается — обновите страницу через минуту-две.</p>'}
    <p class="hint">После скачивания откройте файл и разрешите установку
    из неизвестных источников, если телефон попросит.</p>
  </div>
</body>
</html>''';
}

Future<List<String>> _lanAddresses() async {
  final result = <String>[];
  for (final interface in await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  )) {
    for (final address in interface.addresses) {
      result.add(address.address);
    }
  }
  return result;
}
