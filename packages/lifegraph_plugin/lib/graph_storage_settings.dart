import 'package:notes_api/notes_api.dart';

enum GraphStorageMode { obsidian, local }

class GraphStorageTarget {
  const GraphStorageTarget({
    this.mode = GraphStorageMode.obsidian,
    this.localPath = '',
  });
  final GraphStorageMode mode;
  final String localPath;
  Map<String, String> toJson() => {'mode': mode.name, 'localPath': localPath};
  factory GraphStorageTarget.fromJson(Map<String, dynamic> data) =>
      GraphStorageTarget(
        mode: data['mode'] == 'local'
            ? GraphStorageMode.local
            : GraphStorageMode.obsidian,
        localPath: data['localPath'] as String? ?? '',
      );
  static const localFolders = VaultFolders(
    boards: 'Boards',
    notes: 'Notes',
    exports: 'Exports',
    backups: 'Backups',
  );
}

abstract interface class GraphStorageSettings {
  VaultFolders get folders;
  Stream<VaultFolders> watchFolders();
}
