import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

class SemanticTag extends StatelessWidget {
  final String label;
  final Color accentColor;
  final VoidCallback? onRemove;

  const SemanticTag({
    Key? key,
    required this.label,
    required this.accentColor,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: accentColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$label',
            style: AppTypography.bodySm.copyWith(
              color: accentColor,
              fontWeight: FontWeight.values[4], // font-medium
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 14, color: accentColor),
            ),
          ],
        ],
      ),
    );
  }
}
