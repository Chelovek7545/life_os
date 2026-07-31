import 'package:life_os/features/dashboard/domain/dashboard_widget_type.dart';

class DashboardItem {
  String id;
  int x;
  int y;
  int w;
  int h;
  DashboardWidgetType type;

  DashboardItem({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.type,
  });
}
