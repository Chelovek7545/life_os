import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:sync_plugin/sync_logic.dart';

import 'sync_conflict_comparison.dart';
import 'sync_text_difference.dart';

const _conflictAccent = Color(0xFFFF923F);

class SyncConflictsPanel extends StatefulWidget {
  const SyncConflictsPanel({
    super.key,
    required this.control,
    required this.isCurrent,
    required this.onBack,
    required this.onClose,
  });

  final LocalSyncControl control;
  final bool Function() isCurrent;
  final VoidCallback onBack, onClose;

  @override
  State<SyncConflictsPanel> createState() => _SyncConflictsPanelState();
}

class _SyncConflictsPanelState extends State<SyncConflictsPanel> {
  Map<String, List<SyncRevision>> _groups = {};
  Map<String, String> _names = {};
  Map<String, String> _titles = {};
  List<SyncDifferenceSection> _differences = [];
  String? _group, _selectedVersionId, _error;
  bool _loading = true, _saving = false, _reloadRequired = false;
  bool _showAllFields = true;
  Map<SyncFieldDifference, int>? _mergeChoices;

  List<SyncRevision> get _versions => _groups[_group] ?? const [];
  bool get _hasDeletion => _versions.any((revision) => revision.deleted);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted || !widget.isCurrent()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final control = widget.control;
    try {
      final (groups, names) = await (
        control.conflicts(),
        control.entityNames(),
      ).wait;
      if (!mounted || !widget.isCurrent()) return;
      setState(() {
        _names = names;
        final device = control.state.deviceId;
        _groups = {
          for (final entry in groups.entries)
            if (entry.value.length > 1)
              entry.key: [
                ...entry.value.where((version) => version.deviceId == device),
                ...entry.value.where((version) => version.deviceId != device),
              ],
        };
        _titles = _groups.map(
          (key, versions) => MapEntry(key, _groupTitle(versions)),
        );
        _reloadRequired = false;
        _selectGroup(
          _groups.containsKey(_group) ? _group : _groups.keys.firstOrNull,
        );
      });
    } catch (error) {
      if (!mounted || !widget.isCurrent()) return;
      setState(() {
        _reloadRequired = true;
        _error = _message(error, 'Не удалось загрузить конфликты.');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectGroup(String? key) {
    _group = key;
    _selectedVersionId = null;
    _mergeChoices = null;
    _updateComparison();
  }

  void _updateComparison() {
    final versions = _versions;
    _differences = versions.isEmpty
        ? []
        : compareSyncVersions(
            versions,
            _names,
            includeUnchanged: _showAllFields,
          );
  }

  String _groupTitle(List<SyncRevision> versions) => syncRevisionTitle(
    versions.firstWhere(
      (version) => !version.deleted,
      orElse: () => versions.first,
    ),
    _names,
  );

  bool _canChoose(SyncRevision revision) =>
      !_hasDeletion ||
      revision.deleted ||
      SyncPayload.externalNotes.contains(revision.entityType);

  Future<void> _apply(SyncRevision version, {String? mergedPayload}) async {
    if (!mounted ||
        !widget.isCurrent() ||
        _loading ||
        _saving ||
        _reloadRequired ||
        widget.control.state.busy ||
        !_versions.contains(version) ||
        !_canChoose(version)) {
      return;
    }
    final basis = _versions.map((item) => item.id).toSet();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.control.resolve(
        version,
        basis,
        mergedPayload: mergedPayload,
      );
      await _load();
    } catch (error) {
      if (!mounted || !widget.isCurrent()) return;
      setState(() {
        _reloadRequired = mergedPayload == null;
        _error = _message(
          error,
          mergedPayload == null
              ? 'Не удалось применить версию.'
              : 'Не удалось сохранить выбранные значения. Проверьте связи и даты или обновите список конфликтов.',
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _saveMerge() {
    final versions = _versions;
    final choices = _mergeChoices;
    if (choices == null || versions.isEmpty) return;
    try {
      final payload = buildMergedSyncPayload(versions, choices);
      unawaited(_apply(versions.first, mergedPayload: payload));
    } on LocalSyncException catch (error) {
      setState(() => _error = error.message);
    } on FormatException {
      setState(
        () => _error =
            'Выбранные значения несовместимы. Проверьте даты, связи и типы карточек.',
      );
    }
  }

  String _message(Object error, String fallback) =>
      error is LocalSyncException ? error.message : fallback;

  List<String> _sources(LocalSyncState state, List<SyncRevision> versions) {
    final peers = {
      for (final peer in [...state.peers, ...state.unverifiedPeers])
        peer.id: peer.name,
    };
    final labels = [
      for (final version in versions)
        if (version.deviceId == state.deviceId)
          'Это устройство'
        else
          peers[version.deviceId] ?? 'Другое устройство',
    ];
    return [
      for (final (index, label) in labels.indexed)
        labels.where((item) => item == label).length > 1
            ? '$label · ${index + 1}'
            : label,
    ];
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<LocalSyncState>(
    stream: widget.control.states,
    initialData: widget.control.state,
    builder: (context, snapshot) {
      final state = snapshot.data ?? widget.control.state;
      final versions = _versions;
      final sources = _sources(state, versions);
      final choices = _mergeChoices;
      final selectedVersion = versions
          .where((version) => version.id == _selectedVersionId)
          .firstOrNull;
      final locked = _loading || _saving || state.busy || _reloadRequired;
      final theme = Theme.of(context);

      return LayoutBuilder(
        builder: (_, constraints) {
          final scrollTogether = constraints.maxHeight < 390;
          final sidebar =
              _groups.isNotEmpty &&
              constraints.maxWidth >= 878 &&
              !scrollTogether;
          final inset = constraints.maxWidth < 480 ? 12.0 : 20.0;
          final comparisonWidth =
              constraints.maxWidth - inset * 2 - (sidebar ? 242 : 0);
          final labelWidth =
              versions.length <= 3 &&
                  comparisonWidth >= 144 + versions.length * 164
              ? 130.0
              : 0.0;
          final columns =
              versions.length <= 3 &&
              (comparisonWidth - labelWidth) >= versions.length * 164;
          final devices = [
            for (final (index, version) in versions.indexed)
              _DeviceColumnHeading(
                name: sources[index],
                local: version.deviceId == state.deviceId,
                deleted: version.deleted,
                selected: choices == null && version.id == _selectedVersionId,
                onPressed: locked || choices != null || !_canChoose(version)
                    ? null
                    : () => setState(() => _selectedVersionId = version.id),
              ),
          ];
          final comparison = [
            if (_loading || _saving) const LinearProgressIndicator(),
            if (_error case final message?)
              _ConflictSurface(
                child: Text(
                  message,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (!_loading && !_reloadRequired && versions.isEmpty)
              const _ConflictSurface(child: Text('Конфликтов нет.')),
            if (versions.isNotEmpty) ...[
              _recordHeading(theme),
              if (columns)
                _ComparisonRow(labelWidth: labelWidth, children: devices)
              else
                Column(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: devices,
                ),
              if (_differences.isEmpty)
                const _ConflictSurface(
                  child: Text('Содержимое версий совпадает.'),
                ),
              for (final section in _differences) ...[
                if (section.title case final title?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                for (final field in section.fields)
                  _ConflictField(
                    key: ObjectKey(field.values),
                    field: field,
                    sources: sources,
                    columns: columns,
                    labelWidth: labelWidth,
                    selected:
                        choices != null && field.changed && field.path != null
                        ? choices[field] ?? 0
                        : null,
                    onSelect:
                        choices != null &&
                            field.changed &&
                            field.path != null &&
                            !locked
                        ? (index) => setState(() {
                            choices[field] = index;
                            _error = null;
                          })
                        : null,
                  ),
              ],
            ],
          ];
          final header = _header(
            theme,
            state.busy,
            inset,
            constraints.maxWidth >= 900,
          );
          final footer = versions.isEmpty
              ? null
              : _footer(theme, selectedVersion, locked, inset);
          final navigation = sidebar || _groups.length > 1
              ? _navigation(theme, sidebar, inset)
              : null;
          if (scrollTogether) {
            return ListView(
              key: ValueKey(_group),
              shrinkWrap: true,
              primary: false,
              children: [
                header,
                ?navigation,
                const SizedBox(height: 12),
                for (final item in comparison)
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
                    child: item,
                  ),
                ?footer,
              ],
            );
          }
          final detail = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: ListView.separated(
                  key: ValueKey(_group),
                  shrinkWrap: true,
                  primary: false,
                  padding: EdgeInsets.fromLTRB(inset, 12, inset, 14),
                  itemCount: comparison.length,
                  itemBuilder: (_, index) => comparison[index],
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                ),
              ),
              ?footer,
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (!sidebar) ?navigation,
              Flexible(
                child: sidebar
                    ? Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 242),
                            child: detail,
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 0,
                            child: navigation!,
                          ),
                        ],
                      )
                    : detail,
              ),
            ],
          );
        },
      );
    },
  );

  Widget _header(ThemeData theme, bool busy, double inset, bool wide) =>
      Container(
        padding: EdgeInsets.fromLTRB(inset - 6, 12, inset - 6, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderGlass)),
        ),
        child: Row(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Назад к синхронизации',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            if (wide)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _conflictAccent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: _conflictAccent,
                  size: 28,
                ),
              ),
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      'Разрешение конфликтов синхронизации',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: wide ? 22 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_groups.isNotEmpty)
                      Text(
                        'Записей с конфликтом: ${_groups.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (wide)
              Wrap(
                spacing: 16,
                children: [
                  for (final (label, color) in [
                    ('Изменено', _conflictAccent),
                    ('Без изменений', const Color(0xFF83828E)),
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Icon(Icons.square_rounded, size: 12, color: color),
                        Text(label, style: theme.textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
            IconButton(
              tooltip: 'Обновить список конфликтов',
              onPressed: _loading || _saving || busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Закрыть',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );

  Widget _recordHeading(ThemeData theme) {
    final versions = _versions;
    final type = versions.first.entityType;
    final count = _differences.fold(
      0,
      (total, section) =>
          total + section.fields.where((field) => field.changed).length,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            spacing: 10,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _conflictAccent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    _entityIcon(type),
                    color: _conflictAccent,
                    size: 22,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      syncEntityKind(type),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _conflictAccent,
                      ),
                    ),
                    Text(
                      _titles[_group] ?? syncEntityKind(type),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    size: 18,
                    color: count > 0
                        ? _conflictAccent
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    'Изменённых полей: $count',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (_mergeChoices == null && type != 'canvasBoard')
                FilterChip(
                  label: const Text('Только различия'),
                  selected: !_showAllFields,
                  onSelected: (value) => setState(() {
                    _showAllFields = !value;
                    _updateComparison();
                  }),
                ),
            ],
          ),
          if (_mergeChoices != null)
            Text(
              'Выберите значение в каждой изменённой строке.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _navigation(ThemeData theme, bool sidebar, double inset) {
    final groups = _groups.entries.toList();
    Widget row(BuildContext context, int index) {
      final group = groups[index];
      final type = group.value.first.entityType;
      final active = group.key == _group;
      return Material(
        color: active
            ? _conflictAccent.withValues(alpha: .11)
            : AppColors.surfaceGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: active
                ? _conflictAccent.withValues(alpha: .46)
                : AppColors.borderGlass,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          selected: active,
          child: InkWell(
            onTap: _loading || _saving || active
                ? null
                : () => setState(() => _selectGroup(group.key)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                spacing: 8,
                children: [
                  Icon(
                    _entityIcon(type),
                    size: 18,
                    color: active
                        ? AppColors.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titles[group.key] ?? syncEntityKind(type),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          syncEntityKind(type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return sidebar
        ? Container(
            width: 242,
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              border: Border(right: BorderSide(color: AppColors.borderGlass)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Text('Записи с конфликтами', style: theme.textTheme.titleSmall),
                Expanded(
                  child: ListView.separated(
                    primary: false,
                    itemCount: groups.length,
                    itemBuilder: row,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                  ),
                ),
              ],
            ),
          )
        : SizedBox(
            height: 85,
            child: ListView.separated(
              primary: false,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(inset, 8, inset, 4),
              itemCount: groups.length,
              itemBuilder: (context, index) =>
                  SizedBox(width: 206, child: row(context, index)),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
            ),
          );
  }

  Widget _footer(
    ThemeData theme,
    SyncRevision? selectedVersion,
    bool locked,
    double inset,
  ) {
    final versions = _versions;
    final choices = _mergeChoices;
    final changedLabels = {
      for (final section in _differences)
        for (final field in section.fields)
          if (field.changed) field.label,
    };
    final canMerge =
        !_hasDeletion &&
        _differences.any(
          (section) => section.fields.any(
            (field) => field.changed && field.path != null,
          ),
        );
    final primaryStyle = FilledButton.styleFrom(
      backgroundColor: _conflictAccent,
      foregroundColor: AppColors.surfaceDim,
      textStyle: theme.textTheme.labelLarge,
      minimumSize: const Size(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    final secondaryStyle = OutlinedButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurface,
      textStyle: theme.textTheme.labelLarge,
      backgroundColor: AppColors.surfaceGlass,
      minimumSize: const Size(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(inset, 10, inset, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderGlass)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (changedLabels.isNotEmpty && choices == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _conflictAccent.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _conflictAccent.withValues(alpha: .24),
                ),
              ),
              child: Row(
                spacing: 8,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: _conflictAccent,
                    size: 18,
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Изменены поля: ',
                        children: [
                          TextSpan(
                            text: [
                              ...changedLabels.take(4),
                              if (changedLabels.length > 4)
                                '+${changedLabels.length - 4}',
                            ].join(', '),
                            style: const TextStyle(
                              color: _conflictAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (_hasDeletion &&
              !SyncPayload.externalNotes.contains(versions.first.entityType))
            Text(
              'Для этой записи доступно подтверждение удаления.',
              style: theme.textTheme.bodySmall,
            ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              if (choices != null) ...[
                OutlinedButton(
                  style: secondaryStyle,
                  onPressed: locked
                      ? null
                      : () => setState(() {
                          _mergeChoices = null;
                          _error = null;
                        }),
                  child: const Text('Отмена'),
                ),
                FilledButton.icon(
                  style: primaryStyle,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  onPressed: locked ? null : _saveMerge,
                  label: const Text('Сохранить объединение'),
                ),
              ] else ...[
                if (canMerge)
                  OutlinedButton(
                    style: secondaryStyle,
                    onPressed: locked
                        ? null
                        : () => setState(() {
                            _mergeChoices = {};
                            _error = null;
                          }),
                    child: const Text('Объединить вручную'),
                  ),
                FilledButton.icon(
                  style: primaryStyle,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  onPressed:
                      locked ||
                          selectedVersion == null ||
                          !_canChoose(selectedVersion)
                      ? null
                      : () => _apply(selectedVersion),
                  label: Text(
                    selectedVersion?.deleted == true
                        ? 'Подтвердить удаление'
                        : 'Подтвердить версию',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

IconData _entityIcon(String type) => switch (type) {
  'task' => Icons.check_circle_outline_rounded,
  'workLog' => Icons.schedule_rounded,
  'project' => Icons.layers_outlined,
  'goal' => Icons.flag_outlined,
  'sphere' => Icons.bubble_chart_outlined,
  'tag' => Icons.sell_outlined,
  'habit' || 'habitEntry' => Icons.repeat_rounded,
  'note' => Icons.description_outlined,
  'canvasNode' || 'canvasBoard' => Icons.hub_outlined,
  'sticker' => Icons.sticky_note_2_outlined,
  _ => Icons.article_outlined,
};

class _ConflictSurface extends StatelessWidget {
  const _ConflictSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceGlass,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.borderGlass),
    ),
    child: child,
  );
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.labelWidth,
    this.label,
    this.changed = false,
    required this.children,
  });
  final double labelWidth;
  final Widget? label;
  final bool changed;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      if (labelWidth > 0) SizedBox(width: labelWidth, child: label),
      for (final (index, child) in children.indexed) ...[
        if (index == 1 && children.length == 2)
          SizedBox(
            width: 18,
            child: changed
                ? const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Icon(
                      Icons.compare_arrows_rounded,
                      color: _conflictAccent,
                      size: 18,
                    ),
                  )
                : null,
          ),
        Expanded(child: child),
      ],
    ],
  );
}

class _DeviceColumnHeading extends StatelessWidget {
  const _DeviceColumnHeading({
    required this.name,
    required this.local,
    required this.deleted,
    required this.selected,
    required this.onPressed,
  });
  final String name;
  final bool local, deleted, selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      spacing: 8,
      children: [
        Icon(
          local ? Icons.devices_outlined : Icons.devices_other_outlined,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleSmall),
              Text(
                deleted
                    ? 'Удаление'
                    : local
                    ? 'Локальная версия'
                    : 'Удалённая версия',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (onPressed != null || selected)
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            size: 18,
            color: selected
                ? _conflictAccent
                : theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );
    if (onPressed == null && !selected) return _ConflictSurface(child: content);
    return Tooltip(
      message: 'Выбрать версию: $name',
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        selected: selected,
        child: Material(
          color: selected
              ? _conflictAccent.withValues(alpha: .14)
              : AppColors.surfaceGlass,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: _conflictAccent.withValues(alpha: selected ? .70 : .28),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(padding: const EdgeInsets.all(12), child: content),
          ),
        ),
      ),
    );
  }
}

class _ConflictField extends StatefulWidget {
  const _ConflictField({
    super.key,
    required this.field,
    required this.sources,
    required this.columns,
    required this.labelWidth,
    required this.selected,
    required this.onSelect,
  });
  final SyncFieldDifference field;
  final List<String> sources;
  final bool columns;
  final double labelWidth;
  final int? selected;
  final ValueChanged<int>? onSelect;

  @override
  State<_ConflictField> createState() => _ConflictFieldState();
}

class _ConflictFieldState extends State<_ConflictField> {
  late final _excerpts = widget.field.text
      ? syncTextDifferences(widget.field.values)
      : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = widget.field;
    final label = Text(
      field.label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: field.changed
            ? _conflictAccent
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
    final values = [
      for (final (index, source) in widget.sources.indexed)
        _ConflictValue(
          source: source,
          showSource: !widget.columns,
          value: field.values[index],
          excerpt: _excerpts?[index],
          selected: index == widget.selected,
          changed: field.changed,
          onSelected: widget.onSelect == null
              ? null
              : () => widget.onSelect!(index),
        ),
    ];
    if (widget.columns && widget.labelWidth > 0) {
      return _ComparisonRow(
        labelWidth: widget.labelWidth,
        changed: field.changed,
        label: Padding(padding: const EdgeInsets.only(top: 9), child: label),
        children: values,
      );
    }
    return Column(
      spacing: 5,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        if (widget.columns)
          _ComparisonRow(
            labelWidth: 0,
            changed: field.changed,
            children: values,
          )
        else
          ...values,
      ],
    );
  }
}

class _ConflictValue extends StatelessWidget {
  const _ConflictValue({
    required this.source,
    required this.showSource,
    required this.value,
    required this.excerpt,
    required this.selected,
    required this.changed,
    required this.onSelected,
  });

  final String source;
  final String? value;
  final SyncTextExcerpt? excerpt;
  final bool showSource, selected, changed;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = theme.colorScheme.onSurfaceVariant;
    final data = value;
    final snippet = excerpt;
    final shortened = snippet?.shortened ?? (data?.length ?? 0) > 1600;
    final cell = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: changed
            ? _conflictAccent.withValues(alpha: selected ? .18 : .08)
            : AppColors.surfaceGlass,
        border: Border.all(
          color: selected
              ? _conflictAccent.withValues(alpha: .52)
              : changed
              ? _conflictAccent.withValues(alpha: .25)
              : AppColors.borderGlass,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          if (showSource || onSelected != null)
            Row(
              spacing: 6,
              children: [
                if (onSelected != null)
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected ? _conflictAccent : tint,
                  ),
                if (showSource)
                  Expanded(
                    child: Text(
                      source,
                      style: theme.textTheme.labelMedium?.copyWith(color: tint),
                    ),
                  ),
              ],
            ),
          if (data == null || data.isEmpty)
            Text(data == null ? '—' : 'Пусто', style: TextStyle(color: tint))
          else if (snippet != null)
            for (final line in snippet.lines)
              Text.rich(
                TextSpan(
                  children: [
                    if (line.number case final number?)
                      TextSpan(
                        text: '$number  ',
                        style: TextStyle(color: tint),
                      ),
                    for (final part in line.parts)
                      TextSpan(
                        text: part.text.isEmpty && line.parts.length == 1
                            ? ' '
                            : part.text,
                        style: part.changed
                            ? TextStyle(
                                color: _conflictAccent,
                                backgroundColor: _conflictAccent.withValues(
                                  alpha: .17,
                                ),
                              )
                            : null,
                      ),
                  ],
                ),
              )
          else
            Text(shortened ? '${data.substring(0, 1600)}…' : data),
          if (shortened && data != null)
            TextButton(
              onPressed: () => _showFull(context, data),
              child: const Text('Показать целиком'),
            ),
        ],
      ),
    );
    if (onSelected == null) return cell;
    return Semantics(
      selected: selected,
      button: true,
      label: showSource ? null : source,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onSelected,
        child: cell,
      ),
    );
  }

  Future<void> _showFull(BuildContext context, String data) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(source),
      content: SizedBox(
        width: 540,
        height: 360,
        child: ListView.builder(
          itemCount: (data.length + 4095) ~/ 4096,
          itemBuilder: (_, index) {
            final start = index * 4096;
            final end = (start + 4096).clamp(0, data.length);
            return SelectableText(data.substring(start, end));
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}
