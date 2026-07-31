import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/dashboard/domain/dashboard_widget_type.dart';

class PlaceholderWidget extends StatelessWidget {
  final DashboardWidgetType type;
  const PlaceholderWidget({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(type.icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              type.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const Spacer(),
        Center(
          child: Text(
            'Coming soon',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
