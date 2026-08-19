import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/settings/settings_service.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final double blurLevel;
  final bool hasBlur;
  final Color? color; 
  const GlassPanel(
    {
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0, // По умолчанию rounded-3xl (24px)
    this.borderColor,
    this.blurLevel = 8,
    this.hasBlur = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget container(bool blurAllowed) => Container(
      padding: padding,
      decoration: BoxDecoration(
        color: blurAllowed
            ? color ?? AppColors.surfaceGlass
            : AppColors.surfaceContainerLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.borderGlass,
          width: 1.0,
        ),
      ),
      child: child,
    );
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService.hasBlur,
      builder: (context, isGlobalBlurEnabled, _) {
        final bool effectiveBlur = isGlobalBlurEnabled && hasBlur;
        if (effectiveBlur) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurLevel, sigmaY: blurLevel),
              child: container(effectiveBlur),
            ),
          );
        } else {
          return container(effectiveBlur);
        }
      },
    );
  }
}
