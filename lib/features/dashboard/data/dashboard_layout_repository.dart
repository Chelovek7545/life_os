import 'dart:convert';

import 'package:life_os/features/dashboard/domain/dashboard_item.dart';
import 'package:life_os/features/dashboard/domain/dashboard_widget_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DashboardLayoutRepository {
  static const String _layoutKey = 'dashboard_layout';
  static const int _version = 1;

  /// Возвращает null, если раскладка ещё не сохранена или повреждена.
  Future<List<DashboardItem>?> loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_layoutKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>;
      return items
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLayout(List<DashboardItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _layoutKey,
      jsonEncode({
        'version': _version,
        'items': items.map(_toJson).toList(),
      }),
    );
  }

  String generateId() => const Uuid().v4();

  Map<String, dynamic> _toJson(DashboardItem item) {
    return {
      'id': item.id,
      'x': item.x,
      'y': item.y,
      'w': item.w,
      'h': item.h,
      'type': item.type.name,
    };
  }

  DashboardItem _fromJson(Map<String, dynamic> json) {
    return DashboardItem(
      id: json['id'] as String,
      x: json['x'] as int,
      y: json['y'] as int,
      w: json['w'] as int,
      h: json['h'] as int,
      type: _mapType(json['type'] as String?),
    );
  }

  DashboardWidgetType _mapType(String? typeName) {
    return switch (typeName) {
      'taskList' || 'tasks' => DashboardWidgetType.tasks,
      'timer' => DashboardWidgetType.timer,
      'habits' => DashboardWidgetType.habits,
      'calendar' => DashboardWidgetType.calendar,
      _ => DashboardWidgetType.tasks,
    };
  }
}
