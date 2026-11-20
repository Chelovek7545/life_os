import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';

class DateHeader extends StatelessWidget {
  final DateTime anchorDate;
  final ValueChanged<DateTime> onDateChange;

  const DateHeader({
    super.key,
    required this.anchorDate,
    required this.onDateChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlassPanel(
              borderRadius: AppRadius.full,
              child: IconButton(
                tooltip: 'Предыдущий день',
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white70,
                  size: 32,
                ),
                onPressed: () =>
                    onDateChange(DateUtils.addDaysToDate(anchorDate, -1)),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: anchorDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2140),
                  );
                  if (date != null && context.mounted) onDateChange(date);
                },
                child: GlassPanel(
                  borderRadius: AppRadius.full,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              // Одновременно анимируем прозрачность и высоту
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  fixedCrossAxisSizeFactor: 1,
                                  child: child,
                                ),
                              );
                            },
                        child:
                            anchorDate.startOfDay == DateTime.now().startOfDay
                            ? Text(
                                'TODAY',
                                key: ValueKey(
                                  'today_text',
                                ), // Key обязателен для работы AnimatedSwitcher
                                style: AppTypography.codeLabel,
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('empty_space'),
                              ),
                      ),
                      const SizedBox(height: AppMargins.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatDate(anchorDate),
                          style: AppTypography.headlineMd,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GlassPanel(
              borderRadius: AppRadius.full,

              child: IconButton(
                tooltip: 'Следующий день',
                icon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 32,
                ),
                onPressed: () =>
                    onDateChange(DateUtils.addDaysToDate(anchorDate, 1)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
