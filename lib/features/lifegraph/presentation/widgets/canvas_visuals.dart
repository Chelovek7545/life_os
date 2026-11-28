import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:lifegraph_plugin/canvas_board.dart';

import 'package:life_os/core/theme/app_colors.dart';
import 'graph_theme.dart';

const canvasIcon = Icons.space_dashboard_outlined;
const canvasStroke = Color(0x26FFFFFF);
const canvasMuted = Color(0xFFB8ADAC);

String canvasKindLabel(String kind) => switch (kind) {
  'sphere' => 'Сфера',
  'goal' => 'Цель',
  'project' => 'Проект',
  'task' || 'subTask' => 'Задача',
  'note' => 'Заметка',
  _ => 'Карточка',
};

IconData canvasKindIcon(String kind) => switch (kind) {
  'sphere' => Icons.public_outlined,
  'goal' => Icons.adjust_rounded,
  'project' => Icons.folder_outlined,
  'task' || 'subTask' => Icons.check_box_outlined,
  'note' => Icons.sticky_note_2_outlined,
  _ => canvasIcon,
};

Color canvasKindColor(String kind) => switch (kind) {
  'sphere' => const Color(0xFFFF9753),
  'goal' => AppGraphThemes.dark.accentFor(1),
  'project' => AppGraphThemes.dark.accentFor(2),
  'task' || 'subTask' => AppGraphThemes.dark.accentFor(3),
  'note' => const Color(0xFFE6BD78),
  _ => canvasMuted,
};

String canvasCardCount(int count) {
  final last = count % 10;
  final noun = switch (count % 100) {
    >= 11 && <= 14 => 'карточек',
    _ when last == 1 => 'карточка',
    _ when last >= 2 && last <= 4 => 'карточки',
    _ => 'карточек',
  };
  return '$count $noun';
}

class CanvasBadge extends StatelessWidget {
  const CanvasBadge({super.key, this.size = 41});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0x24FF7B20),
      border: Border.all(color: const Color(0x38FF8E50)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(canvasIcon, size: size * .53, color: canvasKindColor('sphere')),
  );
}

ButtonStyle canvasPrimaryButton() => FilledButton.styleFrom(
  backgroundColor: AppColors.primaryContainer,
  foregroundColor: const Color(0xFF190900),
  disabledBackgroundColor: const Color(0x33FF984C),
  disabledForegroundColor: canvasMuted,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

typedef _PreviewCard = ({String id, String title, String kind, Rect rect});

class CanvasThumbnail extends StatelessWidget {
  CanvasThumbnail.document(CanvasBoardDocument document, {super.key})
    : _cards = [
        for (final node in document.nodes)
          (
            id: node['id'] as String,
            title: '',
            kind: switch (node['pulse']) {
              {'kind': final String kind} => kind,
              _ => document.entityId(node) == null ? 'note' : 'entity',
            },
            rect: Rect.fromLTWH(
              (node['x'] as num).toDouble(),
              (node['y'] as num).toDouble(),
              (node['width'] as num).toDouble(),
              (node['height'] as num).toDouble(),
            ),
          ),
      ],
      edges = [
        for (final edge in document.edges)
          if (edge['fromNode'] is String && edge['toNode'] is String)
            (edge['fromNode'] as String, edge['toNode'] as String),
      ],
      labels = false;

  CanvasThumbnail.structure(List<GraphNodeData> nodes, {super.key})
    : _cards = _structureCards(nodes),
      edges = [
        for (final node in nodes) ...[
          if (node.parentId case final parent?) (parent, node.id),
          for (final from in graphPredecessorIds(node.attributes))
            (from, node.id),
        ],
      ],
      labels = true;

  final List<_PreviewCard> _cards;
  final List<(String, String)> edges;
  final bool labels;

  static List<_PreviewCard> _structureCards(List<GraphNodeData> nodes) {
    final depths = <String, int>{};
    final rows = <int, int>{};
    return [
      for (final node in nodes)
        () {
          final column = (depths[node.parentId] ?? -1) + 1;
          final row = rows[column] ?? 0;
          depths[node.id] = column;
          rows[column] = row + 1;
          return (
            id: node.id,
            title: node.title,
            kind: node.kind,
            rect: Rect.fromLTWH(column * 118, row * 49, 96, 29),
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF151111),
        gradient: LinearGradient(
          colors: [Color(0xFF241713), Color(0xFF151111), Color(0xFF211923)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _CanvasPreviewPainter(
          _cards,
          edges,
          labels,
          Directionality.of(context),
        ),
        child: _cards.isEmpty
            ? Center(
                child: Icon(
                  canvasIcon,
                  color: canvasMuted.withValues(alpha: .55),
                  size: 25,
                ),
              )
            : const SizedBox.expand(),
      ),
    ),
  );
}

class _CanvasPreviewPainter extends CustomPainter {
  _CanvasPreviewPainter(this.cards, this.edges, this.labels, this.direction);
  final List<_PreviewCard> cards;
  final List<(String, String)> edges;
  final bool labels;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x32EAD1C6);
    for (var x = 7.0; x < size.width; x += 14) {
      for (var y = 7.0; y < size.height; y += 14) {
        canvas.drawCircle(Offset(x, y), .8, paint);
      }
    }
    if (cards.isEmpty || size.shortestSide <= 22) return;
    final bounds = cards
        .map((card) => card.rect)
        .reduce((a, b) => a.expandToInclude(b));
    final scale = math.min(
      math.min(
        (size.width - 22) / bounds.width,
        (size.height - 22) / bounds.height,
      ),
      labels ? 1.25 : .48,
    );
    final origin = (size.center(Offset.zero) - bounds.center * scale);
    final positions = {
      for (final card in cards)
        card.id: Rect.fromLTWH(
          origin.dx + card.rect.left * scale,
          origin.dy + card.rect.top * scale,
          card.rect.width * scale,
          card.rect.height * scale,
        ),
    };
    final colors = {
      for (final card in cards) card.id: canvasKindColor(card.kind),
    };
    for (final (from, to) in edges) {
      final start = positions[from]?.centerRight;
      final end = positions[to]?.centerLeft;
      if (start == null || end == null) continue;
      final middle = (start.dx + end.dx) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(middle, start.dy, middle, end.dy, end.dx, end.dy);
      canvas.drawPath(
        path,
        paint
          ..style = PaintingStyle.stroke
          ..color = colors[to]!.withValues(alpha: .51),
      );
    }
    for (final card in cards) {
      final rect = positions[card.id]!;
      final tint = colors[card.id]!;
      final box = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(
        box,
        paint
          ..style = PaintingStyle.fill
          ..color = Color.alphaBlend(
            tint.withValues(alpha: .14),
            const Color(0xFF201B1D),
          ),
      );
      canvas.drawRRect(
        box,
        paint
          ..style = PaintingStyle.stroke
          ..color = tint.withValues(alpha: .67),
      );
      if (rect.width < 13 || rect.height < 5) continue;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(rect.left + 5, rect.center.dy),
        1.65,
        paint..color = tint,
      );
      if (labels && rect.width >= 32 && rect.height >= 13) {
        final title = TextPainter(
          text: TextSpan(
            text: card.title,
            style: const TextStyle(fontSize: 9, color: AppColors.onSurface),
          ),
          textDirection: direction,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: rect.width - 13);
        title.paint(
          canvas,
          Offset(rect.left + 10, rect.center.dy - title.height / 2),
        );
        title.dispose();
      } else {
        canvas.drawLine(
          Offset(rect.left + 10, rect.center.dy),
          Offset(rect.left + rect.width * .83, rect.center.dy),
          paint..color = tint.withValues(alpha: .58),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPreviewPainter oldDelegate) =>
      cards != oldDelegate.cards ||
      edges != oldDelegate.edges ||
      direction != oldDelegate.direction ||
      labels != oldDelegate.labels;
}

class CanvasEntityPicker extends StatefulWidget {
  const CanvasEntityPicker({
    super.key,
    required this.entities,
    this.title = 'Добавить карточку',
  });
  final List<GraphNodeData> entities;
  final String title;

  @override
  State<CanvasEntityPicker> createState() => _CanvasEntityPickerState();
}

class _CanvasEntityPickerState extends State<CanvasEntityPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final entities = widget.entities
        .where((entity) => entity.title.toLowerCase().contains(_search))
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 410,
        height: 350,
        child: Column(
          children: [
            TextField(
              onChanged: (text) =>
                  setState(() => _search = text.toLowerCase().trim()),
              decoration: const InputDecoration(
                hintText: 'Поиск по названию',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: entities.isEmpty
                  ? const Center(child: Text('Нет доступных карточек'))
                  : ListView.builder(
                      itemCount: entities.length,
                      itemBuilder: (context, i) {
                        final entity = entities[i];
                        return ListTile(
                          leading: Icon(
                            canvasKindIcon(entity.kind),
                            color: canvasKindColor(entity.kind),
                          ),
                          title: Text(entity.title),
                          subtitle: Text(canvasKindLabel(entity.kind)),
                          onTap: () => Navigator.pop(context, entity),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
