import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Мягкие диагональные «лучи» на фоне — тёплое северное сияние.
///
/// Порт веб-компонента AnimatedRays: диагональные полосы, радужный
/// градиент и радиальная маска в правом верхнем углу. Анимация медленно
/// сдвигает полосы, поэтому фон «дышит», но не мешает читать сообщения.
class AuroraRays extends StatefulWidget {
  const AuroraRays({super.key, this.child, this.intensity = 1});

  /// Содержимое поверх фона.
  final Widget? child;

  /// Насколько ярко: 1 — как есть, 0.5 — приглушённо.
  final double intensity;

  @override
  State<AuroraRays> createState() => _AuroraRaysState();
}

class _AuroraRaysState extends State<AuroraRays>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (reduceMotion)
            CustomPaint(
              painter: _AuroraPainter(
                progress: 0.35,
                dark: dark,
                intensity: widget.intensity,
              ),
            )
          else
            AnimatedBuilder(
              animation: _controller!,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AuroraPainter(
                    progress: _controller!.value,
                    dark: dark,
                    intensity: widget.intensity,
                  ),
                );
              },
            ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.progress,
    required this.dark,
    required this.intensity,
  });

  final double progress;
  final bool dark;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    // Угол полос как в веб-версии: 100°.
    const angle = 100 * math.pi / 180;
    final period = size.shortestSide * 0.46;
    final shift = (progress * period * 2) % period;

    final blue = const Color(0xFF60A5FA);
    final magenta = const Color(0xFFE879F9);
    final teal = const Color(0xFF5EEAD4);
    final alpha = (dark ? 0.72 : 0.55) * intensity;

    // Полосы: цвет плавно появляется и гаснет, между ними — воздух.
    List<Color> stripes(double strength) => <Color>[
      blue.withValues(alpha: 0.0),
      blue.withValues(alpha: alpha * strength),
      blue.withValues(alpha: 0.0),
      magenta.withValues(alpha: 0.0),
      magenta.withValues(alpha: alpha * strength * 0.92),
      magenta.withValues(alpha: 0.0),
      teal.withValues(alpha: 0.0),
      teal.withValues(alpha: alpha * strength * 0.85),
      teal.withValues(alpha: 0.0),
    ];
    const stops = <double>[0.0, 0.12, 0.27, 0.38, 0.48, 0.62, 0.70, 0.82, 1.0];

    canvas.saveLayer(rect, Paint());

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-size.width / 2, -size.height / 2);

    final drawRect = Rect.fromCenter(
      center: rect.center,
      width: size.longestSide * 2.4,
      height: size.longestSide * 2.4,
    );

    // Широкое мягкое свечение — фон.
    final glowPeriod = period * 1.9;
    canvas.drawRect(
      drawRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-glowPeriod + shift * 0.6, 0),
          Offset(shift * 0.6, 0),
          stripes(0.55),
          stops,
          TileMode.repeated,
        ),
    );

    // Узкие лучи поверх — сам «аврорный» рисунок.
    canvas.drawRect(
      drawRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-period + shift, 0),
          Offset(shift, 0),
          stripes(1),
          stops,
          TileMode.repeated,
        ),
    );
    canvas.restore();

    // Маска: свет сконцентрирован в правом верхнем углу и растворяется
    // к центру экрана — сообщения на таком фоне читаются спокойно.
    final mask = ui.Gradient.radial(
      Offset(size.width * 1.02, -size.height * 0.06),
      size.longestSide * 0.82,
      <Color>[
        Colors.white,
        Colors.white.withValues(alpha: 0.55),
        Colors.white.withValues(alpha: 0.0),
      ],
      const <double>[0.0, 0.32, 1.0],
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = mask
        ..blendMode = BlendMode.dstIn,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.dark != dark ||
      oldDelegate.intensity != intensity;
}
