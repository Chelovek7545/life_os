import 'package:uuid/uuid.dart';

/// Статус выполнения привычки за конкретный день.
enum HabitEntryStatus {
  /// Ещё не выполнена.
  pending,

  /// Выполнена.
  completed,

  /// Осознанно пропущена (не ломает серию).
  skipped,
}

/// Форматирует дату в ключ дня "YYYY-MM-DD".
String formatDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Запись о выполнении привычки за конкретный день.
class HabitEntry {
  const HabitEntry({
    required this.id,
    required this.habitId,
    required this.dateKey,
    required this.status,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String habitId;
  final String dateKey;
  final HabitEntryStatus status;
  final DateTime? completedAt;
  final DateTime createdAt;

  DateTime get date => DateTime.parse(dateKey);

  factory HabitEntry.create({
    required String habitId,
    required String dateKey,
    HabitEntryStatus status = HabitEntryStatus.pending,
  }) {
    final now = DateTime.now();
    return HabitEntry(
      id: const Uuid().v4(),
      habitId: habitId,
      dateKey: dateKey,
      status: status,
      completedAt: status == HabitEntryStatus.completed ? now : null,
      createdAt: now,
    );
  }

  HabitEntry copyWith({
    HabitEntryStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return HabitEntry(
      id: id,
      habitId: habitId,
      dateKey: dateKey,
      status: status ?? this.status,
      completedAt: clearCompletedAt
          ? null
          : (completedAt ?? this.completedAt),
      createdAt: createdAt,
    );
  }
}
