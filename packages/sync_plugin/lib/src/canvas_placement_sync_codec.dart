import 'dart:convert';

import 'package:crypto/crypto.dart';

String canvasScopePrefix(String sphereId) =>
    '${_digest(sphereId).substring(0, 32)}/';

String canvasEntryId(String sphereId, String id) =>
    '${canvasScopePrefix(sphereId)}${_digest(id)}';

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();

class SyncCanvasPlacement {
  const SyncCanvasPlacement({
    required this.sphereId,
    required this.nodeId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String sphereId, nodeId;
  final double x, y, width, height;

  String get id => canvasEntryId(sphereId, nodeId);

  String encode() {
    if (sphereId.isEmpty ||
        nodeId.isEmpty ||
        nodeId.length > 1024 ||
        ![x, y, width, height].every((value) => value.isFinite) ||
        width <= 0 ||
        height <= 0) {
      throw const FormatException('Invalid Canvas placement.');
    }
    return jsonEncode({
      'sphereId': sphereId,
      'nodeId': nodeId,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
  }

  factory SyncCanvasPlacement.decode(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final placement = SyncCanvasPlacement(
      sphereId: map['sphereId'] as String,
      nodeId: map['nodeId'] as String,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
    );
    if (placement.encode() != payload) {
      throw const FormatException('Noncanonical Canvas placement.');
    }
    return placement;
  }
}
