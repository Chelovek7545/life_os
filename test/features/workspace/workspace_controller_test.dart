import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/workspace/workspace_controller.dart';
import 'package:life_os/features/workspace/workspace_layout.dart';

void main() {
  test(
    'project date ranges persist, isolate panes and preserve project selections',
    () async {
      String? saved;
      final controller = WorkspaceController(
        editorIds: const {'tasks', 'calendar', 'projectTasks'},
        save: (value) async {
          saved = value;
        },
        onSaveError: (_, _) {},
      )..setEditing(true);
      final id = controller.selectedId;
      controller.changeEditor(id, 'projectTasks');
      controller.selectProjectTaskDates(
        id,
        DateTime(2026, 11, 14, 23),
        DateTime(2026, 11, 16, 7),
      );
      controller.selectProjects(id, ['a'], false);
      controller.split(id, WorkspaceAxis.vertical);
      final other = controller.selectedId;
      controller.setEditing(false);
      controller.selectProjectTaskDates(
        other,
        DateTime(2026, 12, 1),
        DateTime(2026, 12, 1),
      );
      final before = controller.layout.encode();
      controller.selectProjectTaskDates(
        id,
        DateTime(2026, 11, 20),
        DateTime(2026, 11, 19),
      );
      controller.selectProjectTaskDates(id, null, DateTime(2026, 11, 19));
      expect(controller.layout.encode(), before);
      controller.setEditing(true);
      controller.changeEditor(id, 'calendar');
      controller.changeEditor(id, 'projectTasks');
      await controller.flush();
      final layout = WorkspaceLayout.decode(saved!, controller.editorIds)!;
      final pane = layout.root.find(id) as WorkspacePane;
      expect(pane.projectIds, ['a']);
      expect(pane.showUnassigned, isFalse);
      expect(pane.dateFrom, DateTime(2026, 11, 14));
      expect(pane.dateTo, DateTime(2026, 11, 16));
      expect(
        (layout.root.find(other) as WorkspacePane).dateFrom,
        DateTime(2026, 12, 1),
      );
      controller.selectProjectTaskDates(id, null, null);
      expect(
        (controller.layout.root.find(id) as WorkspacePane).dateFrom,
        isNull,
      );
      await controller.close();
      final closed = controller.layout.encode();
      controller.selectProjectTaskDates(id, DateTime(2026), DateTime(2026));
      expect(controller.layout.encode(), closed);
      controller.dispose();
    },
  );

  test(
    'project selections persist independently and survive editor changes',
    () async {
      final writes = <String>[];
      final controller = WorkspaceController(
        editorIds: const {'tasks', 'calendar', 'projectTasks'},
        save: (value) async {
          writes.add(value);
        },
        onSaveError: (_, _) {},
      )..setEditing(true);
      final id = controller.selectedId;
      controller.changeEditor(id, 'projectTasks');
      controller.selectProjects(id, ['project-a'], false);
      controller.split(id, WorkspaceAxis.vertical);
      final otherId = controller.selectedId;
      controller.setEditing(false);
      controller.selectProjects(otherId, [], true);
      expect((controller.layout.root.find(id) as WorkspacePane).projectIds, [
        'project-a',
      ]);
      expect(
        (controller.layout.root.find(otherId) as WorkspacePane).projectIds,
        isEmpty,
      );
      controller.setEditing(true);
      controller.changeEditor(id, 'tasks');
      controller.changeEditor(id, 'projectTasks');
      await controller.flush();
      final restored = WorkspaceLayout.decode(
        writes.last,
        controller.editorIds,
      )!;
      final pane = restored.root.find(id) as WorkspacePane;
      expect(pane.projectIds, ['project-a']);
      expect(pane.showUnassigned, isFalse);
      expect(
        (restored.root.find(otherId) as WorkspacePane).showUnassigned,
        isTrue,
      );
      controller.selectProjects(id, null, true);
      await controller.close();
      final before = controller.layout.encode();
      controller.selectProjects(id, [], false);
      expect(controller.layout.encode(), before);
      expect(
        (controller.layout.root.find(id) as WorkspacePane).projectIds,
        isNull,
      );
      controller.dispose();
    },
  );

  test(
    'old layouts use all projects and malformed selections are rejected',
    () {
      const editors = {'tasks'};
      WorkspaceLayout? decode(String options) => WorkspaceLayout.decode(
        '{"version":1,"root":{"id":"pane","editor":"tasks"$options}}',
        editors,
      );
      final pane = decode('')!.root as WorkspacePane;
      expect(pane.projectIds, isNull);
      expect(pane.showUnassigned, isTrue);
      expect(pane.dateFrom, isNull);
      expect(pane.dateTo, isNull);
      for (final options in [
        ',"projectIds":42',
        ',"projectIds":[1]',
        ',"projectIds":[""]',
        ',"showUnassigned":"true"',
        ',"dateFrom":"2026-11-14"',
        ',"dateTo":"2026-11-14"',
        ',"dateFrom":"2026-11-15","dateTo":"2026-11-14"',
        ',"dateFrom":14,"dateTo":"2026-11-14"',
        ',"dateFrom":"2026-02-31","dateTo":"2026-03-04"',
      ]) {
        expect(decode(options), isNull);
      }
    },
  );

  WorkspaceController create({Future<void> Function(String)? save}) =>
      WorkspaceController(
        editorIds: const {'tasks', 'calendar'},
        save: save ?? (_) async {},
        onSaveError: (_, _) {},
      )..setEditing(true);

  test(
    'structure changes require edit mode but resizing remains available',
    () async {
      final writes = <String>[];
      final controller = create(
        save: (value) async {
          writes.add(value);
        },
      );
      final root = controller.layout.root as WorkspaceSplit;
      controller.toggleMaximize(root.first.id);
      controller.setEditing(false);
      expect(controller.maximizedId, isNull);
      final before = controller.layout.encode();
      controller.split(root.first.id, WorkspaceAxis.vertical);
      controller.changeEditor(root.first.id, 'calendar');
      controller.closePane(root.first.id);
      controller.toggleMaximize(root.first.id);
      expect(controller.layout.encode(), before);
      expect(controller.maximizedId, isNull);
      await controller.flush();
      expect(writes, isEmpty);
      controller.resize(root, .7);
      expect((controller.layout.root as WorkspaceSplit).ratio, .7);
      controller.setEditing(true);
      controller.split(root.first.id, WorkspaceAxis.vertical);
      expect(controller.layout.root.panes.length, 3);
      await controller.close();
      controller.dispose();
    },
  );

  test(
    'nested split and close preserve remaining identities and contents',
    () async {
      final controller = create();
      final original = controller.layout.root.panes.toList();
      controller.split(original.first.id, WorkspaceAxis.vertical);
      final added = controller.selectedId;
      controller.changeEditor(added, 'calendar');
      expect(controller.layout.root.panes.length, 3);
      controller.toggleMaximize(added);
      controller.closePane(added);
      expect(controller.maximizedId, isNull);
      expect(
        controller.layout.root.panes.map((pane) => pane.id),
        original.map((pane) => pane.id),
      );
      controller.closePane(original.first.id);
      controller.closePane(original.last.id);
      expect(controller.layout.root.panes.single.id, original.last.id);
      expect(controller.selectedId, original.last.id);
      await controller.close();
      controller.dispose();
    },
  );

  test(
    'flush saves latest content and proportions and close revokes callbacks',
    () async {
      final writes = <String>[];
      final controller = create(
        save: (value) async {
          writes.add(value);
        },
      );
      final split = controller.layout.root as WorkspaceSplit;
      controller.resize(split, .65);
      controller.changeEditor(split.first.id, 'calendar');
      await controller.close();
      expect(writes, hasLength(1));
      final restored = WorkspaceLayout.decode(
        writes.single,
        controller.editorIds,
      )!;
      expect((restored.root as WorkspaceSplit).ratio, .65);
      expect(restored.root.panes.first.editorId, 'calendar');
      final snapshot = controller.layout.encode();
      controller.split(split.first.id, WorkspaceAxis.vertical);
      controller.closePane(split.first.id);
      controller.changeEditor(split.first.id, 'tasks');
      controller.resize(split, .3);
      controller.toggleMaximize(split.first.id);
      expect(controller.layout.encode(), snapshot);
      controller.dispose();
    },
  );

  test(
    'failed save can be retried without losing the accepted layout',
    () async {
      var fail = true;
      String? saved;
      final controller = create(
        save: (value) async {
          if (fail) throw StateError('disk unavailable');
          saved = value;
        },
      );
      controller.split(controller.selectedId, WorkspaceAxis.vertical);
      await expectLater(controller.flush(), throwsStateError);
      fail = false;
      await controller.close();
      expect(saved, controller.layout.encode());
      controller.dispose();
    },
  );

  test(
    'a retained divider cannot restore removed panes or old editor types',
    () async {
      final controller = create();
      final oldSplit = controller.layout.root as WorkspaceSplit;
      controller.changeEditor(oldSplit.first.id, 'calendar');
      controller.resize(oldSplit, .6);
      expect(controller.layout.root.panes.first.editorId, 'calendar');
      controller.closePane(oldSplit.second.id);
      controller.resize(oldSplit, .4);
      expect(controller.layout.root.panes.length, 1);
      expect(controller.layout.root.panes.single.editorId, 'calendar');
      await controller.close();
      controller.dispose();
    },
  );

  test('pane limit and invalid editor commands leave a valid layout', () async {
    final controller = create();
    for (var i = 0; i < 20; i++) {
      controller.split(controller.selectedId, WorkspaceAxis.vertical);
    }
    expect(controller.layout.root.panes.length, WorkspaceLayout.maxPanes);
    final snapshot = controller.layout.encode();
    controller.changeEditor(controller.selectedId, 'missing');
    controller.split('missing', WorkspaceAxis.horizontal);
    expect(controller.layout.encode(), snapshot);
    expect(WorkspaceLayout.decode(snapshot, controller.editorIds), isNotNull);
    await controller.close();
    controller.dispose();
  });

  test(
    'damaged, duplicate, oversized and unsupported layouts are rejected',
    () {
      const editors = {'tasks', 'calendar'};
      expect(
        WorkspaceLayout.decode(WorkspaceLayout.initial.encode(), editors),
        isNotNull,
      );
      for (final value in [
        'bad json',
        'null',
        '[]',
        '{"version":2}',
        '{"version":1,"root":null}',
      ]) {
        expect(WorkspaceLayout.decode(value, editors), isNull);
      }
      final split = WorkspaceLayout.initial.root as WorkspaceSplit;
      for (final root in [
        const WorkspacePane('a', 'unknown'),
        WorkspaceSplit('a', split.axis, .5, split.first, split.first),
        WorkspaceSplit('a', split.axis, 1, split.first, split.second),
      ]) {
        expect(
          WorkspaceLayout.decode(WorkspaceLayout(root).encode(), editors),
          isNull,
        );
      }
      var root = <String, Object>{'id': 'leaf', 'editor': 'tasks'};
      for (var i = 0; i < 30; i++) {
        root = {
          'id': 'split-$i',
          'axis': 'vertical',
          'ratio': .5,
          'first': root,
          'second': {'id': 'pane-$i', 'editor': 'calendar'},
        };
      }
      expect(
        WorkspaceLayout.decode(
          jsonEncode({'version': 1, 'root': root}),
          editors,
        ),
        isNull,
      );
    },
  );
}
