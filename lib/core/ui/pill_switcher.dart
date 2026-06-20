import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

class PillSwitcher extends StatefulWidget {
  final List<String> options;
  final Function(int) onSelectionChanged;

  const PillSwitcher({
    Key? key,
    required this.options,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  State<PillSwitcher> createState() => _PillSwitcherState();
}

class _PillSwitcherState extends State<PillSwitcher> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Row(
        children: List.generate(widget.options.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => selectedIndex = index);
                widget.onSelectionChanged(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
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
          );
        }),
      ),
    );
  }
}