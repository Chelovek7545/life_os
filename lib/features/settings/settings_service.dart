import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _blurKey = 'has_blur_enabled';
  
  // ValueNotifier хранит текущее значение и уведомляет служащие виджеты об изменении
  static final ValueNotifier<bool> hasBlur = ValueNotifier<bool>(true);

  // Инициализация при старте приложения
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Считываем сохранённое значение (по умолчанию true)
    hasBlur.value = prefs.getBool(_blurKey) ?? true;
  }

  // Метод для изменения и сохранения значения
  static Future<void> setHasBlur(bool value) async {
    hasBlur.value = value; // Уведомляет все ValueListenableBuilder
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blurKey, value); // Сохраняет на диск
  }
}