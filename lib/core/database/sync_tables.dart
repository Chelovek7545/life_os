import 'package:drift/drift.dart';

@DataClassName('SyncIdentityRow')
class SyncIdentities extends Table {
  IntColumn get singleton => integer().withDefault(const Constant(1))();
  TextColumn get datasetId => text()();
  TextColumn get deviceId => text()();
  @override
  Set<Column> get primaryKey => {singleton};
}

@DataClassName('SyncRevisionRow')
class SyncRevisions extends Table {
  IntColumn get sequence => integer().autoIncrement()();
  TextColumn get revisionId => text().unique()();
  TextColumn get body => text()();
}

class SyncCursors extends Table {
  TextColumn get deviceId => text()();
  IntColumn get cursor => integer()();
  @override
  Set<Column> get primaryKey => {deviceId};
}

@DataClassName('SyncEntityHeadRow')
class SyncEntityHeads extends Table {
  TextColumn get entityKey => text()();
  TextColumn get revisionId => text().nullable()();
  TextColumn get payload => text().nullable()();
  BoolColumn get blocked => boolean()();
  @override
  Set<Column> get primaryKey => {entityKey};
}

@DataClassName('SyncNoteCheckpoint')
class SyncNoteCheckpoints extends Table {
  TextColumn get scope => text()();
  TextColumn get noteId => text()();
  TextColumn get revisionId => text()();

  @override
  Set<Column> get primaryKey => {scope, noteId};
}
