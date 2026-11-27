class GraphPoint {
  const GraphPoint(this.x, this.y);
  final double x;
  final double y;
  @override
  bool operator ==(Object other) =>
      other is GraphPoint && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
}

abstract interface class GraphPositionsStore {
  Future<Map<String, GraphPoint>?> loadPositions(String scopeId);
  Future<void> savePositions(String scopeId, Map<String, GraphPoint> positions);
  Future<Map<String, GraphPoint>> loadStandalonePositions(String scopeId);
  Future<void> saveStandalonePositions(
    String scopeId,
    Map<String, GraphPoint> positions,
  );
  Future<Set<String>> loadRemovedTaskIds(String scopeId);
  Future<void> saveRemovedTaskIds(String scopeId, Set<String> ids);
  Future<void> deletePositions(String scopeId);
  Future<String?> loadLastSphereId();
  Future<void> saveLastSphereId(String scopeId);
}
