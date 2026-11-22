import 'package:notes_api/notes_api.dart';

enum GraphStorageMode { obsidian, local, sharedFolder }

class GraphStorageTarget {
  const GraphStorageTarget({
    this.mode = GraphStorageMode.obsidian,
    this.localPath = '',
    this.folderName = '',
  });
  final GraphStorageMode mode;
  final String localPath;
  final String folderName;
  Map<String, String> toJson() => {
    'mode': mode.name,
    'localPath': localPath,
    if (folderName.isNotEmpty) 'folderName': folderName,
  };
  factory GraphStorageTarget.fromJson(Map<String, dynamic> data) =>
      GraphStorageTarget(
        mode: switch (data['mode']) {
          'local' => GraphStorageMode.local,
          'sharedFolder' => GraphStorageMode.sharedFolder,
          _ => GraphStorageMode.obsidian,
        },
        localPath: data['localPath'] as String? ?? '',
        folderName: data['folderName'] as String? ?? '',
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
