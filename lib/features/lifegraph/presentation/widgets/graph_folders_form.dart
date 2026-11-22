import 'package:flutter/material.dart';
import 'package:notes_api/notes_api.dart';
import 'package:lifegraph_plugin/graph_storage_settings.dart';

class GraphFoldersForm extends StatefulWidget {
  const GraphFoldersForm({
    super.key,
    required this.initial,
    required this.listFolders,
    required this.save,
    this.initialTarget = const GraphStorageTarget(),
    this.saveTarget,
    this.pickDirectory,
    this.localAppDirectory,
    this.pickSharedFolder,
    this.vaultPath = '',
  });
  final VaultFolders initial;
  final Future<List<String>> Function() listFolders;
  final Future<void> Function(VaultFolders) save;
  final GraphStorageTarget initialTarget;
  final Future<void> Function(GraphStorageTarget)? saveTarget;
  final Future<String?> Function()? pickDirectory;
  final Future<String> Function()? localAppDirectory;
  final Future<GraphStorageTarget?> Function()? pickSharedFolder;
  final String vaultPath;
  @override
  State<GraphFoldersForm> createState() => _GraphFoldersFormState();
}

class _GraphFoldersFormState extends State<GraphFoldersForm> {
  late final _controllers = [
    widget.initial.boards,
    widget.initial.notes,
    widget.initial.exports,
    widget.initial.backups,
  ].map((text) => TextEditingController(text: text)).toList();
  bool _saving = false;
  bool _picking = false;
  String? _error;
  late GraphStorageMode _mode = widget.initialTarget.mode;
  late GraphStorageTarget? _sharedFolder =
      widget.initialTarget.mode == GraphStorageMode.sharedFolder
      ? widget.initialTarget
      : null;
  late final _root = TextEditingController(
    text: widget.initialTarget.localPath,
  );

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
    _root.dispose();
  }

  Future<void> _choose(int index) async {
    final folders = Future.sync(widget.listFolders);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Папка внутри vault'),
        content: SizedBox(
          width: 440,
          height: 360,
          child: FutureBuilder<List<String>>(
            future: folders,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('${snapshot.error}');
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: [
                  for (final folder in snapshot.data!)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(folder.isEmpty ? 'Корень vault' : folder),
                      onTap: () => Navigator.pop(context, folder),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (result != null && mounted) _controllers[index].text = result;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.saveTarget != null) {
        final localAppDirectory = widget.localAppDirectory;
        final localPath =
            _mode == GraphStorageMode.local && localAppDirectory != null
            ? await localAppDirectory()
            : _root.text.trim();
        if (!mounted) return;
        final target = _mode == GraphStorageMode.sharedFolder
            ? _sharedFolder ??
                  (throw StateError('Выберите папку для файлов графа.'))
            : GraphStorageTarget(mode: _mode, localPath: localPath);
        await widget.saveTarget!(target);
      }
      if (_mode == GraphStorageMode.obsidian) {
        await widget.save(
          VaultFolders(
            boards: _controllers[0].text,
            notes: _controllers[1].text,
            exports: _controllers[2].text,
            backups: _controllers[3].text,
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Папки сохранены')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseSharedFolder() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final selected = await widget.pickSharedFolder!();
      if (mounted && selected != null) setState(() => _sharedFolder = selected);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Расположение файлов графа'),
        const SizedBox(height: 8),
        if (widget.saveTarget != null) ...[
          DropdownButtonFormField<GraphStorageMode>(
            isExpanded: true,
            key: const ValueKey('graph-storage-mode'),
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Где хранить файлы'),
            items: [
              const DropdownMenuItem(
                value: GraphStorageMode.obsidian,
                child: Text('В vault Obsidian'),
              ),
              DropdownMenuItem(
                value: GraphStorageMode.local,
                child: Text(
                  widget.localAppDirectory == null
                      ? 'В папке Pulse на компьютере'
                      : 'В хранилище Pulse на устройстве',
                ),
              ),
              if (widget.pickSharedFolder != null ||
                  _mode == GraphStorageMode.sharedFolder)
                const DropdownMenuItem(
                  value: GraphStorageMode.sharedFolder,
                  child: Text('В выбранной папке'),
                ),
            ],
            onChanged: _saving || _picking
                ? null
                : (value) {
                    if (value != null) setState(() => _mode = value);
                  },
          ),
          const SizedBox(height: 12),
          if (_mode == GraphStorageMode.sharedFolder) ...[
            OutlinedButton.icon(
              onPressed: _saving || _picking || widget.pickSharedFolder == null
                  ? null
                  : _chooseSharedFolder,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(
                _sharedFolder?.folderName.isNotEmpty == true
                    ? _sharedFolder!.folderName
                    : 'Выбрать папку',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pulse будет сохранять сюда доски, заметки, экспорты и резервные копии.',
            ),
          ] else if (_mode == GraphStorageMode.local &&
              widget.localAppDirectory != null)
            const Text(
              'Доски, новые заметки графа, экспорты и копии будут храниться во внутренней папке приложения.',
            )
          else if (_mode == GraphStorageMode.local) ...[
            TextField(
              key: const ValueKey('graph-local-root'),
              controller: _root,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Единая папка Pulse',
                suffixIcon: IconButton(
                  tooltip: 'Выбрать папку Pulse',
                  onPressed: _saving || widget.pickDirectory == null
                      ? null
                      : () async {
                          try {
                            final path = await widget.pickDirectory!();
                            if (path != null && mounted) _root.text = path;
                          } catch (error) {
                            if (mounted) setState(() => _error = '$error');
                          }
                        },
                  icon: const Icon(Icons.folder_open_outlined),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'В этой папке будут доски, новые заметки графа, экспорты и копии: Boards, Notes, Exports и Backups. Заметки подключённого Obsidian доступны без переноса.',
            ),
          ] else
            Text(
              widget.vaultPath.isEmpty
                  ? 'Укажите vault в настройках Obsidian.'
                  : 'Vault: ${widget.vaultPath}',
            ),
          const SizedBox(height: 12),
        ],
        if (_mode == GraphStorageMode.obsidian) ...[
          const Text(
            'Выберите папки для досок и новых заметок графа. Пустое поле — корень vault. Существующие заметки остаются на месте и доступны для добавления на канвас.',
          ),
          for (var i = 0; i < _controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                key: ValueKey('graph-folder-$i'),
                controller: _controllers[i],
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: [
                    'Доски сфер',
                    'Новые Markdown-заметки графа',
                    'Экспорты Canvas',
                    'Резервные копии',
                  ][i],
                  suffixIcon: IconButton(
                    tooltip: 'Выбрать папку',
                    onPressed: _saving ? null : () => _choose(i),
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                ),
              ),
            ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed:
              _saving ||
                  _picking ||
                  (_mode == GraphStorageMode.sharedFolder &&
                      _sharedFolder == null)
              ? null
              : _save,
          child: const Text('Сохранить папки'),
        ),
      ],
    ),
  );
}
