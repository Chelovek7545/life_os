import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

const habitPanelBackground = Color(0xFF151313);
const habitPanelBorder = Color(0x24FFFFFF);
const habitPanelAccent = Color(0xFFFF9B63);
const habitPanelLabel = Color(0xFFEED0C3);
const habitPanelRadius = 22.0;
const habitPanelMaxWidth = 640.0;
const habitWeekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

BoxDecoration habitPanelCard({double radius = 16}) => BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF252121), Color(0xFF1B191A)],
  ),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: habitPanelBorder),
);

class HabitIconBadge extends StatelessWidget {
  const HabitIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: .16),
          AppColors.surface,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .38)),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, color: color, size: size * 24 / 44),
      ),
    );
  }
}
