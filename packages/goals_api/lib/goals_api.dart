import 'src/goal.dart';
export 'src/goal.dart';

abstract interface class GoalsQueries {
  Stream<List<Goal>> watchGoalsBySphere(String sphereId);
  Stream<List<Goal>> watchAllGoals();
  Future<List<Goal>> getGoalsBySphere(String sphereId);
  Future<List<Goal>> getAllGoals();
  Future<Goal?> getGoal(String id);
}

abstract interface class GoalsCommands {
  Future<void> addGoal(Goal goal);
  Future<void> updateGoal(Goal goal);
  Future<void> deleteGoal(String id);
  Future<void> deleteGoalsBySphere(String sphereId);
}

abstract interface class GoalsApi implements GoalsQueries, GoalsCommands {}
