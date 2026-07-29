import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final double blurLevel;
  final bool hasBlur; 
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0, // По умолчанию rounded-3xl (24px)
    this.borderColor,
    this.blurLevel = 8, 
    this.hasBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    var container = Container(
          padding: padding,
          decoration: BoxDecoration(
            color: hasBlur ? AppColors.surfaceGlass : AppColors.surfaceContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? AppColors.borderGlass,
              width: 1.0,
            ),
          ),
          child: child,
        );
    if (hasBlur) {
          return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurLevel, sigmaY: blurLevel),
        child: container
      ),
    );
    }
    else{
      return container;
    }

  }
}
