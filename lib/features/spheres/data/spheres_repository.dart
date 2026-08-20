import 'package:life_os/features/spheres/data/spheres_dao.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import 'package:life_os/features/spheres/data/sphere_model_extension.dart';

class StorageException implements Exception {
  StorageException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

class SpheresRepository {
  SpheresRepository(this._dao);
  final SpheresDao _dao;

  Stream<List<Sphere>> watchAllSpheres() => _dao.watchAllSpheres();

  Future<List<Sphere>> getAllSpheres() => _dao.getAllSpheres();

  Future<Sphere?> getSphere(String id) => _dao.getSphere(id);

  Future<void> addSphere(Sphere sphere) async {
    try {
      await _dao.createSphere(sphere.toDrift());
    } catch (error) {
      throw StorageException('Failed to save sphere.', error);
    }
  }

  Future<void> updateSphere(Sphere sphere) async {
    try {
      await _dao.updateSphere(sphere);
    } catch (error) {
      throw StorageException('Failed to update sphere.', error);
    }
  }

  Future<void> deleteSphere(String id) async {
    try {
      await _dao.deleteSphere(id);
    } catch (e) {
      throw StorageException('Failed to delete sphere.', e);
    }
  }
}