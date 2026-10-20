import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Конфетти-пушки по бокам экрана — «нашли!».
///
/// Показывается, когда поиск подтвердил группу или преподавателя.
/// Из левого и правого края (по центру по вертикали) бьют две пушки:
/// угол 60° и 120°, разброс 55°, палитра — как в примере на
/// canvas-confetti. Рисуется поверх всего через корневой Overlay,
/// не перехватывает тапы и сам удаляется после анимации.
void showSalute(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SideCannons(
      key: const Key('salute'),
      onCompleted: entry.remove,
    ),
  );
  overlay.insert(entry);
}

/// Одна бумажка конфетти.
class _Confetto {
  _Confetto({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.round,
    required this.spin,
    required this.spinSpeed,
    required this.flutterPhase,
  });

  double x;
  double y;

  /// Скорость в «пикселях за кадр» (60 к/с) — как в canvas-confetti.
  double vx;
  double vy;

  final double size;
  final Color color;
  final bool round;

  /// Текущий наклон бумажки.
  double spin;

  /// Скорость вращения, рад/кадр.
  final double spinSpeed;

  /// Фаза «трепетания» — бумажка то разворачивается, то поворачивается ребром.
  final double flutterPhase;
}

class _SideCannons extends StatefulWidget {
  const _SideCannons({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<_SideCannons> createState() => _SideCannonsState();
}

class _SideCannonsState extends State<_SideCannons>
    with SingleTickerProviderStateMixin {
  /// Сколько «стреляют» пушки: короткий салют на полсекунды.
  static const _emitSeconds = 0.5;

  /// Полное время эффекта (выстрелы + быстрое падение бумажек вниз).
  static const _total = Duration(milliseconds: 1300);

  /// Начальная скорость частиц, px за кадр — как startVelocity 60
  /// в canvas-confetti, но чуть спокойнее для телефона.
  static const _startVelocity = 46;

  /// Доля скорости, остающаяся за кадр — как friction 0.9.
  static const _friction = 0.9;

  /// Гравитация, px за кадр².
  static const _gravity = 0.8;

  /// Гравитация после окончания выстрелов: бумажки не растворяются в воздухе,
  /// а быстро падают вниз за край экрана — чтобы не загораживать расписание.
  static const _fallGravity = 2.2;

  /// Трение на фазе падения — почти нет, падение ускоряется.
  static const _fallFriction = 0.995;

  /// Разброс струи, градусы (spread: 55).
  static const _spread = 55;

  /// Углы пушек: левая бьёт вверх-вправо, правая — вверх-влево.
  static const _leftAngle = 60.0;
  static const _rightAngle = 120.0;

  /// Сколько бумажек вылетает из каждой пушки за кадр (particleCount).
  /// Стреляем недолго, поэтому струя плотнее.
  static const _perShot = 3;

  /// Палитра из примера: ["#a786ff","#fd8bbc","#eca184","#f8deb1"].
  static const _colors = <Color>[
    Color(0xFFA786FF),
    Color(0xFFFD8BBC),
    Color(0xFFECA184),
    Color(0xFFF8DEB1),
  ];

  late final AnimationController _controller;
  final _rnd = math.Random();
  final List<_Confetto> _items = <_Confetto>[];

  Size _size = Size.zero;

  /// Время симуляции на фиксированном шаге 1/60 с.
  double _elapsed = 0;
  double _last = 0;
  double _acc = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onCompleted();
      })
      ..addListener(_onTick)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    final seconds = _controller.value * (_total.inMilliseconds / 1000);
    var dt = seconds - _last;
    _last = seconds;
    if (dt <= 0) return;
    // Защита от «прыжка» времени, если кадр подвис.
    if (dt > 0.25) dt = 0.25;
    _acc += dt;

    const step = 1 / 60;
    while (_acc >= step) {
      _acc -= step;
      _elapsed += step;
      _simulate();
    }
  }

  void _simulate() {
    if (_size.isEmpty) return;
    // Масштаб: на телефоне (~400 dp) скорости один в один с canvas-confetti.
    final unit = (_size.width / 400).clamp(0.6, 1.8);

    // Пока идут выстрелы — бумажки летят вверх «струёй», после — падают.
    final falling = _elapsed > _emitSeconds;
    final gravity = falling ? _fallGravity : _gravity;
    final friction = falling ? _fallFriction : _friction;

    if (!falling) {
      _spawn(_leftAngle, Offset(0, _size.height * 0.5), unit);
      _spawn(_rightAngle, Offset(_size.width, _size.height * 0.5), unit);
    }

    for (final c in _items) {
      c.vx *= friction;
      c.vy = c.vy * friction + gravity * unit;
      c.x += c.vx;
      c.y += c.vy;
      c.spin += c.spinSpeed;
    }

    _items.removeWhere(
      (c) =>
          c.x < -80 ||
          c.x > _size.width + 80 ||
          c.y > _size.height + 80,
    );
  }

  void _spawn(double angleDeg, Offset origin, double unit) {
    for (var i = 0; i < _perShot; i++) {
      final angle =
          (angleDeg + (_rnd.nextDouble() - 0.5) * _spread) * math.pi / 180;
      final speed =
          _startVelocity * (0.62 + 0.38 * _rnd.nextDouble()) * unit;
      _items.add(
        _Confetto(
          x: origin.dx,
          y: origin.dy,
          vx: math.cos(angle) * speed,
          vy: -math.sin(angle) * speed,
          size: (5 + _rnd.nextDouble() * 6) * unit.clamp(0.75, 1.4),
          color: _colors[_rnd.nextInt(_colors.length)],
          round: _rnd.nextBool(),
          spin: _rnd.nextDouble() * math.pi,
          spinSpeed: (_rnd.nextDouble() - 0.5) * 0.4,
          flutterPhase: _rnd.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _size = Size(constraints.maxWidth, constraints.maxHeight);
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  items: _items,
                  controller: _controller,
                  totalSeconds: _total.inMilliseconds / 1000,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.items,
    required this.controller,
    required this.totalSeconds,
  }) : super(repaint: controller);

  final List<_Confetto> items;
  final AnimationController controller;
  final double totalSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final seconds = controller.value * totalSeconds;
    // Никакого угасания: бумажки сами улетают за нижний край экрана.
    const tail = 1.0;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final c in items) {
      // Бумажка «трепещет»: то полная, то повёрнутая ребром.
      final flutter = math.cos(c.flutterPhase + seconds * 7);
      final squash = 0.25 + 0.75 * flutter.abs();

      canvas.save();
      canvas.translate(c.x, c.y);
      canvas.rotate(c.spin);
      canvas.scale(squash, 1);
      paint.color = c.color.withValues(alpha: tail);
      if (c.round) {
        canvas.drawCircle(Offset.zero, c.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: c.size,
              height: c.size * 0.62,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.items != items ||
      oldDelegate.controller != controller ||
      oldDelegate.totalSeconds != totalSeconds;
}
