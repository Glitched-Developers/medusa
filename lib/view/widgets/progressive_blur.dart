import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Край списка, который «расфокусируется» — верхний или нижний.
enum ProgressiveBlurPosition { top, bottom }

/// Плавное размытие у края экрана: ближе к центру контент в фокусе,
/// у самой кромки — размыт. Так лента выглядит собраннее, а глаз
/// цепляется за карточки в середине.
///
/// Кладётся поверх списка в [Stack] и не перехватывает жесты.
///
/// Под капотом — несколько вложенных [BackdropFilter]: широкий и слабый
/// снизу, узкие и сильные ближе к кромке. Каждый следующий слой размывает
/// уже размытое, поэтому сила растёт к краю ступенями по несколько
/// пикселей — переход читается как плавный.
class ProgressiveBlur extends StatelessWidget {
  const ProgressiveBlur({
    super.key,
    this.position = ProgressiveBlurPosition.bottom,
    this.height = 72,
    this.sigma = 5,
    this.bands = 5,
  });

  final ProgressiveBlurPosition position;
  final double height;

  /// Сила размытия у самой кромки (с учётом наложения слоёв).
  final double sigma;

  /// Сколько слоёв: больше — плавнее, но дороже.
  final int bands;

  @override
  Widget build(BuildContext context) {
    if (height <= 0 || sigma <= 0) return const SizedBox.shrink();
    final count = bands < 1 ? 1 : bands;
    final step = height / count;
    final fromTop = position == ProgressiveBlurPosition.top;

    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            // От широкого слоя с лёгким размытием к узкому и сильному:
            // получается градиент фокуса, а не резкая полоса.
            for (var i = count; i >= 1; i--)
              Positioned(
                top: fromTop ? 0 : null,
                bottom: fromTop ? null : 0,
                left: 0,
                right: 0,
                height: step * i,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: sigma * (count + 1 - i) / count,
                      sigmaY: sigma * (count + 1 - i) / count,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
