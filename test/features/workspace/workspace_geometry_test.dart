import 'dart:ui';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/workspace/workspace_geometry.dart';
import 'package:life_os/features/workspace/workspace_layout.dart';

void main() {
  test(
    'repeated boundary drags preserve other divider positions and minimum sizes',
    () {
      WorkspaceNode root = const WorkspaceSplit(
        'outer',
        WorkspaceAxis.horizontal,
        .5,
        WorkspaceSplit(
          'left',
          WorkspaceAxis.vertical,
          .5,
          WorkspaceSplit(
            'inner',
            WorkspaceAxis.horizontal,
            .5,
            WorkspacePane('a', 'tasks'),
            WorkspacePane('b', 'tasks'),
          ),
          WorkspacePane('c', 'tasks'),
        ),
        WorkspaceSplit(
          'right',
          WorkspaceAxis.horizontal,
          .5,
          WorkspacePane('d', 'tasks'),
          WorkspacePane('e', 'tasks'),
        ),
      );
      const size = Size(1800, 1200);
      final random = Random(42);
      for (var i = 0; i < 200; i++) {
        final before = WorkspaceGeometry(root, size);
        final ids = before.splits.keys.toList();
        final moved = ids[random.nextInt(ids.length)];
        root = before.moveDivider(moved, random.nextDouble() * 10000 - 5000);
        final after = WorkspaceGeometry(root, size);
        for (final id in ids.where((id) => id != moved)) {
          final oldDivider = before.splits[id]!;
          final newDivider = after.splits[id]!;
          expect(
            oldDivider.horizontal
                ? newDivider.divider.left
                : newDivider.divider.top,
            closeTo(
              oldDivider.horizontal
                  ? oldDivider.divider.left
                  : oldDivider.divider.top,
              .0001,
            ),
          );
        }
        for (final rect in after.panes.values) {
          expect(rect.width, greaterThanOrEqualTo(259.9999));
          expect(rect.height, greaterThanOrEqualTo(259.9999));
        }
        expect(
          WorkspaceLayout.decode(WorkspaceLayout(root).encode(), {'tasks'}),
          isNotNull,
        );
      }
    },
  );

  test(
    'moving an outer divider preserves nested boundaries in both branches',
    () {
      const root = WorkspaceSplit(
        'outer',
        WorkspaceAxis.horizontal,
        .5,
        WorkspaceSplit(
          'left',
          WorkspaceAxis.vertical,
          .5,
          WorkspaceSplit(
            'top-left',
            WorkspaceAxis.horizontal,
            .5,
            WorkspacePane('a', 'tasks'),
            WorkspacePane('b', 'tasks'),
          ),
          WorkspaceSplit(
            'bottom-left',
            WorkspaceAxis.horizontal,
            .5,
            WorkspacePane('c', 'tasks'),
            WorkspacePane('d', 'tasks'),
          ),
        ),
        WorkspaceSplit(
          'right',
          WorkspaceAxis.horizontal,
          .5,
          WorkspacePane('e', 'tasks'),
          WorkspacePane('f', 'tasks'),
        ),
      );
      const size = Size(2400, 1400);
      final before = WorkspaceGeometry(root, size);
      final changed = before.moveDivider('outer', 150);
      final after = WorkspaceGeometry(changed, size);
      for (final id in ['top-left', 'bottom-left', 'right']) {
        expect(
          after.splits[id]!.divider.left,
          closeTo(before.splits[id]!.divider.left, .0001),
        );
      }
      expect(
        after.splits['left']!.divider.top,
        before.splits['left']!.divider.top,
      );
      for (final id in ['a', 'c', 'f']) {
        expect(after.panes[id], before.panes[id]);
      }
      expect(
        after.panes['b']!.width,
        closeTo(before.panes['b']!.width + 150, .0001),
      );
      expect(
        after.panes['d']!.width,
        closeTo(before.panes['d']!.width + 150, .0001),
      );
      expect(
        after.panes['e']!.width,
        closeTo(before.panes['e']!.width - 150, .0001),
      );
    },
  );

  test('anchored proportions survive save and restore on wide workspaces', () {
    const root = WorkspaceSplit(
      'outer',
      WorkspaceAxis.horizontal,
      .5,
      WorkspaceSplit(
        'inner',
        WorkspaceAxis.horizontal,
        .1,
        WorkspacePane('a', 'tasks'),
        WorkspacePane('b', 'tasks'),
      ),
      WorkspacePane('c', 'tasks'),
    );
    const size = Size(6000, 1400);
    final before = WorkspaceGeometry(root, size);
    final changed = before.moveDivider('outer', 2000);
    expect((changed.find('inner')! as WorkspaceSplit).ratio, lessThan(.1));
    final restored = WorkspaceLayout.decode(WorkspaceLayout(changed).encode(), {
      'tasks',
    })!;
    final after = WorkspaceGeometry(restored.root, size);
    expect(
      after.splits['inner']!.divider.left,
      closeTo(before.splits['inner']!.divider.left, .0001),
    );
    expect(after.panes['a']!.width, closeTo(before.panes['a']!.width, .0001));
  });
}
