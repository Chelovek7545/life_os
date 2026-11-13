import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notes_api/notes_api.dart';
import 'package:path/path.dart' as p;
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

const _accent = AppColors.primaryContainer;
const _ink = Color(0xFFF4F3F2);
const _muted = Color(0xFFB5B2B2);

class MarkdownNotesPanel extends StatefulWidget {
  const MarkdownNotesPanel({
    super.key,
    required this.state,
    required this.onOpen,
    this.onCreate,
    this.onDelete,
  });
  final VaultState state;
  final Future<void> Function(VaultNote) onOpen;
  final Future<VaultNote?> Function()? onCreate;
  final Future<void> Function(VaultNote)? onDelete;

  @override
  State<MarkdownNotesPanel> createState() => _MarkdownNotesPanelState();
}

class _MarkdownNotesPanelState extends State<MarkdownNotesPanel> {
  final _search = TextEditingController();
  String? _selectedPath;
  bool _creating = false;
  bool _opening = false;
  bool _deleting = false;

  Future<void> _delete(VaultNote note) async {
    final delete = widget.onDelete;
    if (delete == null || _deleting) return;
    setState(() => _deleting = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить заметку?'),
          content: Text(
            'Файл «${p.basename(note.absolutePath)}» будет удалён с диска. '
            'Карточки на графах сохранятся, но файл станет недоступен.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              key: const ValueKey('markdown-delete-confirm'),
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Удалить файл'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await delete(note);
      if (mounted) {
        setState(() {
          if (_selectedPath == note.absolutePath) _selectedPath = null;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить заметку: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final create = widget.onCreate;
    if (create == null || _creating) return;
    setState(() => _creating = true);
    try {
      final note = await create();
      if (mounted && note != null) {
        _search.clear();
        setState(() => _selectedPath = note.absolutePath);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _open(VaultNote note) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _selectedPath = note.absolutePath;
    });
    try {
      await widget.onOpen(note);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final files = <String, VaultNote>{
      for (final note in widget.state.notes) note.absolutePath: note,
    };
    final notes =
        files.values
            .where(
              (note) =>
                  query.isEmpty ||
                  '${note.title} ${note.relativePath} ${note.content}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList()
          ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    final selected = notes.any((note) => note.absolutePath == _selectedPath)
        ? _selectedPath
        : notes.firstOrNull?.absolutePath;
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxWidth >= 700;
        final padding = roomy ? 24.0 : 16.0;
        final title = Row(
          children: [
            const Icon(Icons.edit_square, size: 22, color: _accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Markdown-заметки графа',
                style: AppTypography.bodyMd.copyWith(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        );
        final search = TextField(
          key: const ValueKey('markdown-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: AppTypography.bodySm.copyWith(color: _ink),
          decoration: InputDecoration(
            hintText: 'Поиск в заметках…',
            hintStyle: const TextStyle(color: _muted),
            prefixIcon: const Icon(Icons.search, color: _muted, size: 22),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Очистить поиск',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: Colors.black.withValues(alpha: .16),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: Color(0xFF3A3838)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: _accent),
            ),
          ),
        );
        final create = Tooltip(
          message: widget.onCreate == null
              ? 'Выберите папку Notes в настройках графа'
              : 'Новая Markdown-заметка',
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.onCreate == null
                    ? [const Color(0xFF353232), const Color(0xFF242222)]
                    : [const Color(0xFFFF720B), const Color(0xFFAF3900)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.onCreate == null
                    ? const Color(0xFF454141)
                    : _accent,
              ),
              boxShadow: widget.onCreate == null
                  ? []
                  : [
                      BoxShadow(
                        color: _accent.withValues(alpha: .2),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey('markdown-create'),
                onPressed: widget.onCreate == null || _creating
                    ? null
                    : _create,
                icon: Icon(
                  Icons.add,
                  color: _ink.withValues(alpha: _creating ? .5 : 1),
                  size: 27,
                ),
              ),
            ),
          ),
        );
        return Container(
          key: const ValueKey('markdown-gallery'),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF171616), Color(0xFF0D0D0E)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .16),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (constraints.maxWidth >= 1000)
                Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 18),
                    SizedBox(width: 260, child: search),
                    const SizedBox(width: 20),
                    create,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    create,
                  ],
                ),
              const SizedBox(height: 10),
              Tooltip(
                message: widget.state.vaultPath,
                child: Text(
                  widget.state.vaultPath.isEmpty
                      ? 'Папка Notes не выбрана'
                      : widget.state.vaultPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
              ),
              if (constraints.maxWidth < 1000) ...[
                const SizedBox(height: 16),
                search,
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: .08),
                ),
              ),
              if (widget.state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    widget.state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (widget.state.isLoading && files.isEmpty)
                const SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
                )
              else if (notes.isEmpty)
                SizedBox(
                  height: 230,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          query.isEmpty
                              ? Icons.note_alt_outlined
                              : Icons.search_off,
                          color: _muted,
                          size: 36,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          query.isEmpty
                              ? 'Пока нет Markdown-заметок'
                              : 'Ничего не найдено',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          query.isEmpty
                              ? 'Создайте заметку кнопкой + или добавьте .md в папку Notes.'
                              : 'Попробуйте другое название или слово из текста.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySm.copyWith(
                            color: _muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, grid) {
                    const baseHeight = 220.0;
                    final desiredHeight = MediaQuery.textScalerOf(
                      context,
                    ).scale(baseHeight).clamp(baseHeight, baseHeight * 1.5);
                    final columns =
                        ((grid.maxWidth + 14) / (desiredHeight + 14))
                            .floor()
                            .clamp(1, 4);
                    final rows = (notes.length / columns).ceil();
                    final maximumRowFlex =
                        (columns ~/ 2) * 5 + (columns.isOdd ? 3 : 0);
                    final single = notes.length == 1;
                    final rowWidth = single
                        ? math.min(grid.maxWidth, desiredHeight)
                        : grid.maxWidth;
                    final height = single
                        ? rowWidth
                        : math.min(
                            desiredHeight,
                            columns == 1
                                ? grid.maxWidth
                                : (grid.maxWidth - (columns - 1) * 14) *
                                      2 /
                                      maximumRowFlex,
                          );
                    return SizedBox(
                      height: (rows * (height + 14) - 14).clamp(height, 850.0),
                      child: ListView.separated(
                        primary: false,
                        padding: EdgeInsets.zero,
                        itemCount: rows,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, row) {
                          Widget card(int index) => _MarkdownFileCard(
                            key: ValueKey(notes[index].absolutePath),
                            note: notes[index],
                            root: widget.state.vaultPath,
                            selected: notes[index].absolutePath == selected,
                            onOpen: () => _open(notes[index]),
                            onDelete: widget.onDelete == null || _deleting
                                ? null
                                : () => _delete(notes[index]),
                          );
                          final index = row * columns;
                          return Align(
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: single ? rowWidth : null,
                              height: height,
                              child: single
                                  ? card(index)
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (
                                          var column = 0;
                                          column < columns;
                                          column++
                                        ) ...[
                                          if (column > 0)
                                            const SizedBox(width: 14),
                                          Expanded(
                                            flex: columns == 1
                                                ? 1
                                                : (row + column).isEven
                                                ? 3
                                                : 2,
                                            child: index + column < notes.length
                                                ? card(index + column)
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MarkdownFileCard extends StatefulWidget {
  const _MarkdownFileCard({
    super.key,
    required this.note,
    required this.root,
    required this.selected,
    required this.onOpen,
    this.onDelete,
  });
  final VaultNote note;
  final String root;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  @override
  State<_MarkdownFileCard> createState() => _MarkdownFileCardState();
}

class _MarkdownFileCardState extends State<_MarkdownFileCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final highlighted = _hovered || widget.selected;
      final relative = p.relative(widget.note.absolutePath, from: widget.root);
      final folders = p.split(relative);
      final category = folders.length > 1 ? folders.first : null;
      final title = p.basenameWithoutExtension(widget.note.absolutePath);
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: highlighted
                  ? _accent
                  : Colors.white.withValues(alpha: .065),
              width: highlighted ? 1.2 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlighted
                  ? [
                      const Color(0xFF512A1C),
                      const Color(0xFF171719),
                      const Color(0xFF121214),
                    ]
                  : [
                      const Color(0xFF242324),
                      const Color(0xFF19191B),
                      const Color(0xFF121214),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: highlighted
                    ? _accent.withValues(alpha: .1)
                    : Colors.black.withValues(alpha: .1),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: widget.onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: category == null
                              ? Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: AppTypography.bodyMd.fontSize,
                                    fontFamily: AppTypography.bodyMd.fontFamily,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                )
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: _FolderBadge(category),
                                ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.description_outlined,
                          color: _muted,
                          size: 23,
                        ),
                      ],
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink,
                          fontSize: AppTypography.bodyMd.fontSize,
                          fontFamily: AppTypography.bodyMd.fontFamily,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: _MarkdownPreview(text: widget.note.content),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dateLabel(widget.note.modifiedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(
                              color: _muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Действия заметки',
                          icon: const Icon(
                            Icons.more_horiz,
                            color: _ink,
                            size: 22,
                          ),
                          color: const Color(0xFF242122),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onSelected: (action) async {
                            if (action == 'open') {
                              widget.onOpen();
                            } else if (action == 'delete') {
                              widget.onDelete?.call();
                            } else {
                              await Clipboard.setData(
                                ClipboardData(text: widget.note.absolutePath),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Путь скопирован'),
                                  ),
                                );
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'open',
                              child: Text('Редактировать'),
                            ),
                            const PopupMenuItem(
                              value: 'path',
                              child: Text('Скопировать путь'),
                            ),
                            if (widget.onDelete != null)
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Удалить заметку',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FolderBadge extends StatelessWidget {
  const _FolderBadge(this.name);
  final String name;
  @override
  Widget build(BuildContext context) {
    final value = name.toLowerCase();
    final color = value.contains('иде') || value.contains('idea')
        ? const Color(0xFF519C32)
        : value.contains('уч') || value.contains('study')
        ? const Color(0xFFA276C6)
        : const Color(0xFF3D91B5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Color.lerp(color, Colors.white, .65),
          fontSize: AppTypography.bodySm.fontSize! - 2,
          fontFamily: AppTypography.bodySm.fontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final lines = const LineSplitter().convert(text);
      if (lines.firstOrNull?.trim() == '---') {
        final end = lines
            .skip(1)
            .toList()
            .indexWhere((line) => line.trim() == '---');
        if (end >= 0) lines.removeRange(0, end + 2);
      }
      final spans = <InlineSpan>[];
      for (final line
          in lines.where((line) => line.trim().isNotEmpty).take(8)) {
        if (spans.isNotEmpty) spans.add(const TextSpan(text: '\n'));
        final check = RegExp(r'^\s*[-*] \[([ xX])\]\s*(.*)$').firstMatch(line);
        final heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
        if (check != null) {
          final done = check[1]!.toLowerCase() == 'x';
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Icon(
                  done
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank,
                  size: 17,
                  color: done ? _accent : _muted,
                ),
              ),
            ),
          );
          spans.add(
            TextSpan(
              text: check[2],
              style: TextStyle(
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? _muted : null,
              ),
            ),
          );
        } else if (heading != null) {
          spans.add(
            TextSpan(
              text: '${heading[1]}  ',
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
          spans.add(
            TextSpan(
              text: heading[2],
              style: const TextStyle(fontWeight: FontWeight.w600, color: _ink),
            ),
          );
        } else {
          spans.add(
            TextSpan(text: line.replaceAll('**', '').replaceAll('`', '')),
          );
        }
      }
      final lineHeight =
          MediaQuery.textScalerOf(
            context,
          ).scale(AppTypography.bodySm.fontSize!) *
          1.4;
      final maxLines = math.max(
        1,
        math.min(6, (constraints.maxHeight / lineHeight).floor()),
      );
      return ClipRect(
        child: Align(
          alignment: Alignment.topLeft,
          child: Text.rich(
            TextSpan(
              children: spans.isEmpty
                  ? [const TextSpan(text: 'Пустая заметка')]
                  : spans,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(color: _muted, height: 1.4),
          ),
        ),
      );
    },
  );
}

String _dateLabel(DateTime date) {
  const months = [
    'янв.',
    'февр.',
    'мар.',
    'апр.',
    'мая',
    'июн.',
    'июл.',
    'авг.',
    'сент.',
    'окт.',
    'нояб.',
    'дек.',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
