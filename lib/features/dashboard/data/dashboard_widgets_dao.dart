import 'package:life_os/core/database/database.dart';

/// DAO-слой для таблицы [DashboardWidgets] в Drift.
///
/// Полностью stateless — все операции идут напрямую в БД.
/// Используется [DashboardWidgetsRepository], который
/// конвертирует Drift-модели в доменные [DashboardWidget].
///
/// Таблица:
///   id (TEXT PK), x, y, w, h (INT), type (TEXT), config (TEXT?).
class DashboardWidgetsDao {
  final AppDatabase _db;
  DashboardWidgetsDao(this._db);

  Future<List<DashboardWidgetModel>> getAll() {
    return _db.select(_db.dashboardWidgets).get();
  }

  Stream<List<DashboardWidgetModel>> watchAll() {
    return _db.select(_db.dashboardWidgets).watch();
  }

  Future<void> upsert(DashboardWidgetModel widget) {
    return _db.into(_db.dashboardWidgets).insertOnConflictUpdate(widget);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.dashboardWidgets)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  Future<void> deleteAll() async {
    await _db.delete(_db.dashboardWidgets).go();
  }

  /// Полная замена всех записей (batch).
  /// Используется при инициализации дефолтных виджетов.
  Future<void> replaceAll(List<DashboardWidgetModel> widgets) async {
    await _db.batch((batch) {
      batch.deleteAll(_db.dashboardWidgets);
      for (final w in widgets) {
        batch.insert(_db.dashboardWidgets, w);
      }
    });
  }
}
