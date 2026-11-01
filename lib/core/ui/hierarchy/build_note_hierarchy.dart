import 'package:notes_api/notes_api.dart';
import 'package:path/path.dart' as p;
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';

List<HierarchyNode> buildVaultHierarchy(List<VaultNote> notes) {
  final root = _FolderBuilder(name: '', path: '');
  for (final note in notes) {
    var current = root;
    final parts = p.split(note.relativePath);
    for (var i = 0; i < parts.length - 1; i++) {
      final name = parts[i];
      final parent = current;
      current = parent.subfolders.putIfAbsent(
        name,
        () => _FolderBuilder(name: name, path: p.join(parent.path, name)),
      );
    }
    current.files.add(note);
  }
  return root.toHierarchyNodes();
}

class _FolderBuilder {
  final String name;
  final String path;
  final Map<String, _FolderBuilder> subfolders = {};
  final List<VaultNote> files = [];

  _FolderBuilder({required this.name, required this.path});

  List<HierarchyNode> toHierarchyNodes() {
    final nodes = <HierarchyNode>[];

    final sortedFolderKeys = subfolders.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final key in sortedFolderKeys) {
      final folder = subfolders[key]!;
      nodes.add(
        HierarchyNode(
          id: 'folder_${folder.path}',
          title: folder.name,
          type: NodeType.folder,
          isExpanded: true,
          children: folder.toHierarchyNodes(),
        ),
      );
    }

    final sortedFiles = List<VaultNote>.from(files)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    for (final file in sortedFiles) {
      nodes.add(
        HierarchyNode(
          id: file.absolutePath,
          title: file.title,
          type: NodeType.note,
          data: file,
          children: const [],
        ),
      );
    }

    return nodes;
  }
}
