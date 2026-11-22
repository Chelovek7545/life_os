import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:life_os/features/lifegraph/data/android_graph_files.dart';

Future<String?> pickGraphDirectory() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return (await AndroidGraphFiles.pickFolder())?.localPath;
  }
  return getDirectoryPath();
}
