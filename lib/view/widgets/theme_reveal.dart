import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Ключ корневого [RepaintBoundary] приложения.
///
/// Из него «фотографируется» текущий экран, чтобы смена темы шла как
/// круговая шторка: новая тема открывается из точки нажатия, а старый
/// кадр уходит за край растущего круга.
final GlobalKey appRootBoundaryKey = GlobalKey(debugLabel: 'appRootBoundary');

/// Длительность перехода.
const Duration _revealDuration = Duration(milliseconds: 620);

/// Плавная смена темы «растущим кругом» от точки нажатия.
///
/// [switchTheme] должен только переключить тему (например, `themeProvider`
/// или контроллер настроек) — всё остальное делает сам переход. Если
/// снимок экрана получить не удалось (или нет Overlay), тема просто
/// переключается мгновенно: переход не должен ничего ломать.
Future<void> animateThemeSwitch({
  required BuildContext context,
  required VoidCallback switchTheme,
  Offset? origin,
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final media = MediaQuery.maybeOf(context);
  final boundary =
      appRootBoundaryKey.currentContext?.findRenderObject();

  // Запасной путь: нечего фотографировать — переключаем как раньше.
  if (overlay == null || boundary is! RenderRepaintBoundary) {
    switchTheme();
    return;
  }

  final dpr = media?.devicePixelRatio ?? 1;
  final from = origin ?? _centerOf(context);

  ui.Image? snapshot;
  try {
    snapshot = await boundary.toImage(pixelRatio: dpr.clamp(1.0, 2.0));
  } catch (_) {
    snapshot = null;
  }

  if (snapshot == null || !context.mounted) {
    snapshot?.dispose();
    switchTheme();
    return;
  }

  // Тему переключаем и снимок кладём в тот же кадр: новая тема успевает
  // отрисоваться под фотографией, вспышки «некрашеного» экрана нет.
  switchTheme();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ThemeReveal(
      image: snapshot!,
      origin: from,
      onCompleted: entry.remove,
    ),
  );
  overlay.insert(entry);
}

/// Центр экрана — центр круга, когда точку нажатия передать не удалось.
Offset _centerOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    return box.localToGlobal(box.size.center(Offset.zero));
  }
  final media = MediaQuery.maybeOf(context);
  if (media != null) return media.size.center(Offset.zero);
  return Offset.zero;
}

/// Точка внутри плитки [anchor]: по умолчанию — её центр, а для свитча
/// удобнее правый край ([fromRight] — отступ от правого края), где он и стоит.
Offset anchorOrigin(
  BuildContext context,
  RenderObject? anchor, {
  double? fromRight,
}) {
  if (anchor is! RenderBox || !anchor.hasSize) return _centerOf(context);
  final dx =
      fromRight == null ? anchor.size.width / 2 : anchor.size.width - fromRight;
  return anchor.localToGlobal(Offset(dx, anchor.size.height / 2));
}

/// Фотография старого экрана, которая уходит за край растущего круга.
class _ThemeReveal extends StatefulWidget {
  const _ThemeReveal({
    required this.image,
    required this.origin,
    required this.onCompleted,
  });

  final ui.Image image;
  final Offset origin;
  final VoidCallback onCompleted;

  @override
  State<_ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<_ThemeReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _revealDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onCompleted();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return ClipPath(
              clipper: _RevealClipper(
                origin: widget.origin,
                progress: Curves.easeInOutCubic.transform(_controller.value),
              ),
              child: SizedBox.expand(
                child: RawImage(
                  image: widget.image,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.low,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Прямоугольник экрана с вырезанным кругом — «дырка», через которую
/// видно уже переключённую тему.
class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper({required this.origin, required this.progress});

  final Offset origin;
  final double progress;

  @override
  Path getClip(Size size) {
    final dx = math.max(origin.dx, size.width - origin.dx);
    final dy = math.max(origin.dy, size.height - origin.dy);
    final maxRadius = math.sqrt(dx * dx + dy * dy);
    final hole = Path()
      ..addOval(
        Rect.fromCircle(center: origin, radius: maxRadius * progress),
      );
    final full = Path()..addRect(Offset.zero & size);
    return Path.combine(PathOperation.difference, full, hole);
  }

  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.origin != origin;
}
