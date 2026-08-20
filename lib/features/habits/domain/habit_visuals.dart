import 'package:flutter/material.dart';

/// Доступные иконки привычек. Ключ хранится в БД.
const Map<String, IconData> kHabitIcons = {
  'task_alt': Icons.task_alt,
  'fitness_center': Icons.fitness_center,
  'directions_run': Icons.directions_run,
  'local_drink': Icons.local_drink,
  'restaurant': Icons.restaurant,
  'menu_book': Icons.menu_book,
  'self_improvement': Icons.self_improvement,
  'spa': Icons.spa,
  'bedtime': Icons.bedtime,
  'water_drop': Icons.water_drop,
  'medication': Icons.medication,
  'mood': Icons.mood,
  'school': Icons.school,
  'payments': Icons.payments,
};

/// Доступные цвета привычек (Hex).
const List<String> kHabitColors = [
  '#FF5C00',
  '#DCB8FF',
  '#4FC3F7',
  '#66BB6A',
  '#F06292',
  '#FFD54F',
  '#FF8A65',
  '#80CBC4',
];

IconData habitIconFor(String name) => kHabitIcons[name] ?? Icons.task_alt;

/// Парсит hex-строку "#RRGGBB" в [Color]. При ошибке возвращает оранжевый.
Color habitColorFor(String hex) {
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? const Color(0xFFFF5C00) : Color(parsed);
}
