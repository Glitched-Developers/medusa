#!/usr/bin/env python3
"""
Прокси-помощник для запуска Медузки в Chrome.

Зачем нужен
-----------
Браузер запрещает странице читать ответ с другого источника, если сервер
не прислал заголовки CORS. Бэкенд Медузки их обычно не присылает, поэтому
в Chrome приложение падает с ошибкой CORS — хотя через curl или Postman
тот же самый запрос прекрасно работает. Это классическая ловушка:
сервер жив, а приложение не может до него достучаться.

На Android-эмуляторе и Windows-десктопе этой проблемы нет — CORS
применяется только к браузеру.

Что делает
----------
Слушает порт 5001, переправляет всё на реальный бэкенд (порт 5000)
и дописывает к ответу нужные CORS-заголовки.

Запуск
------
    python dev_cors_proxy.py                 # бэкенд на localhost:5000
    python dev_cors_proxy.py --backend 5000 --listen 5001

Потом запускай приложение с адресом прокси:

    flutter run -d chrome --dart-define=API_URL=http://localhost:5001

Сразу станет видно в консоли: приходящие запросы и ответы бэкенда.
Если бэкенд недоступен, прокси вернёт 502 и напишет причину — это
проще, чем гадать, почему приложение показывает пустой экран.
"""
import argparse
import http.server
import socketserver
import urllib.error
import urllib.request

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Max-Age": "86400",
}

HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailer", "transfer-encoding", "upgrade",
    "content-encoding", "content-length",
    # Server и Date прокси подставит сам, иначе они задваиваются.
    "server", "date",
}


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    backend_base = "http://127.0.0.1:5000"

    def log_message(self, fmt, *args):
        print("[proxy] " + (fmt % args))

    # --- CORS preflight: браузер спрашивает, можно ли вообще слать запрос ---
    def do_OPTIONS(self):
        self.send_response(204)
        for key, value in CORS_HEADERS.items():
            self.send_header(key, value)
        self.end_headers()

    def _proxy(self, method):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None

        url = self.backend_base + self.path
        request = urllib.request.Request(url, data=body, method=method)

        for key, value in self.headers.items():
            if key.lower() in HOP_BY_HOP or key.lower() == "host":
                continue
            request.add_header(key, value)

        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = response.read()
                status = response.status
                headers = dict(response.headers.items())
        except urllib.error.HTTPError as error:
            payload = error.read()
            status = error.code
            headers = dict(error.headers.items())
        except urllib.error.URLError as error:
            message = (
                "Бэкенд недоступен по адресу %s (%s). "
                "Проверь, что сервер расписания запущен."
                % (self.backend_base, error.reason)
            ).encode("utf-8")
            self._send(502, message, {"Content-Type": "text/plain; charset=utf-8"})
            print("[proxy] 502 — " + message.decode("utf-8"))
            return
        except Exception as error:  # noqa: BLE001
            self._send(500, str(error).encode("utf-8"),
                       {"Content-Type": "text/plain; charset=utf-8"})
            return

        headers = {k: v for k, v in headers.items() if k.lower() not in HOP_BY_HOP}
        headers.update(CORS_HEADERS)
        self._send(status, payload, headers)

    def _send(self, status, payload, headers):
        self.send_response(status)
        for key, value in headers.items():
            self.send_header(key, value)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    def do_GET(self):
        self._proxy("GET")

    def do_POST(self):
        self._proxy("POST")

    def do_PUT(self):
        self._proxy("PUT")

    def do_PATCH(self):
        self._proxy("PATCH")

    def do_DELETE(self):
        self._proxy("DELETE")

    def do_HEAD(self):
        self._proxy("HEAD")


def main():
    parser = argparse.ArgumentParser(description="CORS-прокси для бэкенда Медузки")
    parser.add_argument("--backend", type=int, default=5000,
                        help="порт реального бэкенда (по умолчанию 5000)")
    parser.add_argument("--listen", type=int, default=5001,
                        help="порт, на котором слушает прокси (по умолчанию 5001)")
    args = parser.parse_args()

    handler = type("BoundProxyHandler", (ProxyHandler,),
                   {"backend_base": "http://127.0.0.1:%d" % args.backend})

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("127.0.0.1", args.listen), handler) as httpd:
        print("CORS-прокси слушает http://localhost:%d -> http://localhost:%d"
              % (args.listen, args.backend))
        print("Запускай приложение так:")
        print("  flutter run -d chrome --dart-define=API_URL=http://localhost:%d"
              % args.listen)
        print("Ctrl+C — остановить.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nОстановлено.")


if __name__ == "__main__":
    main()
