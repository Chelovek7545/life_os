// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spheres_dao.dart';

// ignore_for_file: type=lint
mixin _$SpheresDaoMixin on DatabaseAccessor<AppDatabase> {
  $SpheresTable get spheres => attachedDatabase.spheres;
  SpheresDaoManager get managers => SpheresDaoManager(this);
}

class SpheresDaoManager {
  final _$SpheresDaoMixin _db;
  SpheresDaoManager(this._db);
  $$SpheresTableTableManager get spheres =>
      $$SpheresTableTableManager(_db.attachedDatabase, _db.spheres);
}
