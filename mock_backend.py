#!/usr/bin/env python3
"""
Тестовый сервер расписания для Медузки.

Нужен, чтобы посмотреть приложение без настоящего бэкенда Влада.
Поднимается сам при запуске из лаунчера, отдаёт правдоподобное
расписание с разными типами пар — на нём видно цветовое кодирование.

Запуск
------
    python mock_backend.py                 # порт 5000
    python mock_backend.py --port 5000 --delay 0.3

Проверить руками
----------------
    http://localhost:5000/            — сводка и список дней
    curl -X POST http://localhost:5000/schedule -d '{"group":90002493}'

Что отдаёт
----------
    POST /week     {"action": "this"|"next"|"last", "week"?: N}  -> {"week": N}
    POST /schedule {"group": N, "week"?: N}                      -> {metadata, schedule}
    POST /actual   {"group": N}                                  -> {metadata, schedule}

Стоит только стандартная библиотека. CORS включён, поэтому из Chrome
всё работает без прокси.
"""
from __future__ import annotations

import argparse
import datetime as dt
import http.server
import json
import socketserver
import sys
import time
from urllib.parse import urlparse

# ---------- данные ----------

WEEKDAYS = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]

TIMES = {
    1: "9:00-10:35",
    2: "10:50-12:25",
    3: "12:40-14:15",
    4: "14:30-16:05",
    5: "16:20-17:55",
    6: "18:10-19:45",
}


def lesson(number, type_, name, teacher, auditory, subgroup=None, online=False):
    item = {
        "number": number,
        "time": TIMES[number],
        "type": type_,
        "name": name,
        "teacher": teacher,
        "auditory": auditory,
        "online": online,
        "key": "%d_%s" % (number, name),
    }
    if subgroup is not None:
        item["subgroup"] = subgroup
    return item


# Две недели различаются — переключение должно быть заметно.
# Типы намеренно разные, чтобы проверить всю палитру цветов, включая
# серый чип для неизвестного типа («УМО»).
WEEKS = {
    1: {
        "Понедельник": [
            lesson(1, "ЛК", "Математический анализ", "Иванова Е. П.", "ауд. 305"),
            lesson(2, "ПЗ", "Иностранный язык", "Смирнова О. В.", "ауд. 412", subgroup=1),
            lesson(2, "ПЗ", "Иностранный язык", "Смирнова О. В.", "ауд. 414", subgroup=2),
            lesson(3, "ЛР", "Информатика и программирование", "Петров А. А.", "Лаб. 12"),
            lesson(4, "Физкультура", "Физическая культура", "Сидоров И. К.", "Спортзал"),
        ],
        "Вторник": [
            lesson(1, "ЛК", "Физика", "Орлов М. В.", "ауд. 210"),
            lesson(2, "Лаб. работа", "Физика (лабораторный практикум)", "Орлов М. В.", "Лаб. 7", subgroup=1),
            lesson(2, "Лаб. работа", "Физика (лабораторный практикум)", "Орлов М. В.", "Лаб. 7", subgroup=2),
            lesson(3, "ПЗ", "Начертательная геометрия", "Кузнецов Д. С.", "ауд. 118"),
            lesson(4, "Консультация", "Высшая математика", "Иванова Е. П.", "ауд. 305"),
        ],
        "Среда": [
            lesson(1, "ЛК", "История Беларуси", "Волкова Н. И.", "ауд. 401"),
            lesson(2, "ПЗ", "Информационные технологии", "Петров А. А.", "Дистанционно", online=True),
            lesson(3, "ЛР", "Химия", "Борисова Л. А.", "Лаб. 3"),
            lesson(4, "КП", "Курсовой проект", "Кузнецов Д. С.", "ауд. 118"),
        ],
        "Четверг": [
            lesson(1, "ЛК", "Экономика и организация производства", "Макеева Т. Р.", "ауд. 502"),
            lesson(2, "ПЗ", "Физическое воспитание", "Сидоров И. К.", "Спортзал"),
            lesson(3, "ЛР", "Электротехника", "Гаврилов С. Н.", "Лаб. 21"),
            lesson(4, "УМО", "Учебно-методическое объединение", "Зайцева А. В.", "ауд. 305"),
        ],
        "Пятница": [
            lesson(1, "ЛК", "Философия", "Лебедева К. Ю.", "ауд. 417"),
            lesson(2, "ПЗ", "Английский язык", "Смирнова О. В.", "ауд. 412", subgroup=1),
            lesson(2, "ПЗ", "Английский язык", "Смирнова О. В.", "ауд. 414", subgroup=2),
            lesson(3, "ЛР", "Теоретическая механика", "Гаврилов С. Н.", "Лаб. 5"),
        ],
        "Суббота": [
            lesson(1, "ЛК", "Основы экологии", "Борисова Л. А.", "ауд. 220"),
            lesson(2, "ПЗ", "Математический анализ", "Иванова Е. П.", "Дистанционно", online=True),
        ],
    },
    2: {
        "Понедельник": [
            lesson(1, "ЛК", "Математический анализ", "Иванова Е. П.", "ауд. 305"),
            lesson(2, "ЛР", "Информатика и программирование", "Петров А. А.", "Лаб. 14"),
            lesson(3, "ПЗ", "Начертательная геометрия", "Кузнецов Д. С.", "ауд. 118"),
            lesson(4, "Экзамен", "Зачёт по физической культуре", "Сидоров И. К.", "Спортзал"),
        ],
        "Вторник": [
            lesson(1, "ЛК", "Физика", "Орлов М. В.", "ауд. 210"),
            lesson(2, "ПЗ", "Физика (решение задач)", "Орлов М. В.", "ауд. 210"),
            lesson(3, "ЛР", "Химия", "Борисова Л. А.", "Лаб. 3"),
        ],
        "Среда": [
            lesson(1, "ЛК", "История Беларуси", "Волкова Н. И.", "ауд. 401"),
            lesson(2, "Лаб. работа", "Информационные технологии", "Петров А. А.", "Лаб. 12", subgroup=1),
            lesson(2, "Лаб. работа", "Информационные технологии", "Петров А. А.", "Лаб. 12", subgroup=2),
            lesson(3, "ПЗ", "Теоретическая механика", "Гаврилов С. Н.", "ауд. 230"),
            lesson(4, "КП", "Курсовой проект", "Кузнецов Д. С.", "ауд. 118"),
            lesson(5, "Консультация", "Экономика", "Макеева Т. Р.", "ауд. 502"),
        ],
        "Четверг": [
            lesson(1, "ЛК", "Экономика и организация производства", "Макеева Т. Р.", "ауд. 502"),
            lesson(2, "ЛР", "Электротехника", "Гаврилов С. Н.", "Лаб. 21"),
            lesson(3, "Физкультура", "Физическая культура", "Сидоров И. К.", "Спортзал"),
        ],
        "Пятница": [
            lesson(1, "ЛК", "Философия", "Лебедева К. Ю.", "ауд. 417"),
            lesson(2, "ПЗ", "Английский язык", "Смирнова О. В.", "ауд. 412", subgroup=1),
            lesson(2, "ПЗ", "Английский язык", "Смирнова О. В.", "ауд. 414", subgroup=2),
        ],
        # Пустой день — проверяем, что приложение показывает «Пар нет».
        "Суббота": [],
    },
}


def current_monday(today: dt.date | None = None) -> dt.date:
    today = today or dt.date.today()
    return today - dt.timedelta(days=today.weekday())


def build_schedule(week: int, today: dt.date | None = None) -> dict:
    """Собирает расписание с реальными датами текущей недели.

    Даты считаются от сегодняшнего дня, поэтому текущий день
    подсвечивается в приложении.
    """
    monday = current_monday(today)
    template = WEEKS.get(week, WEEKS[1])

    schedule = {}
    for index, weekday in enumerate(WEEKDAYS):
        day = monday + dt.timedelta(days=index)
        key = "%s %s" % (day.strftime("%d.%m.%Y"), weekday)
        schedule[key] = [dict(item) for item in template.get(weekday, [])]
    return schedule


def week_number(today: dt.date | None = None) -> int:
    """Номер учебной недели. Чередуем 1 и 2, чтобы данные различались."""
    today = today or dt.date.today()
    iso_week = today.isocalendar()[1]
    return 1 if iso_week % 2 else 2


# ---------- сервер ----------

class Handler(http.server.BaseHTTPRequestHandler):
    delay = 0.3
    quiet = False

    def log_message(self, fmt, *args):
        if self.quiet:
            return
        sys.stderr.write("[mock] " + (fmt % args) + "\n")

    # --- ответы ---

    def _json(self, payload: dict, status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")

    def _error(self, message: str, status: int = 400) -> None:
        self._json({"error": message}, status)

    # --- маршрутизация ---

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_GET(self):
        if urlparse(self.path).path in ("/", ""):
            self._index()
        else:
            self._error("Unknown path: %s" % self.path, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        payload = self._read_body()

        if self.delay:
            time.sleep(self.delay)

        if path == "/week":
            self._week(payload)
        elif path == "/schedule":
            self._schedule(payload)
        elif path == "/actual":
            self._actual(payload)
        else:
            self._error("Unknown path: %s" % path, 404)

    # --- эндпоинты ---

    def _week(self, payload: dict) -> None:
        """Номер учебной недели. Приложение дёргает его первым делом."""
        action = payload.get("action", "this")
        base = week_number()

        if action == "next":
            base = 1 if base == 2 else 2
        elif action == "last":
            base = 1 if base == 2 else 2

        if isinstance(payload.get("week"), int):
            base = payload["week"]

        self._json({"week": base})

    def _schedule(self, payload: dict) -> None:
        week = payload.get("week")
        if not isinstance(week, int):
            week = week_number()
        self._json({
            "metadata": {"timestamp": dt.datetime.now().isoformat(timespec="seconds")},
            "schedule": build_schedule(week),
        })

    def _actual(self, payload: dict) -> None:
        """Расписание на сегодня."""
        today = dt.date.today()
        full = build_schedule(week_number(), today)
        key = "%s %s" % (today.strftime("%d.%m.%Y"), WEEKDAYS[today.weekday()])

        schedule = {}
        if key in full:
            schedule[key] = full[key]
        else:  # выходной — показываем пустой день
            schedule[key] = []

        self._json({
            "metadata": {"timestamp": dt.datetime.now().isoformat(timespec="seconds")},
            "schedule": schedule,
        })

    # --- вспомогательное ---

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return {}

    def _index(self) -> None:
        week = week_number()
        schedule = build_schedule(week)
        rows = []
        for day, lessons in schedule.items():
            types = sorted({item["type"] for item in lessons})
            rows.append(
                "  <tr><td>%s</td><td>%d</td><td>%s</td></tr>"
                % (day, len(lessons), ", ".join(types) or "&mdash;")
            )
        body = """<!DOCTYPE html><html lang="ru"><head><meta charset="utf-8">
<title>Medusa mock backend</title>
<style>
body{font-family:system-ui,Segoe UI,Roboto,sans-serif;margin:32px;color:#222;background:#fafafa}
h1{margin:0 0 4px} p{margin:0 0 18px;color:#666}
table{border-collapse:collapse;background:#fff}
td,th{border:1px solid #ddd;padding:6px 12px;text-align:left}
tr:first-child td{background:#f2f2f5}
code{background:#eee;padding:2px 5px;border-radius:3px}
</style></head><body>
<h1>Тестовый сервер Медузки</h1>
<p>Работает. Неделя №%(week)s. Группу можно указать любую &mdash;
ответ не зависит от неё.</p>
<table>
  <tr><th>День</th><th>Пар</th><th>Типы</th></tr>
%(rows)s
</table>
<p style="margin-top:18px">Проверить вручную:
<code>curl -X POST http://localhost:%(port)s/schedule -d '{"group":90002493}'</code></p>
</body></html>""" % {"week": week, "rows": "\n".join(rows), "port": self.server.server_address[1]}

        encoded = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self._cors_headers()
        self.end_headers()
        self.wfile.write(encoded)


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main() -> int:
    parser = argparse.ArgumentParser(description="Тестовый сервер расписания Медузки")
    parser.add_argument("--port", type=int, default=5000, help="порт (по умолчанию 5000)")
    parser.add_argument("--delay", type=float, default=0.3,
                        help="искусственная задержка ответа в секундах (по умолчанию 0.3)")
    parser.add_argument("--quiet", action="store_true", help="не печатать запросы")
    args = parser.parse_args()

    handler = type("BoundHandler", (Handler,),
                   {"delay": args.delay, "quiet": args.quiet})

    try:
        httpd = Server(("127.0.0.1", args.port), handler)
    except OSError as error:
        print("Не удалось занять порт %d: %s" % (args.port, error))
        print("Возможно, порт уже занят настоящим бэкендом.")
        return 1

    print("Тестовый сервер Медузки слушает http://localhost:%d" % args.port)
    print("Сводка: http://localhost:%d/" % args.port)
    print("Ctrl+C — остановить.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nОстановлено.")
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
