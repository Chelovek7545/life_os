import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

class VibrantGradientButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;

  const VibrantGradientButton({
    Key? key,
    required this.text,
    this.icon,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<VibrantGradientButton> createState() => _VibrantGradientButtonState();
}

class _VibrantGradientButtonState extends State<VibrantGradientButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) =>
          setState(() => _scale = 0.98), // Эффект active:scale-[0.98]
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onPressed,
      child: Transform.scale(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 64, // h-16
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: AppColors.vibrantGradient,
            borderRadius: BorderRadius.circular(16), // rounded-2xl
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white),
                const SizedBox(width: 12),
              ],
              Text(
                widget.text,
                style: AppTypography.bodyMd.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
