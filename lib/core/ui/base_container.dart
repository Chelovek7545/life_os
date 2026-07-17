import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class BaseContainer extends StatelessWidget {
  const BaseContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderGlass, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: EdgeInsets.all(AppSpacing.xl),
      child: child,
    );
  }
}
