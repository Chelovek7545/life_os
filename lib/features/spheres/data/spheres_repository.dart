import 'package:spheres_api/spheres_api.dart' show SpheresApi, Sphere;
import 'package:core_contracts/core_contracts.dart' show StorageException;
import 'package:life_os/features/spheres/data/spheres_dao.dart';
import 'package:life_os/features/spheres/data/sphere_model_extension.dart';

class SpheresRepository implements SpheresApi {
  SpheresRepository(this._dao);
  final SpheresDao _dao;

  @override
  Stream<List<Sphere>> watchAllSpheres() => _dao.watchAllSpheres();

  @override
  Future<List<Sphere>> getAllSpheres() => _dao.getAllSpheres();

  @override
  Future<Sphere?> getSphere(String id) => _dao.getSphere(id);

  @override
  Future<void> addSphere(Sphere sphere) async {
    try {
      await _dao.createSphere(sphere.toDrift());
    } catch (error) {
      throw StorageException('Failed to save sphere.', error);
    }
  }

  @override
  Future<void> updateSphere(Sphere sphere) async {
    try {
      await _dao.updateSphere(sphere);
    } catch (error) {
      throw StorageException('Failed to update sphere.', error);
    }
  }

  @override
  Future<void> deleteSphere(String id) async {
    try {
      await _dao.deleteSphere(id);
    } catch (e) {
      throw StorageException('Failed to delete sphere.', e);
    }
  }
}
