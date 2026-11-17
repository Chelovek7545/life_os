import 'dart:convert';
import 'package:projects_api/projects_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';

class HierarchySyncCodec {
  static String project(Project p) => jsonEncode({
    'id': p.id,
    'name': p.name,
    'description': p.description,
    'color': p.color,
    'createdAt': p.createdAt.toIso8601String(),
    'updatedAt': p.updatedAt.toIso8601String(),
    'dueDate': p.dueDate?.toIso8601String(),
    'isArchived': p.isArchived,
    'goalId': p.goalId,
    'parentProjectId': p.parentProejectId,
  });
  static Project decodeProject(String text, {String? storageRevision}) {
    final m = jsonDecode(text) as Map<String, dynamic>;
    final p = Project(
      id: m['id'] as String,
      name: m['name'] as String,
      description: m['description'] as String,
      color: m['color'] as String,
      createdAt: DateTime.parse(m['createdAt'] as String),
      updatedAt: DateTime.parse(m['updatedAt'] as String),
      dueDate: m['dueDate'] == null
          ? null
          : DateTime.parse(m['dueDate'] as String),
      isArchived: m['isArchived'] as bool,
      goalId: m['goalId'] as String?,
      parentProejectId: m['parentProjectId'] as String?,
      storageRevision: storageRevision,
    );
    if (project(p) != text) {
      throw const FormatException('Noncanonical project.');
    }
    return p;
  }

  static String goal(Goal g) => jsonEncode({
    'id': g.id,
    'name': g.name,
    'description': g.description,
    'color': g.color,
    'sphereId': g.sphereId,
    'dueDate': g.dueDate?.toIso8601String(),
    'createdAt': g.createdAt.toIso8601String(),
    'updatedAt': g.updatedAt.toIso8601String(),
  });
  static Goal decodeGoal(String text, {String? storageRevision}) {
    final m = jsonDecode(text) as Map<String, dynamic>;
    final g = Goal(
      id: m['id'] as String,
      name: m['name'] as String,
      description: m['description'] as String,
      color: m['color'] as String,
      sphereId: m['sphereId'] as String,
      dueDate: m['dueDate'] == null
          ? null
          : DateTime.parse(m['dueDate'] as String),
      createdAt: DateTime.parse(m['createdAt'] as String),
      updatedAt: DateTime.parse(m['updatedAt'] as String),
      storageRevision: storageRevision,
    );
    if (goal(g) != text) throw const FormatException('Noncanonical goal.');
    return g;
  }

  static String sphere(Sphere s) => jsonEncode({
    'id': s.id,
    'name': s.name,
    'color': s.color,
    'createdAt': s.createdAt.toIso8601String(),
    'updatedAt': s.updatedAt.toIso8601String(),
  });
  static Sphere decodeSphere(String text, {String? storageRevision}) {
    final m = jsonDecode(text) as Map<String, dynamic>;
    final s = Sphere(
      id: m['id'] as String,
      name: m['name'] as String,
      color: m['color'] as String,
      createdAt: DateTime.parse(m['createdAt'] as String),
      updatedAt: DateTime.parse(m['updatedAt'] as String),
      storageRevision: storageRevision,
    );
    if (sphere(s) != text) throw const FormatException('Noncanonical sphere.');
    return s;
  }

  static String tag(Tag t) {
    if (t.syncId == null ||
        t.syncId!.isEmpty ||
        t.name.isEmpty ||
        t.name.length > 20) {
      throw const FormatException('Invalid portable tag.');
    }
    return jsonEncode({'id': t.syncId, 'name': t.name, 'colorHex': t.colorHex});
  }

  static Tag decodeTag(String text) {
    final m = jsonDecode(text) as Map<String, dynamic>;
    final t = Tag(
      id: 0,
      syncId: m['id'] as String,
      name: m['name'] as String,
      colorHex: m['colorHex'] as int,
    );
    if (tag(t) != text) throw const FormatException('Noncanonical tag.');
    return t;
  }
}
