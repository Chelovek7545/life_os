import 'package:graph_api/graph_api.dart';
import 'package:spheres_api/spheres_api.dart';

class SpheresGraphContributor implements GraphContributor {
  SpheresGraphContributor(this.spheres);
  static const kind = 'sphere';
  final SpheresQueries spheres;
  @override
  String get id => 'spheres.nodes';
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) =>
      spheres.watchAllSpheres().map(
        (values) => [
          for (final sphere in values)
            if (sphere.id == scope.rootId)
              GraphNodeData(
                id: sphere.id,
                kind: kind,
                title: sphere.name,
                color: sphere.color,
              ),
        ],
      );
}
