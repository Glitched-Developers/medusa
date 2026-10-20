import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/user_badge.dart';

/// Круглый значок профиля.
///
/// Обычные — цветные с иконкой, неполученные — серые с замком.
/// Эксклюзивные «живут»: по золотой окантовке бежит блик, а вокруг
/// мягко пульсирует сияние в цвет значка.
class BadgeMedal extends StatefulWidget {
  const BadgeMedal({
    super.key,
    required this.badge,
    this.earned = true,
    this.size = 44,
    this.animate = true,
  });

  final UserBadge badge;
  final bool earned;
  final double size;

  /// Выключить анимацию (например, в списках на много значков).
  final bool animate;

  @override
  State<BadgeMedal> createState() => _BadgeMedalState();
}

class _BadgeMedalState extends State<BadgeMedal>
    with SingleTickerProviderStateMixin {
  AnimationController? _shine;

  bool get _shouldShine =>
      widget.animate && widget.badge.isExclusive && widget.earned;

  @override
  void initState() {
    super.initState();
    if (_shouldShine) _start();
  }

  @override
  void didUpdateWidget(covariant BadgeMedal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldShine && _shine == null) {
      _start();
    } else if (!_shouldShine && _shine != null) {
      _shine!.dispose();
      _shine = null;
    }
  }

  void _start() {
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _shine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.badge.color ?? scheme.primary;
    final locked = !widget.earned;

    if (_shouldShine) return _buildExclusive(color);
    return _buildStatic(scheme, color, locked);
  }

  /// Обычный значок: цветной или под замком.
  Widget _buildStatic(ColorScheme scheme, Color color, bool locked) {
    final size = widget.size;
    final exclusive = widget.badge.isExclusive;
    final gold = exclusive && !locked;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gold
            ? const LinearGradient(
                colors: <Color>[Color(0xFFFFD54F), Color(0xFFFFA000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: gold
            ? null
            : locked
                ? scheme.surfaceContainerHighest
                : color.withValues(alpha: 0.16),
        border: Border.all(
          color: locked
              ? scheme.outlineVariant
              : gold
                  ? const Color(0xFFFFC107)
                  : color.withValues(alpha: 0.55),
          width: gold ? 2 : 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            widget.badge.icon,
            size: size * 0.5,
            color: locked ? scheme.outline : gold ? Colors.white : color,
          ),
          if (exclusive && locked) const _ExclusiveDot(),
          if (locked)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  size: size * 0.22,
                  color: scheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Эксклюзивный значок: металлическая окантовка с бегущим бликом,
  /// пульсирующее сияние и тёмный центр, чтобы иконка читалась.
  Widget _buildExclusive(Color color) {
    final size = widget.size;
    final light = Color.lerp(color, Colors.white, 0.75)!;
    final dark = Color.lerp(color, Colors.black, 0.62)!;

    return AnimatedBuilder(
      animation: _shine!,
      builder: (context, child) {
        final t = _shine!.value;
        final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(t * 2 * math.pi),
              colors: <Color>[
                color,
                light,
                color,
                color,
                light,
                color,
              ],
              stops: const <double>[0.0, 0.12, 0.32, 0.58, 0.78, 1.0],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.22 + 0.3 * pulse),
                blurRadius: size * (0.28 + 0.22 * pulse),
                spreadRadius: size * 0.04,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.all(size * 0.11),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.45),
              colors: <Color>[dark, Color.lerp(dark, Colors.black, 0.35)!],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Icon(
            widget.badge.icon,
            size: size * 0.44,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Маленькая золотая точка у запертых эксклюзивных значков:
/// намёк, что это не обычная награда.
class _ExclusiveDot extends StatelessWidget {
  const _ExclusiveDot();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 1,
      top: 1,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFFFFB300),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
