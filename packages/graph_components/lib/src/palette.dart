import 'package:flutter/material.dart';

class GraphComponentPalette extends ThemeExtension<GraphComponentPalette> {
  const GraphComponentPalette({
    required this.surface,
    required this.surfaceBright,
    required this.surfaceDim,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.borderGlass,
  });
  final Color surface;
  final Color surfaceBright;
  final Color surfaceDim;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color borderGlass;

  static GraphComponentPalette of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return theme.extension<GraphComponentPalette>() ??
        GraphComponentPalette(
          surface: scheme.surface,
          surfaceBright: scheme.surfaceBright,
          surfaceDim: scheme.surfaceDim,
          surfaceContainer: scheme.surfaceContainer,
          surfaceContainerHigh: scheme.surfaceContainerHigh,
          onSurface: scheme.onSurface,
          onSurfaceVariant: scheme.onSurfaceVariant,
          borderGlass: scheme.outlineVariant,
        );
  }

  @override
  GraphComponentPalette copyWith({
    Color? surface,
    Color? surfaceBright,
    Color? surfaceDim,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? borderGlass,
  }) => GraphComponentPalette(
    surface: surface ?? this.surface,
    surfaceBright: surfaceBright ?? this.surfaceBright,
    surfaceDim: surfaceDim ?? this.surfaceDim,
    surfaceContainer: surfaceContainer ?? this.surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
    onSurface: onSurface ?? this.onSurface,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    borderGlass: borderGlass ?? this.borderGlass,
  );

  @override
  GraphComponentPalette lerp(covariant GraphComponentPalette? other, double t) {
    if (other == null) return this;
    return GraphComponentPalette(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
      surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceContainerHigh: Color.lerp(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
        t,
      )!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      borderGlass: Color.lerp(borderGlass, other.borderGlass, t)!,
    );
  }
}

Color graphColor(String hex, {Color fallback = const Color(0xFF4A90D9)}) {
  final value = hex.replaceFirst('#', '');
  if (value.length != 6 && value.length != 8) return fallback;
  final parsed = int.tryParse(
    value.length == 6 ? 'FF$value' : value,
    radix: 16,
  );
  return parsed == null ? fallback : Color(parsed);
}
