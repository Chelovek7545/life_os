
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';

class PopUpMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const PopUpMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}


class GlassPopUpMenuButton extends StatelessWidget {
  const GlassPopUpMenuButton({
    super.key,
    required this.overflowActions,
  });

  final List<PopUpMenuAction> overflowActions;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Убираем стандартные подсветки и сплеши, чтобы сохранить чистый вид
      data: Theme.of(context).copyWith(
        highlightColor: Colors.transparent,
        splashColor: AppColors.primaryContainer
            .withValues(alpha: 0.1),
        hoverColor: Colors.transparent
        
      ),
      child: PopupMenuButton<PopUpMenuAction>(
        // Стиль выпадающего контейнера
        color: Colors.black.withValues(
          alpha: 0,
        ), // Тёмный полупрозрачный фон
        elevation: 10,
        shadowColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppRadius.xl,
          ),
          side: BorderSide(
            color: Colors.white.withValues(
              alpha: 0,
            ), // Тонкая матовая рамка
            width: 1,
          ),
        ),
        clipBehavior: Clip
            .antiAlias, // Чтобы блюр не вылезал за границы
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize:
              MaterialTapTargetSize.shrinkWrap,
        ),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert),
        onSelected: (action) => action.onTap(),
        itemBuilder: (context) => overflowActions
            .map(
              (
                action,
              ) => PopupMenuItem<PopUpMenuAction>(
                value: action,
                height: 44,
                padding:
                    const EdgeInsets.symmetric(
                      horizontal: 7,
                    ),
                child: GlassPanel(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    //mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        action.icon,
                        
                        color: Colors.white
                            .withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        action.label,
                        style: AppTypography.bodySm
                            .copyWith(
                              color: Colors.white
                                  .withValues(
                                    alpha: 0.9,
                                  ),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
