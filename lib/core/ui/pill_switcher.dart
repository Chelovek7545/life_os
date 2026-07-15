import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';



class PillSwitcher extends StatefulWidget {
  final List<Widget> options;
  final Function(int) onSelectionChanged;
  final double? outerPadding;
  final double? paddingBetweenOptions;
  final double? innerPadding;

  const PillSwitcher({
    Key? key,
    required this.options,
    required this.onSelectionChanged,
    this.outerPadding,
    this.paddingBetweenOptions,
    this.innerPadding,
    
  }) : super(key: key);

  @override
  State<PillSwitcher> createState() => _PillSwitcherState();
}

class _PillSwitcherState extends State<PillSwitcher> {
  int selectedIndex = 0;

  BorderRadius radiusForIndex(int index, Radius inner, Radius outer) {


  if (index == 0) {
    return BorderRadius.only(
      topLeft: outer,
      bottomLeft: outer,
      topRight: inner,
      bottomRight: inner,
    );
  }

  if (index == widget.options.length - 1) {
    return BorderRadius.only(
      topLeft: inner,
      bottomLeft: inner,
      topRight: outer,
      bottomRight: outer,
    );
  }

  return BorderRadius.all(inner);
}

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:  EdgeInsets.all(widget.outerPadding ?? AppSpacing.sm),
      decoration: BoxDecoration(
        color:  AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Row(
        //mainAxisSize: MainAxisSize.max,
        children: List.generate(widget.options.length, (index) {
          final isSelected = index == selectedIndex;
          final child = widget.options[index];
          return Flexible(
            child: Padding(
              padding: EdgeInsets.all(widget.paddingBetweenOptions ?? 1),
              child: GestureDetector(
                onTap: () {
                  setState(() => selectedIndex = index);
                  widget.onSelectionChanged(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(widget.innerPadding ?? AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryContainer
                        : AppColors.surfaceContainerLow,
                    borderRadius: radiusForIndex(
                      index,
                      Radius.circular(AppRadius.md),
                      Radius.circular(AppRadius.xxl),
                      //AppRadius.xl - AppSpacing.sm
                      ),
            
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.inputGlass,
                    ),
                  ),
                  child: Center(
                    child: child
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
