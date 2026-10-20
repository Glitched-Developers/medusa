import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/bsu_theme.dart';
import '../transitions/fade_up_page_route.dart';
import 'initial_setup_screen_view.dart';

/// Заставка при запуске: анимированная иконка «Медузки».
///
/// Иконка пружинно появляется, вокруг расходятся волны (как у медузы
/// в воде), пульсирует свечение, вспыхивают искры, буквы названия
/// «выплывают» с сужающимся трекингом. Через ~2.6 с приложение плавно
/// уходит на стартовый экран.
class SplashScreenView extends StatefulWidget {
  const SplashScreenView({super.key});

  @override
  State<SplashScreenView> createState() => _SplashScreenViewState();
}

class _SplashScreenViewState extends State<SplashScreenView>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2600);

  late final AnimationController _controller;
  bool _started = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goAhead();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Для пользователей с отключённой анимацией в системе — короткий
    // тихий проход вместо полной заставки.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.duration = const Duration(milliseconds: 400);
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goAhead() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      FadeUpPageRoute(page: const InitialSetupScreenView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // Мягкое угасание заставки в самом конце — стартовый экран
          // наезжает поверх плавно и без дрожания.
          final outro = Curves.easeIn
              .transform(((t - 0.88) / 0.12).clamp(0.0, 1.0));
          return Opacity(
            opacity: 1 - outro,
            child: SafeArea(
              // Всё содержимое заставки строго по центру — и по горизонтали,
              // и по вертикали (раньше группа могла «уезжать» влево).
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MascotAnimation(t: t, scheme: scheme),
                      const SizedBox(height: 28),
                      _Title(t: t),
                      const SizedBox(height: 10),
                      _Subtitle(t: t),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Иконка-маскот со всеми эффектами вокруг: свечение, волны, искры.
class _MascotAnimation extends StatelessWidget {
  const _MascotAnimation({required this.t, required this.scheme});

  /// Прогресс основной анимации (0..1).
  final double t;
  final ColorScheme scheme;

  static const _sparkles = <(double, double, double, double)>[
    // (угол, радиус, фаза, размер)
    (0.2, 86, 0.00, 4.0),
    (1.1, 100, 0.35, 3.0),
    (2.0, 78, 0.70, 5.0),
    (2.9, 96, 0.15, 3.5),
    (3.8, 82, 0.55, 4.5),
    (4.7, 104, 0.85, 3.0),
    (5.6, 90, 0.25, 4.0),
  ];

  @override
  Widget build(BuildContext context) {
    // Пружинное появление иконки.
    final pop = Curves.elasticOut.transform((t / 0.5).clamp(0.0, 1.0));
    // Дыхание после появления — медленное покачивание, как у медузы.
    final breatheIn = ((t - 0.45) / 0.25).clamp(0.0, 1.0);
    final breathe = 1 + 0.045 * math.sin((t - 0.45) * math.pi * 5) * breatheIn;
    // Иконка чуть-чуть «встаёт ровно» после выскакивания.
    final settle = Curves.easeOut.transform((t / 0.6).clamp(0.0, 1.0));

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Мягкое пульсирующее свечение.
          _glow(scheme, settle),
          // Волны, расходящиеся от иконки.
          for (var i = 0; i < 4; i++) _ripple(scheme, i, settle),
          // Искры-искры вокруг.
          for (final s in _sparkles) _sparkle(scheme, s),
          // Иконка-листик — как была с самого начала.
          Transform.rotate(
            angle: (1 - settle) * -0.45,
            child: Transform.scale(
              scale: pop * breathe,
              child: Icon(
                Icons.spa_outlined,
                size: 150,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(ColorScheme scheme, double settle) {
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 5);
    return Transform.scale(
      scale: (0.92 + 0.07 * pulse) * settle,
      child: Opacity(
        opacity: (0.10 + 0.10 * pulse) * settle,
        child: Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _ripple(ColorScheme scheme, int index, double settle) {
    // Две волны по два кольца: вторая волна догоняет первую.
    final start = index < 2 ? 0.15 + index * 0.28 : 1.15 + (index - 2) * 0.28;
    final p = ((t - start) / 0.8).clamp(0.0, 1.0);
    if (p <= 0 || p >= 1) return const SizedBox.shrink();
    final eased = Curves.easeOut.transform(p);
    final size = 110 + 150 * eased;
    return Opacity(
      opacity: (1 - p) * 0.4 * settle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _sparkle(ColorScheme scheme, (double, double, double, double) s) {
    final (angle, baseRadius, phase, size) = s;
    // Искры «вспыхивают» по кругу и слегка дрейфуют.
    final wave = math.sin(2 * math.pi * ((t * 1.1 + phase) % 1));
    final appear = ((t - 0.2) / 0.3).clamp(0.0, 1.0);
    final opacity = appear * math.max(0, wave) * 0.9;
    if (opacity <= 0.01) return const SizedBox.shrink();
    final radius = baseRadius + 8 * math.sin(2 * math.pi * ((t * 0.7 + phase) % 1));
    final color = switch ((phase * 10).round() % 3) {
      0 => scheme.tertiary,
      1 => const Color(0xFFF2C33D),
      _ => scheme.secondary,
    };
    return Positioned(
      left: 130 + math.cos(angle - math.pi / 2) * radius - size / 2,
      top: 130 + math.sin(angle - math.pi / 2) * radius - size / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: 0.6 + 0.8 * math.max(0, wave),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Название: буквы «выплывают», просвет между ними сжимается.
///
/// Буквы рисуются по одной, а просвет — отдельными отступами: у
/// [TextStyle.letterSpacing] отступ добавляется и после последней буквы,
/// из-за чего слово визуально уезжало влево. Здесь такого нет — «Медузка»
/// всегда ровно по центру.
class _Title extends StatelessWidget {
  const _Title({required this.t});

  static const String _word = 'Медузка';

  final double t;

  @override
  Widget build(BuildContext context) {
    final p = Curves.easeOutCubic.transform(((t - 0.35) / 0.35).clamp(0.0, 1.0));
    final gap = 12 - 10 * p;
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, 26 * (1 - p)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _word.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Text(
                _word[i],
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                  color: BsuColors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final p = Curves.easeOutCubic.transform(((t - 0.72) / 0.22).clamp(0.0, 1.0));
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - p)),
        child: Text(
          'Расписание НИУ БелГУ',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
