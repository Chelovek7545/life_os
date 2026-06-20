import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_theme.dart';

// @Preview(group: "DateTimelineCard")
// Widget newPreview() => MaterialApp(
//   debugShowCheckedModeBanner: false,
//   theme: ThemeData.light(),
//   home: DateTimelineCard(day: "20", isSelected: true, weekday: 'mon'),
// );

class DateTimelineCard extends StatelessWidget {
  final bool isSelected;
  final String day;
  final String weekday;
  final VoidCallback? onTap;

  const DateTimelineCard({
    super.key,
    this.isSelected = false,
    required this.day,
    this.onTap, required this.weekday,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                  colors: [Color.fromARGB(255, 255, 97, 23), Color.fromARGB(255, 255, 124, 30)],
                )
              : null,
          color: isSelected
              ? Color.fromARGB(255, 255, 105, 35)
              : AppColors.surfaceContainerLow,
          // boxShadow: isSelected
          //     ? [
          //         BoxShadow(
          //           color: const Color(0xFF4C6FFF).withOpacity(0.35),
          //           blurRadius: 20,
          //           offset: const Offset(0, 8),
          //         ),
          //       ]
          //     : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                weekday,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? Colors.white70
                      : Colors.white.withValues(alpha: 0.2),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),
              Divider(
                radius: BorderRadius.circular(2),
                color: Colors.white.withValues(alpha: 0.30),
                thickness: 2,
                indent: 12,
                endIndent: 12,
              ),
              Text(
                day.toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
