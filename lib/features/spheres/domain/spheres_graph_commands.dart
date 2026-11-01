import 'package:graph_api/graph_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'spheres_graph_contributor.dart';

GraphNodeCommands spheresGraphCommands(
  SpheresApi spheres, {
  required GraphDeleteHandler delete,
}) => GraphNodeCommands(
  kind: SpheresGraphContributor.kind,
  update: (request) async {
    final existing = await spheres.getSphere(request.current.id);
    if (existing == null) return;
    await spheres.updateSphere(
      existing.copyWith(
        name: request.updated.title,
        color: request.updated.color,
        updatedAt: DateTime.now(),
      ),
    );
  },
  delete: delete,
);
