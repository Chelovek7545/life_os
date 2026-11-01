import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';

class EditableGraphModule implements GraphContributor {
  @override
  String get id => 'editable.nodes';
  final nodes = <String, GraphNodeData>{};
  final changes = StreamController<void>.broadcast();
  Completer<void>? createGate;
  final createEntered = Completer<void>();
  int _nextId = 0;
  int listeners = 0;

  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) =>
      Stream.multi((listener) {
        listeners++;
        void emit() => listener.add(
          nodes.values.where((node) => node.parentId == scope.rootId).toList(),
        );
        emit();
        final subscription = changes.stream.listen((_) => emit());
        listener.onCancel = () async {
          await subscription.cancel();
          listeners--;
        };
      });

  GraphModule get module => GraphModule(
    id: 'editable.graph',
    dependencies: {'spheres.graph'},
    contributors: [this],
    commands: [
      GraphNodeCommands(
        kind: 'editable.entry',
        parentKinds: {'sphere'},
        create: (request) async {
          if (!createEntered.isCompleted) createEntered.complete();
          await createGate?.future;
          final id = 'editable:${++_nextId}';
          nodes[id] = GraphNodeData(
            id: id,
            kind: request.draft.kind,
            title: request.draft.title,
            color: request.draft.color ?? '#123456',
            parentId: request.parent.id,
          );
          changes.add(null);
          return id;
        },
        update: (request) async {
          nodes[request.current.id] = request.updated;
          changes.add(null);
        },
        delete: (request) async {
          nodes.remove(request.node.id);
          changes.add(null);
          return {request.node.id};
        },
      ),
    ],
    presentations: [
      GraphNodePresentation(
        kind: 'editable.entry',
        size: const Size(240, 180),
        builder: (_, node, interaction) => Column(
          children: [
            Text(node.title),
            TextButton(
              onPressed: () async {
                await interaction.updateNode!(
                  GraphNodeData(
                    id: node.id,
                    kind: node.kind,
                    parentId: node.parentId,
                    title: 'Edited by plugin',
                    color: node.color,
                  ),
                );
              },
              child: const Text('Edit plugin entry'),
            ),
            TextButton(
              onPressed: () async => interaction.deleteNode!(false),
              child: const Text('Delete plugin entry'),
            ),
          ],
        ),
      ),
    ],
  );
}
