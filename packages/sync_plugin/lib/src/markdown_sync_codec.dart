import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class MarkdownSyncNote {
  const MarkdownSyncNote(this.path, this.text);

  final String path;
  final String text;

  static final _invalid = RegExp(r'[<>:"\\|?*\x00-\x1f]');
  static final _reserved = RegExp(
    r'^(con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])(?:\.|$)',
    caseSensitive: false,
  );

  static bool isPortable(String path) =>
      path.length <= 1024 &&
      !p.posix.isAbsolute(path) &&
      p.posix.normalize(path) == path &&
      p.posix.extension(path).toLowerCase() == '.md' &&
      p.posix
          .split(path)
          .every(
            (part) =>
                part.isNotEmpty &&
                !part.startsWith('.') &&
                !part.endsWith('.') &&
                !part.endsWith(' ') &&
                !_invalid.hasMatch(part) &&
                !_reserved.hasMatch(part),
          );

  String get id => sha256.convert(utf8.encode(path.toLowerCase())).toString();

  String encode() {
    if (!isPortable(path)) {
      throw const FormatException('Invalid Markdown path.');
    }
    return jsonEncode({'path': path, 'text': text});
  }

  factory MarkdownSyncNote.decode(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final result = MarkdownSyncNote(
      map['path'] as String,
      map['text'] as String,
    );
    if (result.encode() != payload) {
      throw const FormatException('Noncanonical Markdown note.');
    }
    return result;
  }
}
