import 'dart:convert';

import 'canvas_placement_sync_codec.dart';

class SyncCanvasBoard {
  const SyncCanvasBoard(this.sphereId, this.document);

  final String sphereId;
  final Map<String, dynamic> document;

  String get id => canvasEntryId(sphereId, 'board');

  String encode() {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(sphereId) ||
        sphereId.length > 128 ||
        document['nodes'] is! List ||
        document['edges'] is! List) {
      throw const FormatException('Invalid Canvas board.');
    }
    return jsonEncode({'sphereId': sphereId, 'document': _ordered(document)});
  }

  factory SyncCanvasBoard.decode(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final board = SyncCanvasBoard(
      map['sphereId'] as String,
      map['document'] as Map<String, dynamic>,
    );
    if (board.encode() != payload) {
      throw const FormatException('Noncanonical Canvas board.');
    }
    return board;
  }

  static Object? _ordered(Object? value) => switch (value) {
    Map<String, dynamic>() => {
      for (final key in value.keys.toList()..sort()) key: _ordered(value[key]),
    },
    List() => value.map(_ordered).toList(),
    _ => value,
  };
}
