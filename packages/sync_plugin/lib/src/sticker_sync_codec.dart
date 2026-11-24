import 'dart:convert';

import 'canvas_placement_sync_codec.dart';
import 'markdown_sync_codec.dart';

class SyncSticker {
  const SyncSticker({
    required this.sphereId,
    required this.stickerId,
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.markdownPath,
  });

  final String sphereId, stickerId, text;
  final String? markdownPath;
  final double x, y, width, height;

  String get id => canvasEntryId(sphereId, stickerId);

  String encode() {
    if (sphereId.isEmpty ||
        stickerId.isEmpty ||
        stickerId.length > 1024 ||
        ![x, y, width, height].every((value) => value.isFinite) ||
        width <= 0 ||
        height <= 0 ||
        (markdownPath != null &&
            (text.isNotEmpty || !MarkdownSyncNote.isPortable(markdownPath!)))) {
      throw const FormatException('Invalid sticker.');
    }
    return jsonEncode({
      'sphereId': sphereId,
      'stickerId': stickerId,
      'text': text,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      if (markdownPath != null) 'markdownPath': markdownPath,
    });
  }

  factory SyncSticker.decode(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final sticker = SyncSticker(
      sphereId: map['sphereId'] as String,
      stickerId: map['stickerId'] as String,
      text: map['text'] as String,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      markdownPath: map['markdownPath'] as String?,
    );
    if (sticker.encode() != payload) {
      throw const FormatException('Noncanonical sticker.');
    }
    return sticker;
  }
}
