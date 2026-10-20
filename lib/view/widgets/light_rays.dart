import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Мягкие лучи света сверху — порт компонента LightRays.
///
/// От верхней кромки вниз идут широкие размытые полосы света: каждая
/// медленно покачивается, разгорается и гаснет (у всех свои длина волны
/// и задержка). Поверх — два мягких световых пятна у верхних углов.
///
/// Слой чисто декоративный: не ловит касания и не попадает в дерево
/// доступности. Полосы заранее рисуются в картинку и размываются один
/// раз, поэтому в кадре остаётся только поворот и прозрачность —
/// фон не тормозит интерфейс.
class LightRaysBackground extends StatefulWidget {
  const LightRaysBackground({
    super.key,
    this.color,
    this.count = 7,
    this.blur = 36,
    this.lengthFactor = 0.7,
    this.cycle = const Duration(seconds: 14),
    this.seed = 20261018,
  });

  /// Цвет лучей. По умолчанию — основной цвет темы (зелёный БелГУ).
  final Color? color;

  /// Сколько лучей в кадре.
  final int count;

  /// Размытие полос, px — как blur(36px) в примере.
  final double blur;

  /// Длина луча — доля высоты экрана (в примере 70vh).
  final double lengthFactor;

  /// Полный цикл: длительности лучей считаются от него.
  final Duration cycle;

  /// Зерно генератора: рисунок лучей всегда одинаковый.
  final int seed;

  @override
  State<LightRaysBackground> createState() => _LightRaysBackgroundState();
}

/// Один луч: где стоит, как наклонён, как качается.
class _LightRay {
  _LightRay({
    required this.left,
    required this.rotate,
    required this.widthFactor,
    required this.swing,
    required this.delay,
    required this.duration,
    required this.intensity,
  });

  /// Положение по горизонтали, % ширины.
  final double left;

  /// Базовый наклон, градусы.
  final double rotate;

  /// Ширина полосы — доля ширины экрана.
  final double widthFactor;

  /// Размах покачивания, градусы.
  final double swing;

  /// Задержка старта, с.
  final double delay;

  /// Длительность одного «вдоха», с.
  final double duration;

  /// Яркость в самой середине, 0..1.
  final double intensity;

  factory _LightRay.random(math.Random rnd, double cycle) => _LightRay(
        left: 8 + rnd.nextDouble() * 84,
        rotate: -28 + rnd.nextDouble() * 56,
        widthFactor: 0.15 + rnd.nextDouble() * 0.15,
        swing: 0.8 + rnd.nextDouble() * 1.8,
        delay: rnd.nextDouble() * cycle,
        duration: cycle * (0.75 + rnd.nextDouble() * 0.5),
        intensity: 0.6 + rnd.nextDouble() * 0.5,
      );
}

/// Отступ под размытие, чтобы края полосы не срезались картинкой.
const double _blurPadFactor = 2.5;

class _LightRaysBackgroundState extends State<LightRaysBackground>
    with SingleTickerProviderStateMixin {
  /// Время идёт «бесконечной» лентой: цикл контроллера длиннее любой сессии.
  static const _period = Duration(seconds: 600);

  late final AnimationController _controller;
  late final List<_LightRay> _rays;

  ui.Image? _rayImage;
  double _imageWidth = 0;
  double _imageLength = 0;
  bool _building = false;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.seed);
    _rays = List.generate(
      widget.count,
      (_) => _LightRay.random(rnd, widget.cycle.inMilliseconds / 1000),
    );
    _controller = AnimationController(vsync: this, duration: _period)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _rayImage?.dispose();
    super.dispose();
  }

  /// Готовит картинку одной полосы (белой: цвет накладывается при отрисовке).
  Future<void> _ensureImage(Size size) async {
    if (_building || size.isEmpty || _rays.isEmpty) return;

    final length = size.height * widget.lengthFactor;
    final width =
        size.width * _rays.map((r) => r.widthFactor).reduce(math.max);
    if (_rayImage != null &&
        (length - _imageLength).abs() < 1 &&
        (width - _imageWidth).abs() < 1) {
      return;
    }

    _building = true;
    _imageWidth = width;
    _imageLength = length;
    try {
      final image = await _renderRay(width, length);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _rayImage?.dispose();
        _rayImage = image;
        _building = false;
      });
    } catch (_) {
      _building = false;
    }
  }

  Future<ui.Image> _renderRay(double width, double length) async {
    // Полоса рисуется один раз: размытие дальше стоит почти ничего.
    const scale = 0.5;
    final sigma = widget.blur / 2;
    final pad = sigma * _blurPadFactor;
    final fullWidth = width + pad * 2;
    final fullHeight = length + pad * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);

    final rect = Rect.fromLTWH(pad, pad, width, length);
    final paint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        // 70% цвета сверху, растворяется вниз — как color-mix(..., transparent).
        const [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width / 2)),
      paint,
    );

    final picture = recorder.endRecording();
    return picture.toImage(
      (fullWidth * scale).round(),
      (fullHeight * scale).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // Лучи полупрозрачные, поэтому в местах пересечения полосы слегка
    // суммируются. Держим альфу умеренной: одиночный луч читается, а верх
    // экрана не превращается в плотную заливку.
    final color = widget.color ??
        (brightness == Brightness.dark
            ? Color.lerp(
                Theme.of(context).colorScheme.primary,
                Colors.white,
                0.35,
              )!
                .withValues(alpha: 0.4)
            : Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.34));

    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              _ensureImage(size);
              return CustomPaint(
                size: size,
                painter: _LightRaysPainter(
                  controller: _controller,
                  rays: _rays,
                  image: _rayImage,
                  imageWidth: _imageWidth,
                  imageLength: _imageLength,
                  blur: widget.blur,
                  color: color,
                  lengthFactor: widget.lengthFactor,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LightRaysPainter extends CustomPainter {
  _LightRaysPainter({
    required this.controller,
    required this.rays,
    required this.image,
    required this.imageWidth,
    required this.imageLength,
    required this.blur,
    required this.color,
    required this.lengthFactor,
  }) : super(repaint: controller);

  final AnimationController controller;
  final List<_LightRay> rays;
  final ui.Image? image;
  final double imageWidth;
  final double imageLength;
  final double blur;
  final Color color;
  final double lengthFactor;

  /// Лучи начинаются выше кромки (как -top-[12%]).
  static const _topOffset = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final elapsed =
        controller.value * controller.duration!.inMilliseconds / 1000;

    // Два мягких пятна у верхних углов.
    _glow(canvas, size, Offset(size.width * 0.20, size.height * 0.15), 0.45, 0.70);
    _glow(canvas, size, Offset(size.width * 0.80, size.height * 0.10), 0.35, 0.75);

    final image = this.image;
    if (image != null && imageWidth > 0) {
      _drawRays(canvas, size, image, elapsed);
    }
  }

  /// Полосы света: каждая покачивается и разгорается по своему графику.
  void _drawRays(Canvas canvas, Size size, ui.Image image, double elapsed) {
    final pad = blur / 2 * _blurPadFactor;
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final top = -size.height * _topOffset;

    for (final ray in rays) {
      // Луч живёт свой отрезок времени, между «вдохами» — пауза.
      final period = ray.duration * 1.1;
      var phase = (elapsed - ray.delay) % period;
      if (phase < 0) phase += period;
      final active = phase < ray.duration;
      final t = active ? phase / ray.duration : 0.0;
      final opacity = active ? ray.intensity * math.sin(math.pi * t) : 0.0;
      if (opacity <= 0.01) continue;

      final angle =
          (ray.rotate - ray.swing * math.cos(2 * math.pi * t)) * math.pi / 180;
      final width = size.width * ray.widthFactor + pad * 2;
      final target = Rect.fromLTWH(
        -width / 2,
        -pad,
        width,
        imageLength + pad * 2,
      );

      canvas.save();
      canvas.translate(size.width * ray.left / 100, top);
      canvas.rotate(angle);
      canvas.drawImageRect(
        image,
        source,
        target,
        Paint()
          ..filterQuality = FilterQuality.low
          ..colorFilter = ColorFilter.mode(
            color.withValues(alpha: opacity.clamp(0.0, 1.0)),
            BlendMode.srcIn,
          ),
      );
      canvas.restore();
    }
  }

  /// Радиальное световое пятно: цвет у центра, растворяется к краям.
  void _glow(
    Canvas canvas,
    Size size,
    Offset center,
    double mix,
    double stop,
  ) {
    final far = math.max(
      (Offset(size.width, size.height) - center).distance,
      center.distance,
    );
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        math.max(far, 1),
        <Color>[
          color.withValues(alpha: color.a * mix * 0.6),
          color.withValues(alpha: 0),
        ],
        <double>[0.0, stop],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _LightRaysPainter old) =>
      old.controller != controller ||
      old.rays != rays ||
      old.image != image ||
      old.imageWidth != imageWidth ||
      old.imageLength != imageLength ||
      old.blur != blur ||
      old.color != color ||
      old.lengthFactor != lengthFactor;
}
