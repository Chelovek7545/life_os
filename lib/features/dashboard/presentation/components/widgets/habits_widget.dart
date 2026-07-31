import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

class HabitsWidget extends StatelessWidget {
  const HabitsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.repeat_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Habits',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const Spacer(),
        LinearProgressIndicator(
          value: 0.7,
          backgroundColor: Colors.white10,
          color: Colors.greenAccent,
        ),
        const SizedBox(height: 6),
        Text(
          '70% complete',
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
