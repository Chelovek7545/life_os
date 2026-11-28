import 'package:flutter/material.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:projects_plugin/projects_plugin.dart';
import 'package:graph_api/graph_api.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/ui/graph_edit_fields.dart';

const projectGraphComponent = GraphNodeComponentSpec(
  kind: 'project',
  label: 'ПРОЕКТ',
  icon: Icons.folder_rounded,
  size: Size(180, 100),
  editTitle: 'Редактировать проект',
  createTitle: 'Добавить проект',
  details: _projectDeadline,
  editFields: _projectFields,
);

Widget _projectFields(
  BuildContext context,
  Map<String, Object?> attributes,
  ValueChanged<Map<String, Object?>> onChanged,
) => GraphNodeEditLayout.maybeOf(context) == null
    ? const SizedBox.shrink()
    : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          GraphEditDateField(
            label: 'Дедлайн',
            value: attributes['dueDate'] as DateTime?,
            onChanged: (date) => onChanged({'dueDate': date}),
          ),
          graphEditSelect(
            label: 'Состояние',
            value: attributes['isArchived'] == true,
            options: const {false: 'Активный', true: 'В архиве'},
            onChanged: (value) => onChanged({'isArchived': value}),
          ),
        ],
      );

Widget? _projectDeadline(
  BuildContext context,
  GraphNodeData node,
  GraphNodeInteraction state,
) {
  final date = node.attributes['dueDate'];
  if (date is! DateTime) return null;
  return GraphNodeMetaChip(
    icon: Icons.calendar_today_outlined,
    label: 'До ${formatDate(date.toLocal())}',
  );
}

GraphNodeEditor projectsGraphEditor() => graphNodeEditor(projectGraphComponent);
List<GraphChildAction> projectsGraphChildActions() => projectsChildActions(
  (_, actions) => graphChildForm(projectGraphComponent, actions),
);
