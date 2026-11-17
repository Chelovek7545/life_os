import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:goals_api/goals_api.dart' show Goal;
import 'package:life_os/features/tasks/data/task_mutation_journal.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'goal_model_extension.dart';
part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db, {this.journal});
  final TaskMutationJournal? journal;
  Future<T> _write<T>(
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  }) =>
      journal?.trackEntity(
        'goal',
        id,
        write,
        expectedRevision: expectedRevision,
        requireExpected: requireExpected,
        createOnly: createOnly,
      ) ??
      transaction(write);
  Future<Goal> _observe(Goal g) async => (await _observeAll([g])).single;
  Future<List<Goal>> _observeAll(List<Goal> goals) async {
    if (journal == null || goals.isEmpty) return goals;
    final payloads = {
      for (final g in goals) 'goal/${g.id}': HierarchySyncCodec.goal(g),
    };
    final versions = await journal!.observedRevisions(payloads);
    return [
      for (final g in goals)
        HierarchySyncCodec.decodeGoal(
          payloads['goal/${g.id}']!,
          storageRevision: versions['goal/${g.id}'],
        ),
    ];
  }

  Future<void> createGoal(GoalsCompanion goal) async {
    await _write(
      goal.id.value,
      () => into(goals).insert(goal),
      createOnly: true,
    );
  }

  Future<List<Goal>> getGoalsBySphere(String sphereId) async => _observeAll(
    (await (select(goals)..where((g) => g.sphereId.equals(sphereId))).get())
        .map((r) => r.toDomain())
        .toList(),
  );
  Stream<List<Goal>> watchGoalsBySphere(String sphereId) =>
      (select(
        goals,
      )..where((g) => g.sphereId.equals(sphereId))).watch().asyncMap(
        (rows) => _observeAll(rows.map((r) => r.toDomain()).toList()),
      );
  Future<List<Goal>> getAllGoals() async => _observeAll(
    (await select(goals).get()).map((r) => r.toDomain()).toList(),
  );
  Stream<List<Goal>> watchAllGoals() => select(goals).watch().asyncMap(
    (rows) => _observeAll(rows.map((r) => r.toDomain()).toList()),
  );
  Future<GoalModel?> getGoalById(String id) =>
      (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();
  Future<Goal?> getGoal(String id) async {
    final model = await getGoalById(id);
    return model == null ? null : _observe(model.toDomain());
  }

  Future<void> updateGoal(Goal goal) async {
    await _write(
      goal.id,
      () => update(
        goals,
      ).replace(goal.copyWith(updatedAt: DateTime.now()).toDrift()),
      expectedRevision: goal.storageRevision,
      requireExpected: true,
    );
  }

  Future<void> deleteGoal(String id) async {
    await _write(id, () => (delete(goals)..where((g) => g.id.equals(id))).go());
  }

  Future<void> deleteGoalsBySphere(String sphereId) async {
    Future<void> write() async {
      await (delete(goals)..where((g) => g.sphereId.equals(sphereId))).go();
    }

    if (journal == null) {
      await transaction(write);
    } else {
      await journal!.trackGraph(write);
    }
  }
}
