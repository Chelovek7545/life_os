import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:life_os/features/lifegraph/data/graph_store.dart';
import 'package:life_os/features/lifegraph/presentation/v1.dart' as graph;

/// Хранилище позиций нод графа (layout) поверх контракта [graph.GraphStore].
///
/// Конкретный бэкенд (prefs / файл / БД / сервер) подменяется одной
/// реализацией [graph.GraphStore] — позиции при этом не привязаны к prefs.
///
/// Каждый граф (сфера) — отдельный слот со снимком:
/// `{ "v": 1, "entities": { "entityId": {"x": 100.0, "y": 200.0} } }`.
class GraphPositionsRepository {
  GraphPositionsRepository({graph.GraphStore? store})
      : _store = store ?? const PrefsGraphStore(prefix: 'graph_positions');

  final graph.GraphStore _store;

  static const int _version = 1;
  static const String _lastSphereKey = 'life_graph.last_sphere';

  /// Загружает позиции для графа (сферы).
  /// Возвращает null, если позиций ещё нет.
  Future<Map<String, Offset>?> loadPositions(String sphereId) async {
    final snap = await _store.load(sphereId);
    if (snap == null || snap['v'] != _version) return null;
    try {
      final entities = snap['entities'] as Map<String, dynamic>?;
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
    await _store.save(sphereId, {
      'v': _version,
      'entities': positions.map((id, offset) => MapEntry(id, {
        'x': offset.dx,
        'y': offset.dy,
      })),
    });
  }

  /// Удаляет позиции графа (например, при удалении сферы).
  Future<void> deletePositions(String sphereId) async {
    await _store.delete(sphereId);
  }

  // ── App-state (не слот графа): какая сфера открыта последней ─────────────

  Future<String?> loadLastSphereId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSphereKey);
  }

  Future<void> saveLastSphereId(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSphereKey, sphereId);
  }
}
