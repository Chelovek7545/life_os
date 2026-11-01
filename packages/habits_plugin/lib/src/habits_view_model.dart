import 'dart:async';
import 'package:habits_api/habits_api.dart';
import 'package:rxdart/rxdart.dart';
import 'habits_state.dart';

class HabitsViewModel {
  HabitsViewModel(this._repository);
  final HabitsApi _repository;
  final _states = BehaviorSubject<HabitsScreenState>.seeded(
    const HabitsLoading(),
  );
  final _dates = BehaviorSubject<DateTime>.seeded(DateTime.now());
  final _forms = BehaviorSubject<bool>.seeded(false);
  final _streaks = const HabitStreakCalculator();
  Stream<HabitsScreenState> get state => _states.stream;
  Stream<DateTime> get selectedDateStream => _dates.stream;
  DateTime get selectedDate => _dates.value;
  Stream<bool> get isFormVisibleStream => _forms.stream;
  bool get isFormVisible => _forms.value;

  Habit? editingHabit;
  Habit draft = Habit.create(title: '', type: const MorningHabit());
  StreamSubscription<void>? _subscription;
  List<Habit> _habits = const [];
  List<HabitEntry> _entries = const [];
  final _pending = <(String, String), List<_EntryEdit>>{};
  bool _initialized = false;
  bool _accepting = true;
  bool _disposed = false;
  Future<void> _operations = Future.value();
  Future<void>? _closing;

  void initialize() {
    _requireActive();
    if (_initialized) return;
    _initialized = true;
    _subscription =
        Rx.combineLatest2<List<Habit>, List<HabitEntry>, void>(
          _repository.watchActiveHabits(),
          _repository.watchAllEntries(),
          (habits, entries) {
            if (_disposed) return;
            _habits = List.unmodifiable(habits);
            _entries = List.unmodifiable(entries);
            _emit();
          },
        ).listen(
          (_) {},
          onError: (Object error) {
            if (!_disposed) {
              _states.add(HabitsError('Failed to load habits: $error'));
            }
          },
        );
  }

  void _requireActive() {
    if (!_accepting) throw StateError('Habits view model is closed.');
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (!_accepting) {
      return Future.error(StateError('Habits view model is closed.'));
    }
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void selectDate(DateTime date) {
    if (!_accepting) return;
    _dates.add(date);
    _emit();
  }

  void showForm() {
    if (_accepting) _forms.add(true);
  }

  void hideForm() {
    if (!_accepting) return;
    _forms.add(false);
    editingHabit = null;
    draft = Habit.create(title: '', type: const MorningHabit());
  }

  void startEditing(Habit habit) {
    if (!_accepting) return;
    editingHabit = habit;
    draft = habit;
    showForm();
  }

  Future<void> saveDraft(Habit habit) {
    final isEditing = editingHabit != null;
    return _enqueue(() async {
      if (isEditing) {
        await _repository.updateHabit(
          habit.copyWith(updatedAt: DateTime.now()),
        );
      } else {
        await _repository.addHabit(habit.copyWith(createdAt: DateTime.now()));
      }
      hideForm();
    });
  }

  Future<void> deleteEditingHabit() {
    final id = editingHabit?.id;
    return _enqueue(() async {
      if (id == null) return;
      await _repository.deleteHabit(id);
      hideForm();
    });
  }

  Future<void> toggleHabit(Habit habit, DateTime date) =>
      _changeEntry(habit, date, HabitEntryStatus.completed);
  Future<void> skipHabit(Habit habit, DateTime date) =>
      _changeEntry(habit, date, HabitEntryStatus.skipped);

  Future<void> _changeEntry(
    Habit habit,
    DateTime date,
    HabitEntryStatus requested,
  ) {
    if (!_accepting) {
      return Future.error(StateError('Habits view model is closed.'));
    }
    final key = (habit.id, formatDateKey(date));
    final current = _findEntry(_effectiveEntries, key);
    final status = current?.status == requested
        ? HabitEntryStatus.pending
        : requested;
    final edit = _EntryEdit(
      current?.copyWith(
            status: status,
            completedAt: status == HabitEntryStatus.completed
                ? DateTime.now()
                : null,
            clearCompletedAt: status != HabitEntryStatus.completed,
          ) ??
          HabitEntry.create(habitId: key.$1, dateKey: key.$2, status: status),
    );
    (_pending[key] ??= []).add(edit);
    _emit();
    return _enqueue(() async {
      try {
        await _repository.setEntryStatus(key.$1, key.$2, status);
        final stored = _findEntry(_entries, key);
        _entries = _replaceEntry(
          _entries,
          stored?.copyWith(
                status: status,
                completedAt: stored.status == status
                    ? stored.completedAt
                    : edit.entry.completedAt,
                clearCompletedAt: status != HabitEntryStatus.completed,
              ) ??
              edit.entry,
        );
      } finally {
        // Remove only this operation. A newer optimistic action must survive
        // an earlier write failure or an unrelated source notification.
        final edits = _pending[key]!;
        edits.remove(edit);
        if (edits.isEmpty) _pending.remove(key);
        _emit();
      }
    });
  }

  List<HabitEntry> get _effectiveEntries {
    var result = _entries;
    for (final edits in _pending.values) {
      result = _replaceEntry(result, edits.last.entry);
    }
    return result;
  }

  List<HabitEntry> _replaceEntry(List<HabitEntry> entries, HabitEntry entry) =>
      [
        for (final old in entries)
          if (old.habitId != entry.habitId || old.dateKey != entry.dateKey) old,
        entry,
      ];

  HabitEntry? _findEntry(List<HabitEntry> entries, (String, String) key) {
    for (final entry in entries) {
      if (entry.habitId == key.$1 && entry.dateKey == key.$2) return entry;
    }
    return null;
  }

  Set<String> completedDateKeysOf(String habitId) => {
    for (final entry in _effectiveEntries)
      if (entry.habitId == habitId &&
          entry.status == HabitEntryStatus.completed)
        entry.dateKey,
  };

  void _emit() {
    if (_disposed) return;
    final date = selectedDate;
    final entries = _effectiveEntries;
    _states.add(
      HabitsLoaded(
        habits: [
          for (final habit in _habits)
            HabitWithEntry(
              habit: habit,
              entry: _findEntry(entries, (habit.id, formatDateKey(date))),
              streak: _streaks.calculate(habit: habit, entries: entries),
              isScheduled: habit.schedule.isScheduledOn(date),
              isExpired: !habit.schedule.isActiveOn(
                date,
                createdAt: habit.createdAt,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> dispose() => _closing ??= _dispose();
  Future<void> _dispose() async {
    _accepting = false;
    await _operations;
    try {
      await _subscription?.cancel();
    } finally {
      _disposed = true;
      await Future.wait([_states.close(), _dates.close(), _forms.close()]);
    }
  }
}

class _EntryEdit {
  _EntryEdit(this.entry);
  final HabitEntry entry;
}
