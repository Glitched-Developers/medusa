import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Дополнительный луч по тому же периметру (см. [BorderBeam.extras]).
///
/// Смещением задаётся, где луч идёт относительно основного: 0.5 — ровно
/// напротив. Направление и цвета можно задать свои — так две полосы
/// отличаются друг от друга и «догоняют» одна другую.
class BorderBeamSpec {
  const BorderBeamSpec({
    this.offset = 0.5,
    this.reverse = false,
    this.colorFrom,
    this.colorTo,
    this.beamLengthFraction,
  });

  /// Где луч на периметре (0..1) в начальный момент.
  final double offset;

  /// Бежать в обратную сторону.
  final bool reverse;

  /// Цвет головы; null — как у основного луча.
  final Color? colorFrom;

  /// Цвет хвоста; null — как у основного луча.
  final Color? colorTo;

  /// Своя длина луча; null — как у основного.
  final double? beamLengthFraction;

  @override
  bool operator ==(Object other) =>
      other is BorderBeamSpec &&
      other.offset == offset &&
      other.reverse == reverse &&
      other.colorFrom == colorFrom &&
      other.colorTo == colorTo &&
      other.beamLengthFraction == beamLengthFraction;

  @override
  int get hashCode =>
      Object.hash(offset, reverse, colorFrom, colorTo, beamLengthFraction);
}

/// Бегущий луч по периметру рамки (порт эффекта BorderBeam).
///
/// Поверх [child] рисуется светящаяся «комета»: яркая голова, плавно
/// затухающий хвост. Луч обегает скруглённый прямоугольник рамки, что
/// оживляет поле ввода, не мешая чтению текста.
///
/// Анимация сделана через вращающийся [SweepGradient]: градиент по кругу
/// поворачивается вслед за контроллером, поэтому луч едет по рамке
/// плавно и равномерно, без вычисления длины пути.
///
/// Пример:
/// ```dart
/// BorderBeam(
///   borderRadius: 16,
///   child: TextField(...),
/// )
/// ```
///
/// Несколько полос задаются через [extras]: они бегут тем же ходом и не
/// догоняют друг друга — расстояние между ними постоянное.
class BorderBeam extends StatefulWidget {
  const BorderBeam({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.borderWidth = 1.8,
    this.beamLengthFraction = 0.22,
    this.duration = const Duration(seconds: 4),
    this.colorFrom,
    this.colorTo,
    this.initialOffset = 0.0,
    this.reverse = false,
    this.glow = true,
    this.extras = const <BorderBeamSpec>[],
  });

  /// Содержимое, вокруг которого бежит луч.
  final Widget child;

  /// Радиус скругления рамки — должен совпадать с радиусом самой рамки.
  final double borderRadius;

  /// Толщина луча (и рамки, по которой он бежит).
  final double borderWidth;

  /// Какую долю периметра занимает луч (0..1).
  final double beamLengthFraction;

  /// Время полного обхода рамки.
  final Duration duration;

  /// Цвет головы луча.
  final Color? colorFrom;

  /// Цвет хвоста луча.
  final Color? colorTo;

  /// Начальное положение луча (0..1) — чтобы лучи на разных рамках
  /// не бежали синхронно.
  final double initialOffset;

  /// Бежать в обратную сторону.
  final bool reverse;

  /// Добавлять мягкое свечение вокруг луча.
  final bool glow;

  /// Дополнительные полосы — рисуются тем же обходом.
  final List<BorderBeamSpec> extras;

  @override
  State<BorderBeam> createState() => _BorderBeamState();
}

class _BorderBeamState extends State<BorderBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Уважаем системное «уменьшение анимации»: луч просто замрёт.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant BorderBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final from = widget.colorFrom ?? scheme.primary;
    final to =
        widget.colorTo ?? Color.lerp(scheme.primary, Colors.white, 0.45)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        var progress = widget.initialOffset +
            (widget.reverse ? -_controller.value : _controller.value);
        progress -= progress.floorToDouble(); // остаток от деления на 1
        return CustomPaint(
          foregroundPainter: _BorderBeamPainter(
            progress: progress,
            radius: widget.borderRadius,
            strokeWidth: widget.borderWidth,
            beamLengthFraction: widget.beamLengthFraction,
            colorFrom: from,
            colorTo: to,
            glow: widget.glow,
            extras: widget.extras,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _BorderBeamPainter extends CustomPainter {
  _BorderBeamPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
    required this.beamLengthFraction,
    required this.colorFrom,
    required this.colorTo,
    required this.glow,
    required this.extras,
  });

  final double progress;
  final double radius;
  final double strokeWidth;
  final double beamLengthFraction;
  final Color colorFrom;
  final Color colorTo;
  final bool glow;
  final List<BorderBeamSpec> extras;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(0.0, size.width - strokeWidth),
      math.max(0.0, size.height - strokeWidth),
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final r = radius.clamp(0.0, math.min(rect.width, rect.height) / 2);
    final border = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));

    _drawBeam(
      canvas,
      rect,
      border,
      progress: progress,
      length: beamLengthFraction,
      from: colorFrom,
      to: colorTo,
    );

    for (final extra in extras) {
      var extraProgress =
          extra.offset + (extra.reverse ? -progress : progress);
      extraProgress -= extraProgress.floorToDouble();
      _drawBeam(
        canvas,
        rect,
        border,
        progress: extraProgress,
        length: extra.beamLengthFraction ?? beamLengthFraction,
        from: extra.colorFrom ?? colorFrom,
        to: extra.colorTo ?? colorTo,
      );
    }
  }

  /// Один луч: мягкий ореол (если включён) и сама комета.
  void _drawBeam(
    Canvas canvas,
    Rect rect,
    Path border, {
    required double progress,
    required double length,
    required Color from,
    required Color to,
  }) {
    if (glow) {
      canvas.drawPath(
        border,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 2.6
          ..isAntiAlias = true
          ..shader = _beamSweep(
            dim: 0.35,
            length: length,
            progress: progress,
            from: from,
            to: to,
          ).createShader(rect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    canvas.drawPath(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true
        ..shader = _beamSweep(
          dim: 1.0,
          length: length,
          progress: progress,
          from: from,
          to: to,
        ).createShader(rect),
    );
  }

  /// Вращающийся градиент-комета: прозрачный хвост, яркая голова.
  ///
  /// [dim] — множитель прозрачности (1 — сам луч, меньше — свечение).
  SweepGradient _beamSweep({
    required double dim,
    required double length,
    required double progress,
    required Color from,
    required Color to,
  }) {
    final beamLength = length.clamp(0.05, 0.8);
    // Начало хвоста и начало его затухания; строго растут: 0 < fade < tail < 1.
    final tail = (1.0 - beamLength).clamp(0.05, 1.0);
    final fade = (tail - 0.06).clamp(0.0, 1.0);

    return SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation(progress * math.pi * 2),
      colors: <Color>[
        Colors.transparent,
        Colors.transparent,
        to.withValues(alpha: to.a * dim),
        from.withValues(alpha: from.a * dim),
      ],
      stops: <double>[0.0, fade, tail, 1.0],
    );
  }

  @override
  bool shouldRepaint(covariant _BorderBeamPainter old) =>
      old.progress != progress ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.beamLengthFraction != beamLengthFraction ||
      old.colorFrom != colorFrom ||
      old.colorTo != colorTo ||
      old.glow != glow ||
      !listEquals(old.extras, extras);
}
