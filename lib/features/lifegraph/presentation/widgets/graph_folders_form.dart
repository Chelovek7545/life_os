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
    this.vaultPath = '',
  });
  final VaultFolders initial;
  final Future<List<String>> Function() listFolders;
  final Future<void> Function(VaultFolders) save;
  final GraphStorageTarget initialTarget;
  final Future<void> Function(GraphStorageTarget)? saveTarget;
  final Future<String?> Function()? pickDirectory;
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
  String? _error;
  late GraphStorageMode _mode = widget.initialTarget.mode;
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
        await widget.saveTarget!(
          GraphStorageTarget(mode: _mode, localPath: _root.text.trim()),
        );
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
            items: const [
              DropdownMenuItem(
                value: GraphStorageMode.obsidian,
                child: Text('В vault Obsidian'),
              ),
              DropdownMenuItem(
                value: GraphStorageMode.local,
                child: Text('В папке Pulse на компьютере'),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _mode = value);
                  },
          ),
          const SizedBox(height: 12),
          if (_mode == GraphStorageMode.local) ...[
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
          onPressed: _saving ? null : _save,
          child: const Text('Сохранить папки'),
        ),
      ],
    ),
  );
}
