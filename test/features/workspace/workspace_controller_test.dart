import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/workspace/workspace_controller.dart';
import 'package:life_os/features/workspace/workspace_layout.dart';

void main() {
  WorkspaceController create({Future<void> Function(String)? save}) =>
      WorkspaceController(
        editorIds: const {'tasks', 'calendar'},
        save: save ?? (_) async {},
        onSaveError: (_, _) {},
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
