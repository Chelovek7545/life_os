// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:path/path.dart' as p;
// import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';

// class ObsidianNote {
//   final String absolutePath;
//   final String relativePath;
//   final String title;
//   final String content;
//   final DateTime modifiedAt;

//   ObsidianNote({
//     required this.absolutePath,
//     required this.relativePath,
//     required this.title,
//     required this.content,
//     required this.modifiedAt,
//   });

//   ObsidianNote copyWith({
//     String? title,
//     String? content,
//     DateTime? modifiedAt,
//   }) {
//     return ObsidianNote(
//       absolutePath: absolutePath,
//       relativePath: relativePath,
//       title: title ?? this.title,
//       content: content ?? this.content,
//       modifiedAt: modifiedAt ?? this.modifiedAt,
//     );
//   }
// }

// class ObsidianRepository extends ChangeNotifier {
//   List<ObsidianNote> _notes = [];
//   bool _isLoading = false;
//   String? _error;

//   List<ObsidianNote> get notes => _notes;
//   bool get isLoading => _isLoading;
//   String? get error => _error;

//   /// Возвращает дерево иерархии папок и заметок в виде [HierarchyNode]
//   List<HierarchyNode> getHierarchyTree() {
//     if (_notes.isEmpty) return const [];

//     final root = _FolderBuilder(name: '', path: '');

//     for (final note in _notes) {
//       final parts = p.split(note.relativePath);
//       var current = root;

//       for (var i = 0; i < parts.length; i++) {
//         final part = parts[i];
//         final isFile = i == parts.length - 1;

//         if (isFile) {
//           current.files.add(note);
//         } else {
//           final subPath = current.path.isEmpty ? part : '${current.path}/$part';
//           current = current.subfolders.putIfAbsent(
//             part,
//             () => _FolderBuilder(name: part, path: subPath),
//           );
//         }
//       }
//     }

//     return root.toHierarchyNodes();
//   }

//   /// Сканирует Vault по указанному пути
//   Future<void> scanVault(String vaultPath) async {
//     if (vaultPath.isEmpty) {
//       _notes = [];
//       _error = null;
//       notifyListeners();
//       return;
//     }

//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       final dir = Directory(vaultPath);
//       if (!await dir.exists()) {
//         _error = 'Указанная папка не существует';
//         _notes = [];
//         _isLoading = false;
//         notifyListeners();
//         return;
//       }

//       final loadedNotes = <ObsidianNote>[];
//       await for (final entity in dir.list(recursive: true, followLinks: false)) {
//         if (entity is File && p.extension(entity.path).toLowerCase() == '.md') {
//           // Пропускаем папку .obsidian если есть
//           if (entity.path.contains('${p.separator}.obsidian${p.separator}')) {
//             continue;
//           }
//           try {
//             final content = await entity.readAsString();
//             final stat = await entity.stat();
//             final relative = p.relative(entity.path, from: vaultPath);
//             final fileName = p.basenameWithoutExtension(entity.path);

//             loadedNotes.add(
//               ObsidianNote(
//                 absolutePath: entity.path,
//                 relativePath: relative,
//                 title: fileName,
//                 content: content,
//                 modifiedAt: stat.modified,
//               ),
//             );
//           } catch (e) {
//             debugPrint('Error reading md file ${entity.path}: $e');
//           }
//         }
//       }

//       _notes = loadedNotes;
//       _error = null;
//     } catch (e) {
//       _error = 'Ошибка чтения хранилища: $e';
//       _notes = [];
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   /// Двусторонняя связь: сохранение изменений заметки обратно в файл `.md`
//   Future<void> updateNoteContent(String absolutePath, String newContent) async {
//     try {
//       final file = File(absolutePath);
//       await file.writeAsString(newContent, flush: true);

//       // Обновляем локальный кэш
//       final index = _notes.indexWhere((n) => n.absolutePath == absolutePath);
//       if (index != -1) {
//         final stat = await file.stat();
//         _notes[index] = _notes[index].copyWith(
//           content: newContent,
//           modifiedAt: stat.modified,
//         );
//         notifyListeners();
//       }
//     } catch (e) {
//       debugPrint('Error writing to obsidian note $absolutePath: $e');
//     }
//   }

//   /// Создание новой заметки в хранилище Obsidian
//   Future<ObsidianNote?> createNote(String vaultPath, String title, String content) async {
//     if (vaultPath.isEmpty) return null;
//     try {
//       final sanitizedTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
//       final filePath = p.join(vaultPath, '$sanitizedTitle.md');
//       final file = File(filePath);
      
//       await file.writeAsString(content, flush: true);
//       final stat = await file.stat();
//       final relative = p.relative(filePath, from: vaultPath);

//       final note = ObsidianNote(
//         absolutePath: filePath,
//         relativePath: relative,
//         title: title,
//         content: content,
//         modifiedAt: stat.modified,
//       );

//       _notes.add(note);
//       notifyListeners();
//       return note;
//     } catch (e) {
//       debugPrint('Error creating obsidian note: $e');
//       return null;
//     }
//   }
// }

// class _FolderBuilder {
//   final String name;
//   final String path;
//   final Map<String, _FolderBuilder> subfolders = {};
//   final List<ObsidianNote> files = [];

//   _FolderBuilder({required this.name, required this.path});

//   List<HierarchyNode> toHierarchyNodes() {
//     final nodes = <HierarchyNode>[];

//     // Сначала папки (по алфавиту)
//     final sortedFolderKeys = subfolders.keys.toList()
//       ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

//     for (final key in sortedFolderKeys) {
//       final folder = subfolders[key]!;
//       nodes.add(
//         HierarchyNode(
//           id: 'folder_${folder.path}',
//           title: folder.name,
//           type: NodeType.folder,
//           isExpanded: true,
//           children: folder.toHierarchyNodes(),
//         ),
//       );
//     }

//     // Затем файлы (по алфавиту)
//     final sortedFiles = List<ObsidianNote>.from(files)
//       ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

//     for (final file in sortedFiles) {
//       nodes.add(
//         HierarchyNode(
//           id: file.absolutePath,
//           title: file.title,
//           type: NodeType.note,
//           data: file,
//           children: const [],
//         ),
//       );
//     }

//     return nodes;
//   }
// }

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';

class ObsidianNote {
  final String absolutePath;
  final String relativePath;
  final String title;
  final String content;
  final DateTime modifiedAt;

  ObsidianNote({
    required this.absolutePath,
    required this.relativePath,
    required this.title,
    required this.modifiedAt, 
    required this.content,
  });

  /// Чтение текста заметки с диска "on-demand" (только при открытии)
  Future<String> readContent() async {
    final file = File(absolutePath);
    return await file.readAsString();
  }

  ObsidianNote copyWith({
    String? title,
    String? content,
    DateTime? modifiedAt,
    
  }) {
    return ObsidianNote(
      absolutePath: absolutePath,
      relativePath: relativePath,
      title: title ?? this.title,
      modifiedAt: modifiedAt ?? this.modifiedAt,
       content: content ?? this.content,
    );
  }
}

class ObsidianRepository extends ChangeNotifier {
  List<ObsidianNote> _notes = [];
  // bool _isLoading = false;
  // String? _error;
  String? _currentVaultPath;

  StreamSubscription<FileSystemEvent>? _vaultWatcher;
  Timer? _debounceTimer;

  List<ObsidianNote> get notes => _notes;
  // bool get isLoading => _isLoading;
  // String? get error => _error;

  /// Возвращает дерево иерархии папок и заметок в виде [HierarchyNode]
  List<HierarchyNode> getHierarchyTree() {
    if (_notes.isEmpty) return const [];

    final root = _FolderBuilder(name: '', path: '');

    for (final note in _notes) {
      final parts = p.split(note.relativePath);
      var current = root;

      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        final isFile = i == parts.length - 1;

        if (isFile) {
          current.files.add(note);
        } else {
          final subPath = current.path.isEmpty ? part : '${current.path}/$part';
          current = current.subfolders.putIfAbsent(
            part,
            () => _FolderBuilder(name: part, path: subPath),
          );
        }
      }
    }

    return root.toHierarchyNodes();
  }

  /// Получение текста конкретной заметки при ее открытии
  Future<String> getNoteContent(String absolutePath) async {
    try {
      final file = File(absolutePath);
      return await file.readAsString();
    } catch (e) {
      debugPrint('Error reading note $absolutePath: $e');
      return '';
    }
  }

  /// Сканирует Vault по указанному пути и запускает отслеживание файловой системы
  

  Future<void> scanVault(String vaultPath, Function() onLoading, Function(String error) onError) async {

    _currentVaultPath = vaultPath;
    _startWatching(vaultPath);

    if (vaultPath.isEmpty) {
      _notes = [];
      //_error = null;
      notifyListeners();
      return;
    }

    //_isLoading = true;
    onLoading();
    //_error = null;
    notifyListeners();

    try {
      final dir = Directory(vaultPath);
      if (!await dir.exists()) {
        //_error =
         onError('Указанная папка не существует');
        _notes = [];
        //_isLoading = false;
        notifyListeners();
        return;
      }

      final loadedNotes = <ObsidianNote>[];
      await _scanDirectory(dir, vaultPath, loadedNotes);

      _notes = loadedNotes;
      //_error = null;
    } catch (e) {
      onError('Ошибка чтения хранилища: $e');
      _notes = [];
    } finally {
      //_isLoading = false;
      notifyListeners();
    }
  }

  /// Запуск наблюдения за файловой системой в директории Vault
  void _startWatching(String vaultPath) {
    _stopWatching();

    if (vaultPath.isEmpty) return;

    try {
      final dir = Directory(vaultPath);
      if (!dir.existsSync()) return;

      _vaultWatcher = dir.watch(recursive: true).listen(
        (event) {
          final path = event.path;
          final name = p.basename(path);

          // Игнорируем изменения в служебных паках (.obsidian, .git, .trash)
          if (p.split(path).any((part) => part.startsWith('.'))) return;

          // Фильтруем события только для .md файлов или перемещений папок
          if (p.extension(name).toLowerCase() == '.md' ||
              event.type == FileSystemEvent.move) {
            _onFileSystemEvent();
          }
        },
        onError: (e) {
          debugPrint('Vault watcher error: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to start vault watcher: $e');
    }
  }

  /// Дебаунс для группировки нескольких связанных событий файловой системы
  void _onFileSystemEvent() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final vaultPath = _currentVaultPath;
      if (vaultPath != null && vaultPath.isNotEmpty) {
        await _refreshVaultNotes(vaultPath);
      }
    });
  }

  /// Фоновое пересканирование папки без взвода флага `_isLoading`
  Future<void> _refreshVaultNotes(String vaultPath) async {
    try {
      final dir = Directory(vaultPath);
      if (!await dir.exists()) return;

      final loadedNotes = <ObsidianNote>[];
      await _scanDirectory(dir, vaultPath, loadedNotes);

      _notes = loadedNotes;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing vault: $e');
    }
  }

  void _stopWatching() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _vaultWatcher?.cancel();
    _vaultWatcher = null;
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }

  /// Ручной рекурсивный обход с мгновенным отсечением служебных директорий
  Future<void> _scanDirectory(
    Directory dir,
    String vaultPath,
    List<ObsidianNote> result,
  ) async {
    try {
      final entities = await dir.list(followLinks: false).toList();

      for (final entity in entities) {
        final name = p.basename(entity.path);

        // Игнорируем скрытые папки и файлы (.obsidian, .git, .trash)
        if (name.startsWith('.')) continue;

        if (entity is Directory) {
          await _scanDirectory(entity, vaultPath, result);
        } else if (entity is File && p.extension(name).toLowerCase() == '.md') {
          try {
            final stat = await entity.stat();
            final relative = p.relative(entity.path, from: vaultPath);
            final fileName = p.basenameWithoutExtension(entity.path);

            result.add(
              ObsidianNote(
                content: '',
                absolutePath: entity.path,
                relativePath: relative,
                title: fileName,
                modifiedAt: stat.modified,
              ),
            );
          } catch (e) {
            debugPrint('Error getting stat for md file ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory ${dir.path}: $e');
    }
  }

  /// Сохранение изменений заметки обратно в файл `.md`
  Future<void> updateNoteContent(String absolutePath, String newContent) async {
    try {
      final file = File(absolutePath);
      await file.writeAsString(newContent, flush: true);

      final index = _notes.indexWhere((n) => n.absolutePath == absolutePath);
      if (index != -1) {
        final stat = await file.stat();
        _notes[index] = _notes[index].copyWith(
          modifiedAt: stat.modified,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error writing to obsidian note $absolutePath: $e');
    }
  }

  /// Создание новой заметки в хранилище Obsidian
  Future<ObsidianNote?> createNote(
    String vaultPath,
    String title,
    String content,
  ) async {
    if (vaultPath.isEmpty) return null;
    try {
      final sanitizedTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final filePath = p.join(vaultPath, '$sanitizedTitle.md');
      final file = File(filePath);

      await file.writeAsString(content, flush: true);
      final stat = await file.stat();
      final relative = p.relative(filePath, from: vaultPath);

      final note = ObsidianNote(
        content: content,
        absolutePath: filePath,
        relativePath: relative,
        title: title,
        modifiedAt: stat.modified,
      );

      _notes.add(note);
      notifyListeners();
      return note;
    } catch (e) {
      debugPrint('Error creating obsidian note: $e');
      return null;
    }
  }
}
class _FolderBuilder {
  final String name;
  final String path;
  final Map<String, _FolderBuilder> subfolders = {};
  final List<ObsidianNote> files = [];

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

    final sortedFiles = List<ObsidianNote>.from(files)
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
