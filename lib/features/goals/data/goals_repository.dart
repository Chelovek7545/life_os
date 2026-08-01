import 'package:life_os/features/goals/data/goals_dao.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'package:life_os/features/goals/data/goal_model_extension.dart';

class StorageException implements Exception {
  StorageException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

class GoalsRepository {
  GoalsRepository(this._dao);
  final GoalsDao _dao;

  Stream<List<Goal>> watchGoalsBySphere(String sphereId) => _dao.watchGoalsBySphere(sphereId);

  Stream<List<Goal>> watchAllGoals() => _dao.watchAllGoals();

  Future<List<Goal>> getGoalsBySphere(String sphereId) => _dao.getGoalsBySphere(sphereId);

  Future<List<Goal>> getAllGoals() => _dao.getAllGoals();

  Future<Goal?> getGoal(String id) => _dao.getGoal(id);

  Future<void> addGoal(Goal goal) async {
    try {
      await _dao.createGoal(goal.toDrift());
    } catch (error) {
      throw StorageException('Failed to save goal.', error);
    }
  }

  Future<void> updateGoal(Goal goal) async {
    try {
      await _dao.updateGoal(goal);
    } catch (error) {
      throw StorageException('Failed to update goal.', error);
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      await _dao.deleteGoal(id);
    } catch (e) {
      throw StorageException('Failed to delete goal.', e);
    }
  }

  Future<void> deleteGoalsBySphere(String sphereId) async {
    try {
      await _dao.deleteGoalsBySphere(sphereId);
    } catch (e) {
      throw StorageException('Failed to delete goals by sphere.', e);
    }
  }
}