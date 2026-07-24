import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';

class DateHeader extends StatelessWidget {
  final DateTime anchorDate;
  final ValueChanged<DateTime> onDateChange;

  const DateHeader({super.key, required this.anchorDate, required this.onDateChange});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlassPanel(
              child: IconButton(
                icon: Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () => onDateChange(anchorDate.add(Duration(days: -1))),
              ),
            ),
            SizedBox(width: 12),
            GlassPanel(
              borderRadius: AppRadius.full,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Column(
                children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (Widget child, Animation<double> animation) {
              // Одновременно анимируем прозрачность и высоту
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                      sizeFactor: animation,
                      child: child,
                ),
              );
                        },
                        child: anchorDate.startOfDay == DateTime.now().startOfDay
                ?  Text(
                        'TODAY',
                        key: ValueKey('today_text'), // Key обязателен для работы AnimatedSwitcher
                        style: AppTypography.codeLabel,
                      )
                : const SizedBox.shrink(
                        key: ValueKey('empty_space'),
                      ),
                      ),
                      SizedBox(height: AppMargins.xs,),
                  Text(
                    formatDate(anchorDate),
                    style: AppTypography.headlineMd
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            GlassPanel(
              child: IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: () => onDateChange(anchorDate.add(Duration(days: 1))),
              ),
            ),
          ],
        ),
        
      ],
    );
  }
}
