import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:spheres_api/spheres_api.dart' show Sphere;

extension SphereDataToDomain on SphereModel {
  Sphere toDomain() {
    return Sphere(
      id: id,
      name: name,
      color: color,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension SphereToDrift on Sphere {
  SpheresCompanion toDrift() {
    return SpheresCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}