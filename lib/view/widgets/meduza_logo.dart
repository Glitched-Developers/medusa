import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:vector_graphics/vector_graphics.dart';

/// Фирменный логотип «Медузки» — тот же рисунок, что и на иконке приложения.
///
/// Используется на заставке, стартовом экране и экране приветствия,
/// чтобы приложение и его иконка выглядели одинаково.
class MeduzaLogo extends StatelessWidget {
  const MeduzaLogo({super.key, this.size = 120});

  /// Сторона квадрата, в который вписывается логотип.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const SvgPicture(
        AssetBytesLoader('assets/logo.svg.vec'),
        fit: BoxFit.contain,
      ),
    );
  }
}
