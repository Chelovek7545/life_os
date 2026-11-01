import 'package:goals_api/goals_api.dart' show GoalsApi;
import 'package:life_os/core/storage/storage_exception.dart';
export 'package:life_os/core/storage/storage_exception.dart';
import 'package:life_os/features/goals/data/goals_dao.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'package:life_os/features/goals/data/goal_model_extension.dart';

class GoalsRepository implements GoalsApi {
  GoalsRepository(this._dao);
  final GoalsDao _dao;

  @override
  Stream<List<Goal>> watchGoalsBySphere(String sphereId) =>
      _dao.watchGoalsBySphere(sphereId);

  @override
  Stream<List<Goal>> watchAllGoals() => _dao.watchAllGoals();

  @override
  Future<List<Goal>> getGoalsBySphere(String sphereId) =>
      _dao.getGoalsBySphere(sphereId);

  @override
  Future<List<Goal>> getAllGoals() => _dao.getAllGoals();

  @override
  Future<Goal?> getGoal(String id) => _dao.getGoal(id);

  @override
  Future<void> addGoal(Goal goal) async {
    try {
      await _dao.createGoal(goal.toDrift());
    } catch (error) {
      throw StorageException('Failed to save goal.', error);
    }
  }

  @override
  Future<void> updateGoal(Goal goal) async {
    try {
      await _dao.updateGoal(goal);
    } catch (error) {
      throw StorageException('Failed to update goal.', error);
    }
  }

  @override
  Future<void> deleteGoal(String id) async {
    try {
      await _dao.deleteGoal(id);
    } catch (e) {
      throw StorageException('Failed to delete goal.', e);
    }
  }

  @override
  Future<void> deleteGoalsBySphere(String sphereId) async {
    try {
      await _dao.deleteGoalsBySphere(sphereId);
    } catch (e) {
      throw StorageException('Failed to delete goals by sphere.', e);
    }
  }
}
