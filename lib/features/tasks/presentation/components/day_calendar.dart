import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/glass_panel.dart';

const _white20 = Color(0x33FFFFFF);
const _white30 = Color(0x4DFFFFFF);
const _white80 = Color(0xCCFFFFFF);

class DateTimelineCard extends StatelessWidget {
  final bool isSelected;
  final String day;
  final String weekday;
  final VoidCallback? onTap;

  const DateTimelineCard({
    super.key,
    this.isSelected = false,
    required this.day,
    this.onTap,
    required this.weekday,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        blurLevel: 12,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            //curve: Curves.easeOut,
            width: 64,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderGlass),
              borderRadius: BorderRadius.circular(24),
        
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromARGB(255, 255, 97, 23),
                        Color.fromARGB(255, 255, 124, 30),
                      ],
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    weekday,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? Colors.white70
                          : _white20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      height: 2,
                      decoration: BoxDecoration(
                        color: _white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    day.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : _white80,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }
}
