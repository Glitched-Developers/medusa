import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Фон «круги на воде» — как компонент Ripple.
///
/// От центра (чуть выше середины) одна за другой расходятся тонкие
/// окружности: каждая медленно растёт, вспыхивает и тает. Живой, но
/// спокойный фон для экрана поиска группы или преподавателя: он ничего
/// не перекрывает и не перехватывает касания.
class RippleBackground extends StatefulWidget {
  const RippleBackground({
    super.key,
    this.color,
    this.rings = 7,
    this.period = const Duration(milliseconds: 3600),
    this.center = const Alignment(0, -0.12),
    this.maxRadiusFactor = 0.42,
    this.strokeWidth = 1.4,
    this.peakOpacity = 0.22,
  });

  /// Цвет колец. По умолчанию — основной цвет темы (фирменный зелёный БелГУ).
  final Color? color;

  /// Сколько колец одновременно «в воздухе».
  final int rings;

  /// Время, за которое кольцо проходит путь от центра до края.
  final Duration period;

  /// Центр, из которого расходятся круги.
  final Alignment center;

  /// Максимальный радиус = доля от большей стороны экрана.
  final double maxRadiusFactor;

  /// Толщина линии кольца.
  final double strokeWidth;

  /// Максимальная прозрачность кольца.
  final double peakOpacity;

  @override
  State<RippleBackground> createState() => _RippleBackgroundState();
}

class _RippleBackgroundState extends State<RippleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant RippleBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _RipplePainter(
              controller: _controller,
              color: color,
              rings: widget.rings,
              center: widget.center,
              maxRadiusFactor: widget.maxRadiusFactor,
              strokeWidth: widget.strokeWidth,
              peakOpacity: widget.peakOpacity,
            ),
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.controller,
    required this.color,
    required this.rings,
    required this.center,
    required this.maxRadiusFactor,
    required this.strokeWidth,
    required this.peakOpacity,
  }) : super(repaint: controller);

  final AnimationController controller;
  final Color color;
  final int rings;
  final Alignment center;
  final double maxRadiusFactor;
  final double strokeWidth;
  final double peakOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || rings <= 0) return;

    final origin = center.alongSize(size);
    final maxRadius = maxRadiusFactor * math.max(size.width, size.height);
    // Кольца идут «волной»: каждое следующее отстаёт ровно на один шаг,
    // а вместе они укладываются ровно в один период анимации.
    final step = 1 / rings;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (var i = 0; i < rings; i++) {
      var p = controller.value - i * step;
      p -= p.floorToDouble(); // кольцо живёт ровно один период
      if (p <= 0 || p >= 1) continue;

      final eased = Curves.easeOutQuad.transform(p);
      // Быстрая вспышка в начале и мягкое угасание к краю.
      final fade = p < 0.12 ? p / 0.12 : (1 - p) / 0.88;
      final alpha = (fade.clamp(0.0, 1.0)) * peakOpacity;
      if (alpha <= 0.002) continue;

      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(origin, maxRadius * eased, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.color != color ||
      oldDelegate.rings != rings ||
      oldDelegate.center != center ||
      oldDelegate.maxRadiusFactor != maxRadiusFactor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.peakOpacity != peakOpacity;
}
