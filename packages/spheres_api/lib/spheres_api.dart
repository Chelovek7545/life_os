import 'src/sphere.dart';
export 'src/sphere.dart';

abstract interface class SpheresQueries {
  Stream<List<Sphere>> watchAllSpheres();
  Future<List<Sphere>> getAllSpheres();
  Future<Sphere?> getSphere(String id);
}

abstract interface class SpheresCommands {
  Future<void> addSphere(Sphere sphere);
  Future<void> updateSphere(Sphere sphere);
  Future<void> deleteSphere(String id);
}

abstract interface class SpheresApi
    implements SpheresQueries, SpheresCommands {}
