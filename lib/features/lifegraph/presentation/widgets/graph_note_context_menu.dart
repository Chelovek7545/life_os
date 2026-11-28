import 'package:flutter/material.dart';

import 'canvas_context_menu.dart';

enum GraphNoteMenuAction { edit, markdown, saveCopy, remove, reload }

Future<GraphNoteMenuAction?> showGraphNoteContextMenu(
  BuildContext context,
  Offset position, {
  required bool canEdit,
  required bool canConvert,
  required bool canDelete,
  bool canReload = false,
  bool canSaveCopy = false,
}) => showCanvasContextMenu<GraphNoteMenuAction>(
  context,
  position & Size.zero,
  title: 'Заметка',
  actions: [
    if (canEdit)
      const CanvasContextOption(
        GraphNoteMenuAction.edit,
        'Редактировать',
        Icons.edit_outlined,
        accented: true,
      ),
    if (canConvert)
      const CanvasContextOption(
        GraphNoteMenuAction.markdown,
        'Преобразовать в .md',
        Icons.note_add_outlined,
      ),
    if (canSaveCopy)
      const CanvasContextOption(
        GraphNoteMenuAction.saveCopy,
        'Сохранить копию .md в папку…',
        Icons.drive_file_move_outlined,
      ),
    if (canReload)
      const CanvasContextOption(
        GraphNoteMenuAction.reload,
        'Загрузить внешнюю версию',
        Icons.restore,
      ),
    if (canDelete)
      const CanvasContextOption(
        GraphNoteMenuAction.remove,
        'Удалить с доски',
        Icons.delete_outline,
        destructive: true,
      ),
  ],
);
