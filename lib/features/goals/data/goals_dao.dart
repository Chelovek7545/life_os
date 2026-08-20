import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'goal_model_extension.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  Future<void> createGoal(GoalsCompanion goal) async {
    await into(goals).insert(goal);
  }

  Future<List<Goal>> getGoalsBySphere(String sphereId) async {
    final dataList = await (select(goals)..where((g) => g.sphereId.equals(sphereId))).get();
    return dataList.map((data) => data.toDomain()).toList();
  }

  Stream<List<Goal>> watchGoalsBySphere(String sphereId) {
    return (select(goals)..where((g) => g.sphereId.equals(sphereId))).watch().map(
      (dataList) => dataList.map((data) => data.toDomain()).toList(),
    );
  }

  Future<List<Goal>> getAllGoals() async {
    final dataList = await select(goals).get();
    return dataList.map((data) => data.toDomain()).toList();
  }

  Stream<List<Goal>> watchAllGoals() {
    return select(goals).watch().map(
      (dataList) => dataList.map((data) => data.toDomain()).toList(),
    );
  }

  Future<GoalModel?> getGoalById(String id) async {
    try {
      final data = await (select(goals)..where((g) => g.id.equals(id))).getSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<Goal?> getGoal(String id) async {
    final model = await getGoalById(id);
    return model?.toDomain();
  }

  Future<void> updateGoal(Goal goal) async {
    await update(goals).replace(goal.copyWith(updatedAt: DateTime.now()).toDrift());
  }

  Future<void> deleteGoal(String id) async {
    await (delete(goals)..where((g) => g.id.equals(id))).go();
  }

  Future<void> deleteGoalsBySphere(String sphereId) async {
    await (delete(goals)..where((g) => g.sphereId.equals(sphereId))).go();
  }
}