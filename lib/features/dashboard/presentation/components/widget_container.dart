import 'package:flutter/material.dart';
import 'package:life_os/features/dashboard/domain/dashboard_item.dart';
import 'package:life_os/features/dashboard/domain/dashboard_widget_type.dart';
import 'package:life_os/features/dashboard/presentation/components/widgets/calendar_widget.dart';
import 'package:life_os/features/dashboard/presentation/components/widgets/habits_widget.dart';
import 'package:life_os/features/dashboard/presentation/components/widgets/task_list_widget.dart';
import 'package:life_os/features/dashboard/presentation/components/widgets/timer_widget.dart';

class DashboardItemWidget extends StatefulWidget {
  final DashboardItem item;
  final bool isEditing;
  final double cellWidth;
  final double cellHeight;
  final double spacing;
  final ValueChanged<int>? onTap;
  final VoidCallback? onResizeStart;
  final ValueChanged<Offset>? onResizeUpdate;
  final ValueChanged<Offset>? onResizeEnd;

  const DashboardItemWidget({
    super.key,
    required this.item,
    required this.isEditing,
    required this.cellWidth,
    required this.cellHeight,
    required this.spacing,
    this.onTap,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
  });

  @override
  State<DashboardItemWidget> createState() => _DashboardItemWidgetState();
}

class _DashboardItemWidgetState extends State<DashboardItemWidget> {
  double _resizeDx = 0;
  double _resizeDy = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E22),
        borderRadius: BorderRadius.circular(16),
        border: widget.isEditing
            ? Border.all(color: Colors.blueAccent.withValues(alpha: 0.8), width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
            if (widget.isEditing)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => widget.onTap?.call(1),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            if (widget.isEditing)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanStart: (_) => widget.onResizeStart?.call(),
                  onPanUpdate: (details) {
                    setState(() {
                      _resizeDx += details.delta.dx;
                      _resizeDy += details.delta.dy;
                    });
                    widget.onResizeUpdate?.call(Offset(_resizeDx, _resizeDy));
                  },
                  onPanEnd: (_) {
                    final delta = Offset(_resizeDx, _resizeDy);
                    setState(() {
                      _resizeDx = 0;
                      _resizeDy = 0;
                    });
                    widget.onResizeEnd?.call(delta);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    color: Colors.transparent,
                    child: const Icon(
                      Icons.south_east,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return switch (widget.item.type) {
      DashboardWidgetType.tasks => const TaskListWidget(),
      DashboardWidgetType.timer => const TimerWidget(),
      DashboardWidgetType.habits => const HabitsWidget(),
      DashboardWidgetType.calendar => const CalendarWidget(),
    };
  }
}
