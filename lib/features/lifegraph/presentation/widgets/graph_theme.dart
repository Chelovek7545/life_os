import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as graph;

/// Тема графа в палитре приложения (тёмная тема PULSE).
class AppGraphThemes {
  const AppGraphThemes._();

  static final graph.GraphViewTheme dark = graph.GraphViewTheme(
    // Рампа акцентов по глубине: сфера / цель / проект / задача.
    depthRamp: const [
      Color(0xFFFF5C00),
      Color(0xFFB78AFF),
      Color(0xFF58A6FF),
      Color(0xFF34D3A6),
    ],
    canvas: AppColors.surfaceDim,
    ambientA: const Color(0x1AFF5C00),
    ambientB: const Color(0x18B78AFF),
    gridMinor: const Color(0x0DFFFFFF),
    gridMajor: const Color(0x17FFFFFF),
    gridSpacing: 42,
    surface: AppColors.surfaceContainer,
    surfaceHover: const Color(0xFF2A2626),
    border: AppColors.borderGlass,
    text: AppColors.onSurface,
    textDim: AppColors.onSurfaceVariant,
    shadow: const Color(0x66000000),
    controlsBg: const Color(0xCC141212),
  );
}
