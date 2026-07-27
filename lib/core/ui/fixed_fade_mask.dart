import 'package:flutter/material.dart';
class FixedVerticalFadeMask extends StatelessWidget {
  final Widget child;
  final double topFade;    // Высота затухания сверху в пикселях
  final double bottomFade; // Высота затухания снизу в пикселях

  const FixedVerticalFadeMask({
    super.key,
    required this.child,
    this.topFade = 24.0,
    this.bottomFade = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        final double height = bounds.height;
        if (height <= 0) {
          return const LinearGradient(colors: [Colors.black]).createShader(bounds);
        }

        // Вычисляем процентные остановки отдельно для верха и низа
        final double topStop = (topFade / height).clamp(0.0, 1.0);
        final double bottomStop = (1.0 - (bottomFade / height)).clamp(0.0, 1.0);

        // Проверяем, чтобы зоны затухания не перекрывали друг друга
        final double effectiveTop = topStop > bottomStop ? bottomStop : topStop;
        final double effectiveBottom = bottomStop < topStop ? topStop : bottomStop;

        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [
            0.0,
            effectiveTop,    // Конец верхнего затухания
            effectiveBottom, // Начало нижнего затухания
            1.0,
          ],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}