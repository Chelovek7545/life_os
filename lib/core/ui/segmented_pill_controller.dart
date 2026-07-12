import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

class SegmentedPillControl extends StatefulWidget {
  final List<String> tabs;
  final Function(int) onTabChanged;

  const SegmentedPillControl({
    Key? key,
    required this.tabs,
    required this.onTabChanged,
  }) : super(key: key);

  @override
  State<SegmentedPillControl> createState() => _SegmentedPillControlState();
}

class _SegmentedPillControlState extends State<SegmentedPillControl> {
  int _currentIdx = 0;

  @override
  Widget build(BuildContext context) {
    final totalTabs = widget.tabs.length;
    
    // Вычисляем координату X для Alignment (от -1.0 до 1.0)
    final alignmentX = totalTabs <= 1 
        ? 0.0 
        : -1.0 + (_currentIdx * (2.0 / (totalTabs - 1)));

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Stack(
        children: [
          // Слой 1: Скользящий оранжевый (primaryContainer) фон
          Positioned.fill(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic, // Мягкий и естественный эффект скольжения
              alignment: Alignment(alignmentX, 0.0),
              child: FractionallySizedBox(
                widthFactor: 1 / totalTabs, // Занимает ровно одну вкладку
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
            ),
          ),
          
          // Слой 2: Интерактивные вкладки поверх фона
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(totalTabs, (index) {
              final isSelected = index == _currentIdx;
              
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // Чтобы кликалась вся область вкладки
                  onTap: () {
                    setState(() => _currentIdx = index);
                    widget.onTabChanged(index);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    alignment: Alignment.center,
                    // Плавно меняем цвет текста при смене вкладки
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: AppTypography.headlineLg.copyWith(
                        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                        //fontWeight: FontWeight.w100,
                        fontSize: 16
                      ),
                      child: Text(widget.tabs[index],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}