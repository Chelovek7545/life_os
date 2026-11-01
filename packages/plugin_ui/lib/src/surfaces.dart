part of '../plugin_ui.dart';

/// A module-owned destination in the application shell.
class PluginScreenContribution {
  const PluginScreenContribution({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.order = 0,
    this.ownsAppBar = false,
    this.resizeToAvoidBottomInset = true,
    this.onOpen,
  });
  final String id;
  final String label;
  final IconData icon;
  final int order;
  final bool ownsAppBar;
  final bool resizeToAvoidBottomInset;
  final Widget Function(BuildContext context, PluginScreenContext screen)
  builder;
  final void Function(Object? argument)? onOpen;
}

/// A module-owned panel placed in a named slot by its host screen.
class PluginPanelContribution {
  const PluginPanelContribution({
    required this.id,
    required this.slot,
    required this.builder,
    this.order = 0,
  });
  final String id;
  final String slot;
  final int order;
  final Widget Function(BuildContext context, PluginPanelContext panel) builder;
}

class PluginPanelContext {
  const PluginPanelContext({required this.expand, this.screen, this.isCurrent});
  final bool expand;
  final PluginScreenContext? screen;
  final bool Function()? isCurrent;
  bool get isActive => isCurrent?.call() ?? true;
}

/// A screen's navigation and layout controls bound to its registration.
class PluginScreenContext {
  PluginScreenContext._(this._navigation, this.id, this._key);
  final PluginNavigationController _navigation;
  final String id;
  final LocalKey _key;
  bool get isActive =>
      !_navigation._disposed &&
      _navigation.registry.contributionKey(id) == _key;
  bool openScreen(String id, {Object? argument}) =>
      isActive && _navigation.open(id, argument: argument);
  void setResizeToAvoidBottomInset(bool value) {
    if (isActive) _navigation._setInset(_key, value);
  }
}

/// Selects destinations by stable ID and reconciles removed registrations.
class PluginNavigationController extends ChangeNotifier {
  PluginNavigationController(this.registry) {
    registry.addListener(_reconcile);
    _reconcile();
  }
  final PluginUiRegistry registry;
  String? _selectedId;
  final Map<LocalKey, bool> _insets = {};
  bool _disposed = false;
  bool _insetNotificationPending = false;
  String? get selectedId => _selectedId;
  PluginScreenContribution? get selected {
    for (final screen in registry.screens) {
      if (screen.id == _selectedId) return screen;
    }
    return null;
  }

  bool get resizeToAvoidBottomInset {
    final screen = selected;
    if (screen == null) return true;
    return _insets[registry.contributionKey(screen.id)] ??
        screen.resizeToAvoidBottomInset;
  }

  PluginScreenContext contextFor(PluginScreenContribution screen) {
    final key = registry.contributionKey(screen.id);
    if (key == null || !registry.screens.contains(screen)) {
      throw StateError('Screen is no longer registered: ${screen.id}');
    }
    return PluginScreenContext._(this, screen.id, key);
  }

  bool open(String id, {Object? argument}) {
    if (_disposed) return false;
    final matches = registry.screens.where((screen) => screen.id == id);
    if (matches.isEmpty) return false;
    final screen = matches.single;
    final key = registry.contributionKey(id);
    screen.onOpen?.call(argument);
    if (_disposed || key != registry.contributionKey(id)) return false;
    _selectedId = id;
    notifyListeners();
    return true;
  }

  void _setInset(LocalKey key, bool value) {
    if (_insets[key] == value) return;
    _insets[key] = value;
    if (registry.contributionKey(_selectedId ?? '') != key ||
        _insetNotificationPending) {
      return;
    }
    _insetNotificationPending = true;
    scheduleMicrotask(() {
      _insetNotificationPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  void _reconcile() {
    final screens = registry.screens;
    if (!screens.any((screen) => screen.id == _selectedId)) {
      _selectedId = screens.isEmpty ? null : screens.first.id;
    }
    final keys = screens
        .map((screen) => registry.contributionKey(screen.id))
        .toSet();
    _insets.removeWhere((key, _) => !keys.contains(key));
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    registry.removeListener(_reconcile);
    _insets.clear();
    super.dispose();
  }
}

class PluginScreenScope extends InheritedWidget {
  const PluginScreenScope({
    super.key,
    required this.screen,
    required super.child,
  });
  final PluginScreenContext screen;
  static PluginScreenContext? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PluginScreenScope>()?.screen;
  @override
  bool updateShouldNotify(PluginScreenScope oldWidget) =>
      oldWidget.screen != screen;
}

/// Preserves screen state across selection, reordering and layout changes.
class PluginScreenDeck extends StatefulWidget {
  const PluginScreenDeck({super.key, required this.navigation});
  final PluginNavigationController navigation;
  @override
  State<PluginScreenDeck> createState() => _PluginScreenDeckState();
}

class _PluginScreenDeckState extends State<PluginScreenDeck>
    with SingleTickerProviderStateMixin {
  final Map<LocalKey, Widget> _pages = {};
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );
  String? _previousId;
  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.navigation,
    builder: (context, _) {
      final navigation = widget.navigation;
      final screens = navigation.registry.screens;
      final keys = screens
          .map((screen) => navigation.registry.contributionKey(screen.id)!)
          .toSet();
      _pages.removeWhere((key, _) => !keys.contains(key));
      if (_previousId != navigation.selectedId) {
        _previousId = navigation.selectedId;
        _fade.forward(from: 0);
      }
      if (screens.isEmpty) {
        return const Center(child: Text('Нет доступных экранов'));
      }
      return FadeTransition(
        opacity: _fade,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final screen in screens)
              Offstage(
                key: navigation.registry.contributionKey(screen.id),
                offstage: screen.id != navigation.selectedId,
                child: TickerMode(
                  enabled: screen.id == navigation.selectedId,
                  child: _pages.putIfAbsent(
                    navigation.registry.contributionKey(screen.id)!,
                    () {
                      final controls = navigation.contextFor(screen);
                      return PluginScreenScope(
                        screen: controls,
                        child: Builder(
                          builder: (context) =>
                              screen.builder(context, controls),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Builds the panels of a slot with registration-specific widget identities.
class PluginPanelSlot extends StatelessWidget {
  const PluginPanelSlot({
    super.key,
    required this.registry,
    required this.slot,
    this.expand = false,
    this.layout,
  });
  final PluginUiRegistry registry;
  final String slot;
  final bool expand;
  final Widget Function(BuildContext, List<Widget>)? layout;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: registry,
    builder: (context, _) {
      final screen = PluginScreenScope.maybeOf(context);
      final panels = [
        for (final panel in registry.panelsFor(slot))
          _panel(context, panel, screen),
      ];
      if (layout != null) return layout!(context, panels);
      return Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final panel in panels)
            if (expand) Expanded(key: panel.key, child: panel) else panel,
        ],
      );
    },
  );
  Widget _panel(
    BuildContext context,
    PluginPanelContribution panel,
    PluginScreenContext? screen,
  ) {
    final key = registry.contributionKey(panel.id);
    return KeyedSubtree(
      key: key,
      child: panel.builder(
        context,
        PluginPanelContext(
          expand: expand,
          screen: screen,
          isCurrent: () => registry.contributionKey(panel.id) == key,
        ),
      ),
    );
  }
}

/// A lifecycle marker for a set of UI contributions without its own service.
class UiModule implements AppPlugin {
  UiModule({required this.id, Set<String> dependencies = const {}})
    : dependencies = Set.unmodifiable(dependencies);
  @override
  final String id;
  @override
  final Set<String> dependencies;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

/// A set of UI contributions composed with the application's plugin host.
class UiModuleSpec {
  UiModuleSpec({
    required this.id,
    Set<String> dependencies = const {},
    Iterable<PluginScreenContribution> screens = const [],
    Iterable<PluginPanelContribution> panels = const [],
    Iterable<PluginActionContribution> actions = const [],
    Iterable<PluginSettingsContribution> settings = const [],
  }) : dependencies = Set.unmodifiable(dependencies),
       screens = List.unmodifiable(screens),
       panels = List.unmodifiable(panels),
       actions = List.unmodifiable(actions),
       settings = List.unmodifiable(settings);
  final String id;
  final Set<String> dependencies;
  final List<PluginScreenContribution> screens;
  final List<PluginPanelContribution> panels;
  final List<PluginActionContribution> actions;
  final List<PluginSettingsContribution> settings;
}
