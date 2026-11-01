import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
part 'src/surfaces.dart';

enum PluginActionLocation { appBar, navigationRail }

class PluginActionContribution {
  PluginActionContribution({
    required this.id,
    required Set<PluginActionLocation> locations,
    required this.builder,
  }) : locations = Set.unmodifiable(locations);
  final String id;
  final Set<PluginActionLocation> locations;
  final Widget Function(BuildContext context, bool compact) builder;
}

class PluginSettingsContribution {
  const PluginSettingsContribution({
    required this.id,
    required this.title,
    required this.builder,
  });
  final String id;
  final String title;
  final WidgetBuilder builder;
}

class PluginNotice {
  const PluginNotice(this.message, {this.isError = false});
  final String message;
  final bool isError;
}

class PluginUiRegistry extends ChangeNotifier {
  final Map<String, List<PluginActionContribution>> _actions = {};
  final Map<String, List<PluginSettingsContribution>> _settings = {};
  final Map<String, List<PluginScreenContribution>> _screens = {};
  final Map<String, List<PluginPanelContribution>> _panels = {};
  final Map<String, Object> _owners = {};
  final _notices = StreamController<PluginNotice>.broadcast();
  bool _disposed = false;
  Stream<PluginNotice> get notices => _notices.stream;
  List<PluginSettingsContribution> get settings =>
      List.unmodifiable(_settings.values.expand((items) => items));
  List<PluginActionContribution> actionsFor(PluginActionLocation location) =>
      List.unmodifiable(
        _actions.values
            .expand((items) => items)
            .where((action) => action.locations.contains(location)),
      );

  List<PluginScreenContribution> get screens => _ordered(
    _screens.values.expand((items) => items),
    (screen) => screen.order,
  );
  List<PluginPanelContribution> panelsFor(String slot) => _ordered(
    _panels.values
        .expand((items) => items)
        .where((panel) => panel.slot == slot),
    (panel) => panel.order,
  );
  List<T> _ordered<T>(Iterable<T> values, int Function(T) order) {
    final indexed = values.toList().asMap().entries.toList()
      ..sort((a, b) {
        final result = order(a.value).compareTo(order(b.value));
        return result != 0 ? result : a.key.compareTo(b.key);
      });
    return List.unmodifiable(indexed.map((entry) => entry.value));
  }

  LocalKey? contributionKey(String id) {
    for (final owner in _owners.keys) {
      if ((_screens[owner] ?? const []).any((item) => item.id == id) ||
          (_panels[owner] ?? const []).any((item) => item.id == id)) {
        return ValueKey((_owners[owner], id));
      }
    }
    return null;
  }

  void register(
    String owner, {
    List<PluginActionContribution> actions = const [],
    List<PluginSettingsContribution> settings = const [],
    List<PluginScreenContribution> screens = const [],
    List<PluginPanelContribution> panels = const [],
  }) {
    if (_disposed) throw StateError('UI registry is disposed.');
    if (_owners.containsKey(owner)) {
      throw ArgumentError('Plugin UI is already registered: $owner');
    }
    final ids = <String>{
      ..._actions.values.expand((items) => items).map((item) => item.id),
      ..._settings.values.expand((items) => items).map((item) => item.id),
      ..._screens.values.expand((items) => items).map((item) => item.id),
      ..._panels.values.expand((items) => items).map((item) => item.id),
    };
    for (final id in [
      ...actions.map((item) => item.id),
      ...settings.map((item) => item.id),
      ...screens.map((item) => item.id),
      ...panels.map((item) => item.id),
    ]) {
      if (!ids.add(id)) throw ArgumentError('Duplicate UI contribution: $id');
    }
    _actions[owner] = List.unmodifiable(actions);
    _settings[owner] = List.unmodifiable(settings);
    _screens[owner] = List.unmodifiable(screens);
    _panels[owner] = List.unmodifiable(panels);
    _owners[owner] = Object();
    notifyListeners();
  }

  void unregister(String owner) {
    final existed = _owners.remove(owner) != null;
    _actions.remove(owner);
    _settings.remove(owner);
    _screens.remove(owner);
    _panels.remove(owner);
    if (existed && !_disposed) notifyListeners();
  }

  void notify(PluginNotice notice) {
    if (!_disposed) _notices.add(notice);
  }

  @override
  void dispose() {
    _disposed = true;
    _owners.clear();
    _actions.clear();
    _settings.clear();
    _screens.clear();
    _panels.clear();
    notifyListeners();
    unawaited(_notices.close());
    super.dispose();
  }
}

class UiPluginRegistration implements AppPlugin {
  UiPluginRegistration({
    required this.plugin,
    required this.registry,
    List<PluginActionContribution> actions = const [],
    List<PluginSettingsContribution> settings = const [],
    List<PluginScreenContribution> screens = const [],
    List<PluginPanelContribution> panels = const [],
  }) : actions = List.unmodifiable(actions),
       settings = List.unmodifiable(settings),
       screens = List.unmodifiable(screens),
       panels = List.unmodifiable(panels);
  final AppPlugin plugin;
  final PluginUiRegistry registry;
  final List<PluginActionContribution> actions;
  final List<PluginSettingsContribution> settings;
  final List<PluginScreenContribution> screens;
  final List<PluginPanelContribution> panels;
  bool _registered = false;
  @override
  String get id => plugin.id;
  @override
  Set<String> get dependencies => plugin.dependencies;
  @override
  Future<void> start() async {
    await plugin.start();
    registry.register(
      id,
      actions: actions,
      settings: settings,
      screens: screens,
      panels: panels,
    );
    _registered = true;
  }

  @override
  Future<void> stop() async {
    try {
      if (_registered) registry.unregister(id);
    } finally {
      _registered = false;
      await plugin.stop();
    }
  }
}

class PluginUiScope extends InheritedNotifier<PluginUiRegistry> {
  const PluginUiScope({
    super.key,
    required PluginUiRegistry registry,
    required super.child,
  }) : super(notifier: registry);
  static PluginUiRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PluginUiScope>()?.notifier;
}

class PluginActions extends StatelessWidget {
  const PluginActions({
    super.key,
    required this.registry,
    required this.location,
    this.compact = false,
  });
  final PluginUiRegistry registry;
  final PluginActionLocation location;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: registry,
    builder: (context, _) {
      final actions = registry.actionsFor(location);
      if (actions.isEmpty) return const SizedBox.shrink();
      final children = [
        for (final action in actions)
          KeyedSubtree(
            key: ValueKey(action.id),
            child: action.builder(context, compact),
          ),
      ];
      return location == PluginActionLocation.navigationRail
          ? Column(mainAxisSize: MainAxisSize.min, children: children)
          : Row(mainAxisSize: MainAxisSize.min, children: children);
    },
  );
}

class PluginTextSetting extends StatelessWidget {
  const PluginTextSetting({
    super.key,
    required this.value,
    required this.title,
    required this.icon,
    required this.save,
    this.emptyLabel = 'Не указан',
    this.obscure = false,
    this.validate,
  });
  final ValueListenable<String> value;
  final String title;
  final IconData icon;
  final Future<void> Function(String text) save;
  final String emptyLabel;
  final bool obscure;
  final String? Function(String text)? validate;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: value,
    builder: (context, current, _) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        current.isEmpty
            ? emptyLabel
            : obscure
            ? 'Указан'
            : current,
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _SettingEditor(
          title: title,
          value: current,
          save: save,
          obscure: obscure,
          validate: validate,
        ),
      ),
    ),
  );
}

class _SettingEditor extends StatefulWidget {
  const _SettingEditor({
    required this.title,
    required this.value,
    required this.save,
    required this.obscure,
    this.validate,
  });
  final String title;
  final String value;
  final Future<void> Function(String) save;
  final bool obscure;
  final String? Function(String)? validate;
  @override
  State<_SettingEditor> createState() => _SettingEditorState();
}

class _SettingEditorState extends State<_SettingEditor> {
  late final _controller = TextEditingController(text: widget.value);
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    final value = _controller.text.trim();
    final validation = widget.validate?.call(value);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(value);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = error.toString();
        });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      obscureText: widget.obscure,
      enabled: !_saving,
      decoration: InputDecoration(errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Сохранить'),
      ),
    ],
  );
}
