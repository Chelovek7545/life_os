import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Хранилище позиций нод графа в SharedPreferences.
///
/// Каждый граф (сфера) имеет свой JSON-документ:
/// key = 'graph_positions:sphereId'
/// value = { "version": 1, "entities": { "entityId": {"x": 100.0, "y": 200.0} } }
class GraphPositionsRepository {
  static const String _keyPrefix = 'graph_positions:';
  static const int _version = 1;

  /// Загружает позиции для графа (сферы).
  /// Возвращает null, если позиций ещё нет.
  Future<Map<String, Offset>?> loadPositions(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$sphereId');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != _version) return null;
      final entities = json['entities'] as Map<String, dynamic>?;
      if (entities == null) return null;
      return entities.map((id, data) {
        final map = data as Map<String, dynamic>;
        return MapEntry(id, Offset(
          (map['x'] as num).toDouble(),
          (map['y'] as num).toDouble(),
        ));
      });
    } catch (_) {
      return null;
    }
  }

  /// Сохраняет позиции для графа.
  Future<void> savePositions(String sphereId, Map<String, Offset> positions) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode({
      'version': _version,
      'entities': positions.map((id, offset) => MapEntry(id, {
        'x': offset.dx,
        'y': offset.dy,
      })),
    });
    await prefs.setString('$_keyPrefix$sphereId', json);
  }

  /// Удаляет позиции графа (например, при удалении сферы).
  Future<void> deletePositions(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$sphereId');
  }
}