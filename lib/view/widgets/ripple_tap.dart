import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Круговой отклик на нажатие (порт RippleButton).
///
/// Из точки касания расходится залитый круг и растворяется — как круг на
/// воде. Рисуется поверх содержимого и обрезается по форме кнопки, поэтому
/// подходит любому child: кнопке, карточке, плашке.
///
/// Своё нажатие кнопка получает как обычно — [Listener] только наблюдает.
///
/// ```dart
/// RippleTap(
///   color: Colors.white.withValues(alpha: 0.45),
///   child: FilledButton(onPressed: ..., child: Text('Взять задачу')),
/// )
/// ```
class RippleTap extends StatefulWidget {
  const RippleTap({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = 100,
    this.duration = const Duration(milliseconds: 650),
    this.spread = 2.0,
  });

  /// Что оборачиваем — обычно кнопка.
  final Widget child;

  /// Цвет волны; null — светлая полупрозрачная (заметна на тёмной кнопке).
  final Color? color;

  /// Радиус скругления для обрезки волны. По умолчанию большой —
  /// получается «капсула», как у кнопок по умолчанию.
  final double borderRadius;

  /// Сколько живёт волна.
  final Duration duration;

  /// Во сколько раз радиус волны больше большей стороны кнопки.
  final double spread;

  @override
  State<RippleTap> createState() => _RippleTapState();
}

/// Точка нажатия и её номер — по нему волна убирается из списка.
class _RippleOrigin {
  const _RippleOrigin(this.id, this.position);

  final int id;
  final Offset position;
}

class _RippleTapState extends State<RippleTap> {
  final List<_RippleOrigin> _ripples = <_RippleOrigin>[];
  int _nextId = 0;

  void _startRipple(Offset position) {
    setState(() => _ripples.add(_RippleOrigin(_nextId++, position)));
  }

  void _removeRipple(int id) {
    if (!mounted) return;
    setState(() => _ripples.removeWhere((ripple) => ripple.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.white.withValues(alpha: 0.45);

    return Stack(
      // Важно: passthrough отдаёт ребёнку те же ограничения, что получила
      // обёртка. Иначе кнопка внутри SizedBox(width: double.infinity)
      // сжималась до своей ширины и прижималась влево.
      fit: StackFit.passthrough,
      children: [
        Listener(
          onPointerDown: (event) => _startRipple(event.localPosition),
          child: widget.child,
        ),
        for (final ripple in _ripples)
          Positioned.fill(
            child: IgnorePointer(
              // Обрезаем только волну: сама кнопка (и её тень) не режется.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<int>(ripple.id),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: widget.duration,
                  curve: Curves.easeOut,
                  onEnd: () => _removeRipple(ripple.id),
                  builder: (context, progress, _) => CustomPaint(
                    painter: _RipplePainter(
                      origin: ripple.position,
                      progress: progress,
                      color: color,
                      spread: widget.spread,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.origin,
    required this.progress,
    required this.color,
    required this.spread,
  });

  final Offset origin;
  final double progress;
  final Color color;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final maxSide = math.max(size.width, size.height);
    final radius = maxSide * spread * progress;
    // Ярче всего в начале, к концу растворяется полностью.
    final alpha = (color.a * (1 - progress)).clamp(0.0, 1.0);
    if (alpha <= 0 || radius <= 0) return;

    canvas.drawCircle(
      origin,
      radius,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.progress != progress ||
      old.origin != origin ||
      old.color != color ||
      old.spread != spread;
}
