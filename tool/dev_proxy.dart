// CORS-прокси для запуска Медузки в браузере.
//
// Браузер запрещает странице приложения читать ответ с bsuedu.ru,
// если сервер не прислал CORS-заголовки (он их не шлёт). С телефона
// (Android/iOS) этой проблемы нет — прокси нужен только для dev-запуска.
//
// Запуск:  dart run tool/dev_proxy.dart [порт]   (по умолчанию 5001)
// Приложение: flutter run -d chrome --web-port=8080 --dart-define=API_URL=http://localhost:5001/bsu/education/schedule
import 'dart:io';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': '*',
  // Без expose-headers браузер скрывает Location от JS — приложение
  // не увидит редирект search_redirect.php (303 -> teacher=<id>).
  'Access-Control-Expose-Headers': 'Location',
};

Future<void> main(List<String> args) async {
  final port = int.tryParse(args.isNotEmpty ? args[0] : '') ?? 5001;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('CORS-прокси: http://localhost:$port -> https://bsuedu.ru');
  stdout.writeln('Остановить: Ctrl+C');

  await for (final request in server) {
    try {
      if (request.method == 'OPTIONS') {
        request.response.statusCode = 204;
        corsHeaders.forEach(request.response.headers.set);
        await request.response.close();
        continue;
      }

      final target = Uri.parse('https://bsuedu.ru${request.uri}');
      final client = HttpClient();
      final clientRequest = await client.openUrl(request.method, target);
      // Редиректы (303 search_redirect.php -> teacher=<id>) должны
      // дойти до приложения как есть, а не съестся прокси.
      clientRequest.followRedirects = false;
      request.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        // Dart-клиент сам управляет сжатием и сам распакует ответ;
        // пробрасывать accept-encoding нельзя — иначе заголовок
        // content-encoding разойдётся с уже распакованным телом.
        if (lower == 'host' || lower == 'accept-encoding') return;
        clientRequest.headers.set(name, values);
      });
      if (request.method == 'POST') {
        final body = await request.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        if (body.isNotEmpty) clientRequest.add(body);
      }
      final clientResponse = await clientRequest.close();

      request.response.statusCode = clientResponse.statusCode;
      clientResponse.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower == 'content-length' || lower == 'content-encoding') return;
        request.response.headers.set(name, values);
      });
      corsHeaders.forEach(request.response.headers.set);
      await request.response.addStream(clientResponse);
      await request.response.close();
      client.close(force: true);
      stdout.writeln('${request.method} ${request.uri} -> ${clientResponse.statusCode}');
    } catch (e) {
      request.response.statusCode = 502;
      request.response.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
      request.response.write('Прокси не смог достучаться до bsuedu.ru: $e');
      await request.response.close();
    }
  }
}
