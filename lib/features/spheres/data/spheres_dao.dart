import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import 'sphere_model_extension.dart';

part 'spheres_dao.g.dart';

@DriftAccessor(tables: [Spheres])
class SpheresDao extends DatabaseAccessor<AppDatabase> with _$SpheresDaoMixin {
  SpheresDao(super.db);

  Future<void> createSphere(SpheresCompanion sphere) async {
    await into(spheres).insert(sphere);
  }

  Future<List<Sphere>> getAllSpheres() async {
    final dataList = await select(spheres).get();
    return dataList.map((data) => data.toDomain()).toList();
  }

  Stream<List<Sphere>> watchAllSpheres() {
    return select(spheres).watch().map(
      (dataList) => dataList.map((data) => data.toDomain()).toList(),
    );
  }

  Future<SphereModel?> getSphereById(String id) async {
    try {
      final data = await (select(spheres)..where((s) => s.id.equals(id))).getSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<Sphere?> getSphere(String id) async {
    final model = await getSphereById(id);
    return model?.toDomain();
  }

  Future<void> updateSphere(Sphere sphere) async {
    await update(spheres).replace(sphere.copyWith(updatedAt: DateTime.now()).toDrift());
  }

  Future<void> deleteSphere(String id) async {
    await (delete(spheres)..where((s) => s.id.equals(id))).go();
  }
}