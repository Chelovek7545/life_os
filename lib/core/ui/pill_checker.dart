//TO DO: Доделать
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class PillChecker extends StatefulWidget {
  final List<String> options;
  final Function(int) onSelectionChanged;

  const PillChecker({
    super.key,
    required this.options,
    required this.onSelectionChanged,
  });

  static Widget preview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: PillChecker(
        options: const ['Morning', 'Afternoon', 'Evening'],
        onSelectionChanged: (_) {},
      ),
    );
  }

  @override
  State<PillChecker> createState() => _PillCheckerState();
}

class _PillCheckerState extends State<PillChecker> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Row(
        children: List.generate(widget.options.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: GestureDetector(
                onTap: () {
                  setState(() => selectedIndex = index);
                  widget.onSelectionChanged(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.options[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
