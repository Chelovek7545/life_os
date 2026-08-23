import 'dart:async';
import 'dart:io';

class ObsidianSyncService {
  StreamSubscription<FileSystemEvent>? _subscription;

  /// Подписывается на изменения `.md` файлов по абсолютному пути директории или файла.
  void startWatching(
    String absolutePath,
    void Function(String filePath) onFileChanged,
  ) {
    stopWatching();

    final dir = Directory(absolutePath);
    if (!dir.existsSync()) return;

    _subscription = dir.watch(recursive: true).listen((event) {
      if (event.path.endsWith('.md')) {
        if (event.type == FileSystemEvent.modify ||
            event.type == FileSystemEvent.create) {
          onFileChanged(event.path);
        }
      }
    });
  }

  void stopWatching() {
    _subscription?.cancel();
    _subscription = null;
  }
}