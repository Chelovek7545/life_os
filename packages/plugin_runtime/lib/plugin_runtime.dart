enum PluginState { inactive, starting, active, stopping, failed }

abstract interface class AppPlugin {
  String get id;
  Set<String> get dependencies;
  Future<void> start();
  Future<void> stop();
}

class PluginLifecycleException implements Exception {
  PluginLifecycleException(this.failures);
  final Map<String, Object> failures;
  @override
  String toString() => 'Plugin lifecycle failed: ${failures.keys.join(', ')}';
}

class PluginHost {
  PluginHost(Iterable<AppPlugin> plugins) {
    final registry = <String, AppPlugin>{};
    for (final plugin in plugins) {
      if (registry.containsKey(plugin.id)) {
        throw ArgumentError('Duplicate plugin: ${plugin.id}');
      }
      registry[plugin.id] = plugin;
    }
    final visiting = <String>{};
    final visited = <String>{};
    void visit(String id) {
      if (visited.contains(id)) return;
      final plugin = registry[id];
      if (plugin == null) throw ArgumentError('Missing plugin dependency: $id');
      if (!visiting.add(id))
        throw ArgumentError('Plugin dependency cycle: $id');
      for (final dependency in plugin.dependencies) {
        visit(dependency);
      }
      visiting.remove(id);
      visited.add(id);
      _ordered.add(plugin);
      _states[id] = PluginState.inactive;
    }

    for (final id in registry.keys) {
      visit(id);
    }
  }

  final List<AppPlugin> _ordered = [];
  final List<AppPlugin> _needsStop = [];
  final Map<String, PluginState> _states = {};
  Future<void> _pending = Future.value();
  Map<String, PluginState> get states => Map.unmodifiable(_states);

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> start() => _enqueue(() async {
    if (_states.values.every((state) => state == PluginState.active)) return;
    if (_needsStop.isNotEmpty) {
      throw StateError('Stop failed plugins before starting again.');
    }
    for (final plugin in _ordered) {
      _states[plugin.id] = PluginState.starting;
      _needsStop.add(plugin);
      try {
        await plugin.start();
        _states[plugin.id] = PluginState.active;
      } catch (error, stack) {
        final failures = <String, Object>{plugin.id: error};
        failures.addAll(await _stopAll());
        _states[plugin.id] = PluginState.failed;
        Error.throwWithStackTrace(PluginLifecycleException(failures), stack);
      }
    }
  });

  Future<void> stop() => _enqueue(() async {
    final failures = await _stopAll();
    if (failures.isNotEmpty) throw PluginLifecycleException(failures);
  });

  Future<Map<String, Object>> _stopAll() async {
    final failures = <String, Object>{};
    for (final plugin in _needsStop.reversed.toList()) {
      _states[plugin.id] = PluginState.stopping;
      try {
        await plugin.stop();
        _needsStop.remove(plugin);
        _states[plugin.id] = PluginState.inactive;
      } catch (error) {
        _states[plugin.id] = PluginState.failed;
        failures[plugin.id] = error;
      }
    }
    return failures;
  }
}
