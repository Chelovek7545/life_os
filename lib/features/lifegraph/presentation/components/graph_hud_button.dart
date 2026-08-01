import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

/// Круглая кнопка HUD (зум-кластер) в стекле приложения.
class GraphHudButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const GraphHudButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<GraphHudButton> createState() => _GraphHudButtonState();
}

class _GraphHudButtonState extends State<GraphHudButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovered ? 1.1 : 1,
            duration: const Duration(milliseconds: 140),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hovered
                    ? AppColors.surfaceBright
                    : AppColors.surfaceContainer.withValues(alpha: 0.85),
                border: Border.all(color: AppColors.borderGlass),
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Icon(
                widget.icon,
                size: 17,
                color: _hovered ? AppColors.onSurface : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
