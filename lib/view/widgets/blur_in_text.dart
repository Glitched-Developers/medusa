import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Как резать текст на кусочки для анимации.
enum BlurInBy {
  /// По одной букве — самый «живой» вариант для заголовков.
  character,

  /// По словам — компромисс для длинных абзацев.
  word,

  /// Целиком — для больших блоков текста.
  line,
}

/// Текст, который проявляется из размытия и чуть поднимается снизу.
///
/// Порт эффекта `blurInUp` из Magic UI: каждая буква (или слово) стартует
/// прозрачной и «расфокусированной», а затем становится чёткой. Анимация
/// проигрывается один раз — при открытии экрана.
///
/// Размытие рисуется тенью с нулевым смещением: так текст остаётся обычным
/// абзацем, и переносы строк работают по словам, а не по буквам.
class BlurInText extends StatefulWidget {
  const BlurInText(
    this.text, {
    super.key,
    this.style,
    this.by = BlurInBy.character,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.stagger = const Duration(milliseconds: 14),
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final BlurInBy by;

  /// Задержка перед началом — чтобы абзацы шли друг за другом.
  final Duration delay;

  /// Сколько «фокусируется» один кусочек.
  final Duration duration;

  /// Пауза между соседними кусочками.
  final Duration stagger;

  final TextAlign? textAlign;

  @override
  State<BlurInText> createState() => _BlurInTextState();
}

class _BlurInTextState extends State<BlurInText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<String> _units;
  late final int _staggerMs;
  late final int _durationMs;

  @override
  void initState() {
    super.initState();
    _units = _split(widget.text, widget.by);
    _durationMs = widget.duration.inMilliseconds;

    // Длинный заголовок не должен «фокусироваться» целую вечность:
    // общий разброс задержек ограничен ~0.7 с.
    final maxStagger = _units.isEmpty ? 0 : 700 ~/ _units.length;
    _staggerMs = math.max<int>(
      4,
      math.min<int>(widget.stagger.inMilliseconds, maxStagger),
    );

    final totalMs =
        _staggerMs * math.max<int>(0, _units.length - 1) + _durationMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || _units.isEmpty) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
      );
    }

    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    final color = base.color ?? Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final nowMs =
                _controller.value * _controller.duration!.inMilliseconds;
            final overall = Curves.easeOutCubic.transform(_controller.value);
            return Transform.translate(
              // Лёгкий подъём всего блока — как в blurInUp.
              offset: Offset(0, 8 * (1 - overall)),
              child: Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    for (var i = 0; i < _units.length; i++)
                      TextSpan(
                        text: _units[i],
                        style: _styleAt(i, nowMs, color),
                      ),
                  ],
                ),
                textAlign: widget.textAlign,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Стиль кусочка: пока он не «в фокусе» — полупрозрачный и с тенью,
  /// размывающей букву. В конце анимации стиль не переопределяется.
  TextStyle? _styleAt(int index, double nowMs, Color color) {
    final t = ((nowMs - index * _staggerMs) / _durationMs).clamp(0.0, 1.0);
    if (t >= 1) return null;
    final eased = Curves.easeOutCubic.transform(t);
    return TextStyle(
      color: color.withValues(alpha: eased),
      shadows: [
        Shadow(
          color: color.withValues(alpha: eased * 0.85),
          blurRadius: 12 * (1 - eased),
          offset: Offset.zero,
        ),
      ],
    );
  }

  static List<String> _split(String text, BlurInBy by) {
    if (text.isEmpty) return const <String>[];
    switch (by) {
      case BlurInBy.character:
        return text.characters.toList(growable: false);
      case BlurInBy.word:
        return RegExp(r'\S+\s*')
            .allMatches(text)
            .map((match) => match.group(0)!)
            .toList(growable: false);
      case BlurInBy.line:
        return <String>[text];
    }
  }
}
