import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/dashboard/domain/dashboard_widget_type.dart';

class WidgetPickerPanel extends StatelessWidget {
  final ValueChanged<DashboardWidgetType> onWidgetSelected;

  const WidgetPickerPanel({super.key, required this.onWidgetSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.borderGlass)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Widget',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close, color: AppColors.onSurfaceVariant, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...DashboardWidgetType.values.map((type) => _PickerItem(
            type: type,
            onTap: () {
              onWidgetSelected(type);
              Navigator.of(context).pop();
            },
          )),
        ],
      ),
    );
  }
}

class _PickerItem extends StatelessWidget {
  final DashboardWidgetType type;
  final VoidCallback onTap;
  const _PickerItem({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(type.icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                type.displayName,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Icon(Icons.add, size: 18, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
