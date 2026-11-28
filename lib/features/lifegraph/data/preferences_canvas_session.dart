import 'package:notes_api/notes_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PreferencesCanvasSession implements CanvasBoardSession {
  PreferencesCanvasSession._(this._preferences, this._id);

  static const _prefix = 'lifegraph.canvas.v1.';
  final SharedPreferences _preferences;
  final String _id;
  String get _key => '$_prefix$_id';

  static Future<List<String>> listIds() async {
    final preferences = await SharedPreferences.getInstance();
    return [
      for (final key in preferences.getKeys())
        if (key.startsWith(_prefix)) key.substring(_prefix.length),
    ];
  }

  static Future<PreferencesCanvasSession> open(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Неверный ID канваса.');
    }
    return PreferencesCanvasSession._(
      await SharedPreferences.getInstance(),
      id,
    );
  }

  @override
  String get path => '$_id.canvas';

  @override
  String notePath(String absolutePath) =>
      throw ArgumentError('Для канваса не выбрана папка.');

  @override
  String resolveNote(String relativePath) =>
      throw ArgumentError('Для канваса не выбрана папка.');

  @override
  Future<String?> read() async => _preferences.getString(_key);

  @override
  Future<void> write(
    String content, {
    required String? expected,
    bool backupPrevious = false,
  }) async {
    final previous = _preferences.getString(_key);
    if (previous != expected) {
      final recovery = 'lifegraph.canvas.recovery.${const Uuid().v4()}';
      await _preferences.setString(recovery, content);
      throw CanvasBoardConflict(recovery);
    }
    if (content != previous && !await _preferences.setString(_key, content)) {
      throw StateError('Не удалось сохранить канвас.');
    }
  }
}
