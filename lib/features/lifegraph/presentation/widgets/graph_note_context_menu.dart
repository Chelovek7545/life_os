import 'package:flutter/material.dart';
import 'graph_theme.dart';

enum GraphNoteMenuAction { edit, markdown, saveCopy, remove, reload }

Future<GraphNoteMenuAction?> showGraphNoteContextMenu(
  BuildContext context,
  Offset position, {
  required Color accent,
  required bool canEdit,
  required bool canConvert,
  required bool canDelete,
  bool canReload = false,
  bool canSaveCopy = false,
}) {
  final palette = AppGraphThemes.dark;
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final point = overlay.globalToLocal(position);
  PopupMenuItem<GraphNoteMenuAction> action(
    GraphNoteMenuAction value,
    String label,
    IconData icon, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    height: 42,
    child: Row(
      children: [
        Icon(icon, size: 18, color: color ?? palette.textDim),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color ?? palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
  return showMenu<GraphNoteMenuAction>(
    context: context,
    semanticLabel: 'Действия заметки',
    position: RelativeRect.fromSize(
      Rect.fromLTWH(point.dx, point.dy, 0, 0),
      overlay.size,
    ),
    color: palette.surface,
    surfaceTintColor: Colors.transparent,
    shadowColor: palette.shadow,
    elevation: 16,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: palette.border),
    ),
    constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
    items: [
      PopupMenuItem<GraphNoteMenuAction>(
        enabled: false,
        height: 30,
        child: Text(
          'ЗАМЕТКА',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ),
      if (canEdit)
        action(GraphNoteMenuAction.edit, 'Редактировать', Icons.edit_outlined),
      if (canConvert)
        action(
          GraphNoteMenuAction.markdown,
          'Преобразовать в .md',
          Icons.note_add_outlined,
          color: accent,
        ),
      if (canSaveCopy)
        action(
          GraphNoteMenuAction.saveCopy,
          'Сохранить копию .md в папку…',
          Icons.drive_file_move_outlined,
        ),
      if (canDelete)
        action(
          GraphNoteMenuAction.remove,
          'Удалить с доски',
          Icons.delete_outline,
        ),
      if (canReload) ...[
        const PopupMenuDivider(),
        action(
          GraphNoteMenuAction.reload,
          'Загрузить внешнюю версию',
          Icons.restore,
        ),
      ],
    ],
  );
}
