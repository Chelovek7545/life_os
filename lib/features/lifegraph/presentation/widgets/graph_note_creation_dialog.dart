import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'graph_theme.dart';

enum GraphNoteCreation { sticker, obsidian, markdownLibrary, markdownFile }

Future<GraphNoteCreation?> showGraphNoteCreationDialog(
  BuildContext context, {
  required bool canCreateMarkdown,
}) => showDialog<GraphNoteCreation>(
  context: context,
  builder: (_) =>
      _GraphNoteCreationDialog(canCreateMarkdown: canCreateMarkdown),
);

class _GraphNoteCreationDialog extends StatelessWidget {
  const _GraphNoteCreationDialog({required this.canCreateMarkdown});
  final bool canCreateMarkdown;

  @override
  Widget build(BuildContext context) {
    final palette = AppGraphThemes.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF242123), Color(0xFF171619), Color(0xFF211B1B)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .15)),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final narrow = width < 480;
                final scaler = MediaQuery.textScalerOf(context);
                final wide = width >= math.max(600, scaler.scale(150) * 4 + 30);
                final twoColumns =
                    width >= math.max(420, scaler.scale(150) * 2 + 10);
                final height = math.max(104.0, scaler.scale(72) + 32);
                final heading = Text(
                  'Добавить заметку',
                  style: AppTypography.bodyMd.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    height: 1.25,
                  ),
                );
                final subtitle = Text(
                  'Выберите способ создания заметки на графе:',
                  style: AppTypography.bodySm.copyWith(
                    color: const Color(0xFFB8B5BE),
                    fontSize: 12,
                  ),
                );
                final close = IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .05),
                    foregroundColor: const Color(0xFFB8B5BE),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                );
                final emblem = Container(
                  width: narrow ? 38 : 46,
                  height: narrow ? 38 : 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: palette.accentFor(0).withValues(alpha: .10),
                    border: Border.all(
                      color: palette.accentFor(0).withValues(alpha: .13),
                    ),
                  ),
                  child: Icon(
                    Icons.note_alt_outlined,
                    size: narrow ? 22 : 26,
                    color: const Color(0xFFFF9753),
                  ),
                );
                Widget tile(
                  String label,
                  Widget icon,
                  GraphNoteCreation choice, {
                  bool primary = false,
                  bool enabled = true,
                }) => _CreationTile(
                  label: label,
                  icon: icon,
                  primary: primary,
                  enabled: enabled,
                  compact: !wide && !twoColumns,
                  onTap: () => Navigator.pop(context, choice),
                );
                const iconColor = Color(0xFFAAA8BA);
                final tiles = [
                  tile(
                    'Пустой стикер',
                    const Icon(
                      Icons.crop_free_rounded,
                      size: 26,
                      color: iconColor,
                    ),
                    GraphNoteCreation.sticker,
                    primary: true,
                  ),
                  tile(
                    'Из Obsidian',
                    const SizedBox(
                      width: 28,
                      height: 32,
                      child: CustomPaint(painter: _ObsidianGlyph()),
                    ),
                    GraphNoteCreation.obsidian,
                  ),
                  tile(
                    'Из Markdown-хранилища',
                    const Icon(
                      Icons.file_download_outlined,
                      size: 28,
                      color: iconColor,
                    ),
                    GraphNoteCreation.markdownLibrary,
                  ),
                  tile(
                    'Создать .md',
                    const Icon(
                      Icons.note_add_outlined,
                      size: 28,
                      color: iconColor,
                    ),
                    GraphNoteCreation.markdownFile,
                    enabled: canCreateMarkdown,
                  ),
                ];
                return FocusTraversalGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          emblem,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                heading,
                                if (!narrow) ...[
                                  const SizedBox(height: 8),
                                  subtitle,
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          close,
                        ],
                      ),
                      if (narrow) ...[const SizedBox(height: 12), subtitle],
                      const SizedBox(height: 20),
                      if (wide)
                        IntrinsicHeight(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: height),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < tiles.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 10),
                                  Expanded(child: tiles[i]),
                                ],
                              ],
                            ),
                          ),
                        )
                      else if (twoColumns)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var row = 0; row < 2; row++) ...[
                              if (row > 0) const SizedBox(height: 10),
                              IntrinsicHeight(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: height,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: tiles[row * 2]),
                                      const SizedBox(width: 10),
                                      Expanded(child: tiles[row * 2 + 1]),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < tiles.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              tiles[i],
                            ],
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CreationTile extends StatefulWidget {
  const _CreationTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.compact,
    this.primary = false,
    this.enabled = true,
  });
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool compact;
  final bool primary;
  final bool enabled;
  @override
  State<_CreationTile> createState() => _CreationTileState();
}

class _CreationTileState extends State<_CreationTile> {
  bool _hovered = false;
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final highlighted =
        widget.enabled && (widget.primary || _hovered || _focused);
    final accent = AppGraphThemes.dark.accentFor(0);
    final label = Text(
      widget.label,
      textAlign: widget.compact ? TextAlign.start : TextAlign.center,
      style: AppTypography.bodySm.copyWith(
        color: AppGraphThemes.dark.text,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : .38,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlighted
                  ? [
                      const Color(0xFF54372C),
                      const Color(0xFF2B2221),
                      const Color(0xFF39271F),
                    ]
                  : [const Color(0xFF2A282C), const Color(0xFF201E22)],
            ),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFED8A49)
                  : Colors.white.withValues(alpha: .10),
              width: highlighted ? 1.4 : 1,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .10),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.enabled ? widget.onTap : null,
              canRequestFocus: widget.enabled,
              onHover: (value) => setState(() => _hovered = value),
              onFocusChange: (value) => setState(() => _focused = value),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: widget.compact
                    ? Row(
                        children: [
                          widget.icon,
                          const SizedBox(width: 12),
                          Expanded(child: label),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          widget.icon,
                          const SizedBox(height: 10),
                          label,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ObsidianGlyph extends CustomPainter {
  const _ObsidianGlyph();
  @override
  void paint(Canvas canvas, Size size) {
    Offset point(double x, double y) => Offset(size.width * x, size.height * y);
    final outline = Path()
      ..moveTo(size.width * .43, size.height * .06)
      ..lineTo(size.width * .18, size.height * .28)
      ..lineTo(size.width * .12, size.height * .62)
      ..lineTo(size.width * .31, size.height * .88)
      ..lineTo(size.width * .60, size.height * .98)
      ..lineTo(size.width * .80, size.height * .76)
      ..lineTo(size.width * .90, size.height * .40)
      ..close();
    canvas.drawPath(outline, Paint()..color = const Color(0xFF332C4D));
    final facet = Path()
      ..moveTo(size.width * .43, size.height * .06)
      ..lineTo(size.width * .47, size.height * .58)
      ..lineTo(size.width * .60, size.height * .98)
      ..lineTo(size.width * .80, size.height * .76)
      ..close();
    canvas.drawPath(facet, Paint()..color = const Color(0xFF4C416C));
    canvas.drawLine(
      point(.18, .28),
      point(.47, .58),
      Paint()
        ..color = const Color(0xFF63577E)
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFFAAA8BA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
