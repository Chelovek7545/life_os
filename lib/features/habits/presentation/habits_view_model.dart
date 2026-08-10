import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:life_os/features/habits/data/habits_repository.dart';
import 'package:life_os/features/habits/domain/habit_entry_model.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_streak.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:rxdart/rxdart.dart';

class HabitsViewModel {
  HabitsViewModel(this._repository);

  final HabitsRepository _repository;

  final BehaviorSubject<HabitsScreenState> _uiStateController =
      BehaviorSubject<HabitsScreenState>.seeded(const HabitsLoading());
  Stream<HabitsScreenState> get state => _uiStateController.stream;

  final BehaviorSubject<DateTime> _selectedDateController =
      BehaviorSubject<DateTime>.seeded(DateTime.now());
  Stream<DateTime> get selectedDateStream => _selectedDateController.stream;
  DateTime get selectedDate => _selectedDateController.value;

  final BehaviorSubject<bool> _isFormVisibleController =
      BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isFormVisibleStream => _isFormVisibleController.stream;
  bool get isFormVisible => _isFormVisibleController.value;

  final HabitStreakCalculator _streakCalculator = const HabitStreakCalculator();

  Habit? editingHabit;
  Habit draft = Habit.create(title: '', type: const MorningHabit());

  StreamSubscription<dynamic>? _subscription;
  List<Habit> _habits = [];
  List<HabitEntry> _entries = [];

  void initialize() {
    _subscription?.cancel();
    _subscription =
        Rx.combineLatest2<List<Habit>, List<HabitEntry>, void>(
          _repository.watchActiveHabits(),
          _repository.watchAllEntries(),
          (habits, entries) {
            _habits = habits;
            _entries = entries;
            _emit();
          },
        ).listen(
          (_) {},
          onError: (Object error) {
            if (_uiStateController.isClosed) return;
            _uiStateController.add(HabitsError('Failed to load habits: $error'));
          },
        );
  }

  void selectDate(DateTime date) {
    if (_selectedDateController.isClosed) return;
    _selectedDateController.add(date);
    _emit();
  }

  void showForm() {
    if (_isFormVisibleController.isClosed) return;
    _isFormVisibleController.add(true);
  }

  void hideForm() {
    if (_isFormVisibleController.isClosed) return;
    _isFormVisibleController.add(false);
    editingHabit = null;
    draft = Habit.create(title: '', type: const MorningHabit());
  }

  void startEditing(Habit habit) {
    editingHabit = habit;
    draft = habit;
    showForm();
  }

  Future<void> saveDraft(Habit habit) async {
    if (editingHabit != null) {
      await _repository.updateHabit(habit.copyWith(updatedAt: DateTime.now()));
    } else {
      await _repository.addHabit(habit.copyWith(createdAt: DateTime.now()));
    }
    hideForm();
  }

  Future<void> deleteEditingHabit() async {
    final id = editingHabit?.id;
    if (id == null) return;
    await _repository.deleteHabit(id);
    hideForm();
  }

  Future<void> toggleHabit(Habit habit, DateTime date) async {
    final key = formatDateKey(date);
    final entry = _findEntry(habit.id, date);
    final nextStatus = entry?.status == HabitEntryStatus.completed
        ? HabitEntryStatus.pending
        : HabitEntryStatus.completed;
    _applyEntryLocally(habit.id, key, nextStatus);
    try {
      await _repository.setEntryStatus(habit.id, key, nextStatus);
    } on Exception {
      _applyEntryLocally(
        habit.id,
        key,
        entry?.status ?? HabitEntryStatus.pending,
      );
      rethrow;
    }
  }

  Future<void> skipHabit(Habit habit, DateTime date) async {
    final key = formatDateKey(date);
    final entry = _findEntry(habit.id, date);
    final nextStatus = entry?.status == HabitEntryStatus.skipped
        ? HabitEntryStatus.pending
        : HabitEntryStatus.skipped;
    _applyEntryLocally(habit.id, key, nextStatus);
    try {
      await _repository.setEntryStatus(habit.id, key, nextStatus);
    } on Exception {
      _applyEntryLocally(
        habit.id,
        key,
        entry?.status ?? HabitEntryStatus.pending,
      );
      rethrow;
    }
  }

  /// Оптимистично обновляет запись в локальном состоянии, чтобы UI
  /// откликнулся мгновенно; реальная запись в БД идёт следом через стрим.
  void _applyEntryLocally(
    String habitId,
    String dateKey,
    HabitEntryStatus status,
  ) {
    debugPrint('DBG apply: closed=${_uiStateController.isClosed} '
        'entries=${_entries.length}');
    if (_uiStateController.isClosed) return;
    final existing = _findEntryByKey(habitId, dateKey);
    if (existing != null) {
      _entries = [
        for (final e in _entries)
          if (e.habitId == habitId && e.dateKey == dateKey)
            e.copyWith(
              status: status,
              clearCompletedAt: status != HabitEntryStatus.completed,
            )
          else
            e,
      ];
    } else {
      _entries = [
        ..._entries,
        HabitEntry.create(habitId: habitId, dateKey: dateKey, status: status),
      ];
    }
    _emit();
  }

  HabitEntry? _findEntry(String habitId, DateTime date) =>
      _findEntryByKey(habitId, formatDateKey(date));

  HabitEntry? _findEntryByKey(String habitId, String dateKey) {
    for (final entry in _entries) {
      if (entry.habitId == habitId && entry.dateKey == dateKey) return entry;
    }
    return null;
  }

  void _emit() {
    if (_uiStateController.isClosed) return;
    debugPrint('DBG emit: closed=${_uiStateController.isClosed} '
        'listeners=${_uiStateController.hasListener}');
    final date = _selectedDateController.value;

    try {
      final items = _habits.map((habit) {
        final isExpired = !habit.schedule.isActiveOn(
          date,
          createdAt: habit.createdAt,
        );
        final isScheduled = habit.schedule.isScheduledOn(date);
        return HabitWithEntry(
          habit: habit,
          entry: _findEntry(habit.id, date),
          streak: _streakCalculator.calculate(
            habit: habit,
            entries: _entries,
          ),
          isScheduled: isScheduled,
          isExpired: isExpired,
        );
      }).toList();

      _uiStateController.add(HabitsLoaded(habits: items));
    } catch (e, st) {
      debugPrint('DBG emit THREW: $e\n$st');
      rethrow;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _uiStateController.close();
    _selectedDateController.close();
    _isFormVisibleController.close();
  }
}
