import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_plugin/telegram_plugin.dart'
    show BotTaskEdit, BotTaskEditField;
import 'package:life_os/core/database/database.dart';
import 'package:core_contracts/core_contracts.dart' show Wrapped;
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:tasks_api/tasks_api.dart' show Tag, Task, TaskStatus;

void main() {
  final now = DateTime(2026, 10, 30, 12);
  Task task() => Task(
    id: 'task-1',
    title: 'Старая задача',
    description: 'Исходное описание',
    status: TaskStatus.notStarted,
    createdAt: now,
    updatedAt: now,
    dueDate: DateTime(2026, 10, 30),
    spaceId: 'space-1',
    priority: 2,
    timerSeconds: 25,
    effortWeight: 1,
    tags: const [Tag(id: 1, name: 'учёба', colorHex: 0xFF9E9E9E)],
  );

  test(
    'validates dates and clears optional fields without changing others',
    () {
      final original = task();
      expect(
        BotTaskEdit.applyText(
          original,
          BotTaskEditField.dueDate,
          '31.02.2026',
          now,
        ),
        isNull,
      );
      final withoutDue = BotTaskEdit.applyText(
        original,
        BotTaskEditField.dueDate,
        'без срока',
        now,
      )!;
      expect(withoutDue.dueDate, isNull);
      expect(withoutDue.priority, 2);
      expect(withoutDue.spaceId, 'space-1');
      expect(withoutDue.tags, original.tags);
      expect(
        BotTaskEdit.applyText(
          original,
          BotTaskEditField.dueDate,
          'завтра',
          now,
        )!.dueDate,
        DateTime(2026, 10, 31),
      );
    },
  );

  test('resolves project only with a matching project ID', () {
    final original = task();
    expect(
      BotTaskEdit.applyText(original, BotTaskEditField.project, 'Учёба', now),
      isNull,
    );
    expect(
      BotTaskEdit.applyText(
        original,
        BotTaskEditField.project,
        'Учёба',
        now,
        projectId: 'project-1',
      )!.projectId,
      'project-1',
    );
    expect(
      BotTaskEdit.applyText(
        original,
        BotTaskEditField.description,
        'пусто',
        now,
      )!.description,
      isEmpty,
    );
  });

  test('moving a planned task keeps its time and duration', () {
    final original = task().copyWith(
      startsAt: Wrapped(DateTime(2026, 10, 30, 14, 30)),
      endsAt: Wrapped(DateTime(2026, 10, 30, 15, 30)),
    );
    final moved = BotTaskEdit.applyText(
      original,
      BotTaskEditField.scheduledAt,
      '31.10.2026',
      now,
    )!;
    expect(moved.startsAt, DateTime(2026, 10, 31, 14, 30));
    expect(moved.endsAt, DateTime(2026, 10, 31, 15, 30));
    final cleared = BotTaskEdit.applyText(
      moved,
      BotTaskEditField.scheduledAt,
      'без плана',
      now,
    )!;
    expect(cleared.startsAt, isNull);
    expect(cleared.endsAt, isNull);
  });

  test(
    'application repository update preserves tags, priority and space',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TasksRepository(TasksDao(db));
      await repository.addTask(task());

      final loaded = (await repository.getAllTasks()).single;
      final edited = BotTaskEdit.applyText(
        loaded,
        BotTaskEditField.title,
        'Новое название',
        now,
      )!;
      await repository.updateTask(
        edited.copyWith(updatedAt: now.add(const Duration(minutes: 1))),
      );

      final saved = (await repository.getAllTasks()).single;
      expect(saved.title, 'Новое название');
      expect(saved.description, 'Исходное описание');
      expect(saved.tags.single.name, 'учёба');
      expect(saved.priority, 2);
      expect(saved.spaceId, 'space-1');
      expect(saved.timerSeconds, 25);
    },
  );
}
