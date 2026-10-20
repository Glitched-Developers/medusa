import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Плавное появление содержимого «из размытия» (порт BlurFade).
///
/// Содержимое проявляется: прозрачность 0 → 1, размытие сходит на нет,
/// карточка чуть подъезжает снизу. Задержкой задаётся волна — элементы
/// появляются по очереди, а не все сразу.
///
/// Пример:
/// ```dart
/// BlurFade(
///   delay: Duration(milliseconds: index * 70),
///   child: Card(...),
/// )
/// ```
class BlurFade extends StatefulWidget {
  const BlurFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.blur = 8,
    this.offset = 12,
  });

  /// Что показываем.
  final Widget child;

  /// Пауза перед началом — из неё складывается «волна».
  final Duration delay;

  /// Длительность проявления.
  final Duration duration;

  /// Стартовое размытие, px. 0 — только прозрачность и подъезд.
  final double blur;

  /// Стартовый сдвиг вниз, px.
  final double offset;

  @override
  State<BlurFade> createState() => _BlurFadeState();
}

class _BlurFadeState extends State<BlurFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Уважаем системное «уменьшение анимации»: показываем сразу.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _timer?.cancel();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        // Готово — отдаём содержимое как есть, без лишних слоёв.
        if (t >= 1) return child!;

        Widget result = child!;
        if (widget.offset != 0) {
          result = Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: result,
          );
        }
        if (widget.blur > 0) {
          final sigma = widget.blur * (1 - t);
          result = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: result,
          );
        }
        return Opacity(opacity: t.clamp(0.0, 1.0), child: result);
      },
      child: widget.child,
    );
  }
}
