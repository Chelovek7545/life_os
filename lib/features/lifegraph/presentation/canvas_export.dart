import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'widgets/canvas_visuals.dart';

enum CanvasExportFormat {
  png('PNG', 'png', 'image/png'),
  svg('SVG', 'svg', 'image/svg+xml'),
  json('JSON', 'json', 'application/json'),
  pulse('Pulse (.canvas)', 'canvas', 'application/json');

  const CanvasExportFormat(this.label, this.extension, this.mime);
  final String label, extension, mime;
}

Future<String?> saveCanvasExport(
  CanvasExportFormat format,
  String title,
  Map<String, Object?> document, {
  bool straight = false,
}) async {
  final filename = '${_safeTitle(title)}.${format.extension}';
  final file = XFile.fromData(
    await encodeCanvasExport(format, document, straight: straight),
    name: filename,
    mimeType: format.mime,
  );
  if (kIsWeb) {
    await file.saveTo(filename);
    return filename;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return const MethodChannel(
      'pulse/graph_folder_picker',
    ).invokeMethod<String>('saveExport', {
      'name': filename,
      'mime': format.mime,
      'bytes': await file.readAsBytes(),
    });
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final folder = await getApplicationDocumentsDirectory();
    final path = p.join(
      folder.path,
      '${DateTime.now().millisecondsSinceEpoch}-$filename',
    );
    await file.saveTo(path);
    return path;
  }
  final location = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: [
      XTypeGroup(label: format.label, extensions: [format.extension]),
    ],
  );
  if (location == null) return null;
  await file.saveTo(location.path);
  return location.path;
}

String _safeTitle(String title) {
  final name = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
      .trim()
      .replaceFirst(RegExp(r'[ .]+$'), '');
  return name.isEmpty ? 'Canvas' : name;
}

Future<Uint8List> encodeCanvasExport(
  CanvasExportFormat format,
  Map<String, Object?> document, {
  bool straight = false,
}) async {
  if (format == CanvasExportFormat.pulse || format == CanvasExportFormat.json) {
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(document)),
    );
  }
  final scene = _ExportScene(document, straight: straight);
  return format == CanvasExportFormat.svg
      ? Uint8List.fromList(utf8.encode(scene.svg()))
      : scene.png();
}

const _background = Color(0xFF151416);
const _ink = Color(0xFFEDE6E4);

class _ExportCard {
  _ExportCard(Map node)
    : id = node['id'] as String,
      rect = Rect.fromLTWH(
        (node['x'] as num).toDouble(),
        (node['y'] as num).toDouble(),
        (node['width'] as num).toDouble(),
        (node['height'] as num).toDouble(),
      ),
      kind = switch (node['pulse']) {
        {'kind': final String kind} => kind,
        _ => node['type'] == 'group' ? 'group' : 'note',
      },
      text = switch (node) {
        {'text': final String text} => text,
        {'pulse': {'cachedText': final String text}} when text.isNotEmpty =>
          text,
        {'label': final String label} => label,
        {'file': final String file} => p.posix.basename(
          file.replaceAll('\\', '/'),
        ),
        {'url': final String url} => url,
        _ => '',
      };
  final String id, kind, text;
  final Rect rect;
  Color get accent => canvasKindColor(kind);
  Color get fill => Color.alphaBlend(
    accent.withValues(alpha: kind == 'note' ? .19 : .08),
    const Color(0xFF222123),
  );
  String get plainText => text.replaceFirst(RegExp(r'^#+\s*'), '');
}

class _ExportScene {
  _ExportScene(Map<String, Object?> document, {required this.straight}) {
    for (final raw in (document['nodes'] as List).whereType<Map>()) {
      final card = _ExportCard(raw);
      cards[card.id] = card;
    }
    for (final edge in (document['edges'] as List).whereType<Map>()) {
      final from = cards[edge['fromNode']];
      final to = cards[edge['toNode']];
      if (from == null || to == null) continue;
      edges.add((
        _side(from.rect, edge['fromSide'], from: true),
        _side(to.rect, edge['toSide'], from: false),
        to.accent,
      ));
    }
    if (cards.isNotEmpty) {
      bounds = cards.values
          .map((card) => card.rect)
          .reduce((a, b) => a.expandToInclude(b))
          .inflate(36);
    }
  }
  final bool straight;
  final cards = <String, _ExportCard>{};
  final edges = <(Offset, Offset, Color)>[];
  Rect bounds = const Rect.fromLTWH(0, 0, 640, 400);

  static Offset _side(Rect rect, Object? side, {required bool from}) =>
      switch (side) {
        'top' => rect.topCenter,
        'bottom' => rect.bottomCenter,
        'left' => rect.centerLeft,
        'right' => rect.centerRight,
        _ => from ? rect.centerRight : rect.centerLeft,
      };

  Iterable<_ExportCard> get groups =>
      cards.values.where((card) => card.kind == 'group');
  Iterable<_ExportCard> get content =>
      cards.values.where((card) => card.kind != 'group');
  double _bend(Offset a, Offset b) => math.max(25, (b.dx - a.dx).abs() * .45);

  Future<Uint8List> png() async {
    final ratio = math.min(2.0, 4096 / math.max(bounds.width, bounds.height));
    final width = math.max(1, (bounds.width * ratio).ceil());
    final height = math.max(1, (bounds.height * ratio).ceil());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(ratio)
      ..translate(-bounds.left, -bounds.top);
    canvas.drawRect(bounds.inflate(1), Paint()..color = _background);
    for (final group in groups) {
      _paintCard(canvas, group);
    }
    for (final (a, b, color) in edges) {
      final path = Path()..moveTo(a.dx, a.dy);
      if (straight) {
        path.lineTo(b.dx, b.dy);
      } else {
        final bend = _bend(a, b);
        path.cubicTo(a.dx + bend, a.dy, b.dx - bend, b.dy, b.dx, b.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .68)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    for (final card in content) {
      _paintCard(canvas, card);
    }
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('Не удалось сформировать PNG.');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  void _paintCard(Canvas canvas, _ExportCard card) {
    final rect = card.rect;
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(card.kind == 'sphere' ? rect.shortestSide / 2 : 12),
    );
    canvas.drawRRect(shape, Paint()..color = card.fill);
    canvas.drawRRect(
      shape,
      Paint()
        ..color = card.accent.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    if (rect.width < 28 || rect.height < 28) return;
    final text = TextPainter(
      text: TextSpan(
        text: card.plainText,
        style: const TextStyle(color: _ink, fontSize: 13, height: 1.24),
      ),
      textDirection: TextDirection.ltr,
      textAlign: card.kind == 'sphere' ? TextAlign.center : TextAlign.start,
      maxLines: math.max(1, ((rect.height - 22) / 17).floor()),
      ellipsis: '…',
    )..layout(maxWidth: rect.width - 24);
    canvas.save();
    canvas.clipRRect(shape);
    text.paint(
      canvas,
      card.kind == 'sphere'
          ? rect.center - Offset(text.width, text.height) / 2
          : rect.topLeft + const Offset(12, 10),
    );
    canvas.restore();
    text.dispose();
  }

  String svg() {
    final out = StringBuffer(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${bounds.left} ${bounds.top} ${bounds.width} ${bounds.height}" width="${bounds.width.ceil()}" height="${bounds.height.ceil()}">',
    );
    out.write(
      '<rect x="${bounds.left}" y="${bounds.top}" width="${bounds.width}" height="${bounds.height}" fill="${_hex(_background)}"/>',
    );
    for (final group in groups) {
      _writeCard(out, group);
    }
    for (final (a, b, color) in edges) {
      final bend = _bend(a, b);
      final end = straight
          ? 'L ${b.dx} ${b.dy}'
          : 'C ${a.dx + bend} ${a.dy} ${b.dx - bend} ${b.dy} ${b.dx} ${b.dy}';
      out.write(
        '<path d="M ${a.dx} ${a.dy} $end" fill="none" stroke="${_hex(color)}" stroke-opacity=".68" stroke-width="2"/>',
      );
    }
    for (final card in content) {
      _writeCard(out, card);
    }
    out.write('</svg>');
    return out.toString();
  }

  void _writeCard(StringBuffer out, _ExportCard card) {
    final r = card.rect;
    final rx = card.kind == 'sphere' ? r.shortestSide / 2 : 12;
    out.write(
      '<rect x="${r.left}" y="${r.top}" width="${r.width}" height="${r.height}" rx="$rx" fill="${_hex(card.fill)}" stroke="${_hex(card.accent)}" stroke-opacity=".65"/>',
    );
    if (r.width < 28 || r.height < 28) return;
    final lineWidth = math.max(1, ((r.width - 24) / 7.5).floor());
    final maxLines = math.max(1, ((r.height - 22) / 17).floor());
    final lines = <String>[];
    for (final paragraph in const LineSplitter().convert(card.plainText)) {
      final chars = paragraph.characters;
      if (chars.isEmpty) lines.add('');
      for (
        var i = 0;
        i < chars.length && lines.length < maxLines;
        i += lineWidth
      ) {
        lines.add(chars.skip(i).take(lineWidth).toString());
      }
      if (lines.length >= maxLines) break;
    }
    final center = card.kind == 'sphere';
    final x = center ? r.center.dx : r.left + 12;
    final y = center ? r.center.dy - (lines.length - 1) * 8 : r.top + 23;
    out.write(
      '<text x="$x" y="$y"${center ? ' text-anchor="middle"' : ''} font-family="Inter, sans-serif" font-size="13" fill="${_hex(_ink)}">',
    );
    for (var i = 0; i < lines.length; i++) {
      final safe = lines[i].replaceAll(
        RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'),
        '',
      );
      out.write(
        '<tspan x="$x" dy="${i == 0 ? 0 : 17}">${const HtmlEscape(HtmlEscapeMode.element).convert(safe)}</tspan>',
      );
    }
    out.write('</text>');
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
}
