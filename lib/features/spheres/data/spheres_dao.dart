import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:spheres_api/spheres_api.dart' show Sphere;
import 'package:life_os/features/tasks/data/task_mutation_journal.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'sphere_model_extension.dart';
part 'spheres_dao.g.dart';

@DriftAccessor(tables: [Spheres])
class SpheresDao extends DatabaseAccessor<AppDatabase> with _$SpheresDaoMixin {
  SpheresDao(super.db, {this.journal});
  final TaskMutationJournal? journal;
  Future<T> _write<T>(
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  }) =>
      journal?.trackEntity(
        'sphere',
        id,
        write,
        expectedRevision: expectedRevision,
        requireExpected: requireExpected,
        createOnly: createOnly,
      ) ??
      transaction(write);
  Future<Sphere> _observe(Sphere s) async => (await _observeAll([s])).single;
  Future<List<Sphere>> _observeAll(List<Sphere> spheres) async {
    if (journal == null || spheres.isEmpty) return spheres;
    final payloads = {
      for (final s in spheres) 'sphere/${s.id}': HierarchySyncCodec.sphere(s),
    };
    final versions = await journal!.observedRevisions(payloads);
    return [
      for (final s in spheres)
        HierarchySyncCodec.decodeSphere(
          payloads['sphere/${s.id}']!,
          storageRevision: versions['sphere/${s.id}'],
        ),
    ];
  }

  Future<void> createSphere(SpheresCompanion sphere) async {
    await _write(
      sphere.id.value,
      () => into(spheres).insert(sphere),
      createOnly: true,
    );
  }

  Future<List<Sphere>> getAllSpheres() async => _observeAll(
    (await select(spheres).get()).map((r) => r.toDomain()).toList(),
  );
  Stream<List<Sphere>> watchAllSpheres() => select(spheres).watch().asyncMap(
    (rows) => _observeAll(rows.map((r) => r.toDomain()).toList()),
  );
  Future<SphereModel?> getSphereById(String id) =>
      (select(spheres)..where((s) => s.id.equals(id))).getSingleOrNull();
  Future<Sphere?> getSphere(String id) async {
    final model = await getSphereById(id);
    return model == null ? null : _observe(model.toDomain());
  }

  Future<void> updateSphere(Sphere sphere) async {
    await _write(
      sphere.id,
      () => update(
        spheres,
      ).replace(sphere.copyWith(updatedAt: DateTime.now()).toDrift()),
      expectedRevision: sphere.storageRevision,
      requireExpected: true,
    );
  }

  Future<void> deleteSphere(String id) async {
    await _write(
      id,
      () => (delete(spheres)..where((s) => s.id.equals(id))).go(),
    );
  }
}
