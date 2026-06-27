import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

class EmptyPlaceholder extends StatelessWidget {
  const EmptyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text("Empty", style: AppTypography.headlineLgMobile.copyWith(color: AppColors.onSurfaceVariant)));
  }
}
