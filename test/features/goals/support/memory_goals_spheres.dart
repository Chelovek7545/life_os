import 'dart:async';
import 'package:goals_api/goals_api.dart';
import 'package:spheres_api/spheres_api.dart';

class MemorySource<T> {
  final items = <String, T>{};
  final listeners = <MultiStreamController<List<T>>>{};
  Completer<void>? entered;
  Completer<void>? gate;
  bool failWrite = false;
  bool failCancel = false;
  Stream<List<T>> watch() => Stream.multi((sink) {
    listeners.add(sink);
    sink.add(items.values.toList());
    sink.onCancel = () async {
      listeners.remove(sink);
      if (failCancel) throw StateError('Cannot cancel source');
    };
  });
  Future<void> write(void Function() action) async {
    if (entered case final signal? when !signal.isCompleted) signal.complete();
    await gate?.future;
    if (failWrite) {
      failWrite = false;
      throw StateError('Cannot write');
    }
    action();
    for (final sink in listeners) {
      sink.add(items.values.toList());
    }
  }
}

class MemoryGoals extends MemorySource<Goal> implements GoalsApi {
  @override
  Stream<List<Goal>> watchAllGoals() => watch();
  @override
  Stream<List<Goal>> watchGoalsBySphere(String id) => watch().map(
    (items) => items.where((item) => item.sphereId == id).toList(),
  );
  @override
  Future<List<Goal>> getAllGoals() async => items.values.toList();
  @override
  Future<List<Goal>> getGoalsBySphere(String id) async =>
      items.values.where((item) => item.sphereId == id).toList();
  @override
  Future<Goal?> getGoal(String id) async => items[id];
  @override
  Future<void> addGoal(Goal goal) => write(() => items[goal.id] = goal);
  @override
  Future<void> updateGoal(Goal goal) => write(() => items[goal.id] = goal);
  @override
  Future<void> deleteGoal(String id) => write(() => items.remove(id));
  @override
  Future<void> deleteGoalsBySphere(String id) =>
      write(() => items.removeWhere((_, item) => item.sphereId == id));
}

class MemorySpheres extends MemorySource<Sphere> implements SpheresApi {
  @override
  Stream<List<Sphere>> watchAllSpheres() => watch();
  @override
  Future<List<Sphere>> getAllSpheres() async => items.values.toList();
  @override
  Future<Sphere?> getSphere(String id) async => items[id];
  @override
  Future<void> addSphere(Sphere sphere) =>
      write(() => items[sphere.id] = sphere);
  @override
  Future<void> updateSphere(Sphere sphere) =>
      write(() => items[sphere.id] = sphere);
  @override
  Future<void> deleteSphere(String id) => write(() => items.remove(id));
}
