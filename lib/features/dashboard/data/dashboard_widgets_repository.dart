import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/dashboard/data/dashboard_widgets_dao.dart';
import 'package:life_os/features/dashboard/domain/dashboard_item.dart';
import 'package:life_os/features/dashboard/domain/dashboard_widget_type.dart';
import 'package:uuid/uuid.dart';

class DashboardWidgetsRepository {
  final DashboardWidgetsDao _dao;

  DashboardWidgetsRepository(this._dao);

  Future<List<DashboardItem>> loadWidgets() async {
    final models = await _dao.getAll();
    return models.map((m) => _toDomain(m)).toList();
  }

  Future<void> saveWidget(DashboardItem item) async {
    await _dao.upsert(_toModel(item));
  }

  Future<void> removeWidget(String id) async {
    await _dao.delete(id);
  }

  Future<String> addWidget(DashboardItem item) async {
    final id = const Uuid().v4();
    item.id = id;
    await _dao.upsert(_toModel(item));
    return id;
  }

  Future<void> saveAll(List<DashboardItem> items) async {
    await _dao.replaceAll(items.map((i) => _toModel(i)).toList());
  }

  DashboardItem _toDomain(DashboardWidgetModel m) {
    return DashboardItem(
      id: m.id,
      x: m.x,
      y: m.y,
      w: m.w,
      h: m.h,
      type: _mapType(m.type),
    );
  }

  DashboardWidgetType _mapType(String typeName) {
    return switch (typeName) {
      'taskList' || 'tasks' => DashboardWidgetType.tasks,
      'timer' => DashboardWidgetType.timer,
      'habits' => DashboardWidgetType.habits,
      'calendar' => DashboardWidgetType.calendar,
      _ => DashboardWidgetType.tasks,
    };
  }

  DashboardWidgetModel _toModel(DashboardItem i) {
    return DashboardWidgetModel(
      id: i.id,
      x: i.x,
      y: i.y,
      w: i.w,
      h: i.h,
      type: i.type.name,
      config: null,
    );
  }
}
