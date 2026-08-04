import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/layout/split_view.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/create_sphere_dialog.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';

/// PULSE — список сфер жизни. По тапу открывает [LifeGraphScreen] (граф сферы)
/// через [Navigator.push]. Создание сферы — кнопкой в AppBar.
class PulseScreen extends StatelessWidget {
  final LifeGraphViewModel viewModel;

  const PulseScreen({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      appBar: AppBar(
        title: const Text('PULSE'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [],
      ),
      body: LayoutBuilder(
        builder: (context, asyncSnapshot) {
          bool isSplit = asyncSnapshot.maxWidth >= 900;

          final goalsPanel = _GoalsPanel(viewModel: viewModel);

          final spheresPanel = Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Spacer(),
                  Text("Spheres", style: AppTypography.headlineLg),
                  Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    style: AppButtonStyles.menuButtonStyle(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    tooltip: 'Новая сфера',
                    onPressed: () => _showCreateSphereDialog(context),
                  ),
                  SizedBox(width: AppMargins.md,)
                ],
              ),
              Flexible(
                child: StreamBuilder<List<Sphere>>(
                  stream: viewModel.spheresStream,
                  initialData: viewModel.spheres,
                  builder: (context, snapshot) {
                    final spheres = snapshot.data ?? const <Sphere>[];
                    if (spheres.isEmpty) {
                      return _EmptyState(
                        onCreate: () => _showCreateSphereDialog(context),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: spheres.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final sphere = spheres[index];
                        return _SphereTile(
                          sphere: sphere,
                          viewModel: viewModel,
                          onTap: () => _openGraph(context, sphere),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );

          return isSplit
              ? SplitView(
                  minSizes: [300, 300, 300],
                  axis: Axis.horizontal,
                  dividerThickness: 2,
                  dividerBuilder: (context, dividerIndex, axis) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.borderGlass,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  },
                  initialWeights: [0.1, 0.8, 0.1],
                  children: [
                    goalsPanel,
                    const Text("Coming soon..."),
                    spheresPanel,
                  ],
                )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: goalsPanel),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Coming soon...",
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(child: spheresPanel),
                ]);
        },
      ),
    );
  }

  Future<void> _openGraph(BuildContext context, Sphere sphere) async {
    await viewModel.switchSphere(sphere.id);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LifeGraphScreen(viewModel: viewModel),
      ),
    );
  }

  Future<void> _showCreateSphereDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => CreateSphereDialog(viewModel: viewModel),
    );
  }
}

/// Панель списка всех целей (display-only). В подзаголовке — имя сферы.
class _GoalsPanel extends StatelessWidget {
  final LifeGraphViewModel viewModel;

  const _GoalsPanel({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Spacer(),
            Text("Goals", style: AppTypography.headlineLg),
            const Spacer(),
            const SizedBox(width: AppMargins.md),
          ],
        ),
        Flexible(
          child: StreamBuilder<List<Sphere>>(
            stream: viewModel.spheresStream,
            initialData: viewModel.spheres,
            builder: (context, sphereSnapshot) {
              final spheres = sphereSnapshot.data ?? const <Sphere>[];
              final sphereNameOf = <String, String>{
                for (final s in spheres) s.id: s.name,
              };
              return StreamBuilder<List<Goal>>(
                stream: viewModel.goalsStream,
                initialData: viewModel.goals,
                builder: (context, goalSnapshot) {
                  final goals = goalSnapshot.data ?? const <Goal>[];
                  if (goals.isEmpty) {
                    return const Center(
                      child: Text(
                        'Нет целей',
                        style: TextStyle(color: Colors.white38),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: goals.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      return _GoalTile(
                        goal: goal,
                        sphereName: sphereNameOf[goal.sphereId] ?? '',
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Строка списка целей: цвет-индикатор, название, имя сферы.
class _GoalTile extends StatelessWidget {
  final Goal goal;
  final String sphereName;

  const _GoalTile({required this.goal, required this.sphereName});

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(goal.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sphereName.isEmpty ? 'Без сферы' : sphereName,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка списка сфер: цвет-индикатор, название, счётчик нод и дата создания.
class _SphereTile extends StatelessWidget {
  final Sphere sphere;
  final LifeGraphViewModel viewModel;
  final VoidCallback onTap;

  const _SphereTile({
    required this.sphere,
    required this.viewModel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(sphere.color);
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sphere.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatDate(sphere.createdAt)} · создана',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SphereNodeCount(viewModel: viewModel, sphereId: sphere.id),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Счётчик нод сферы (без корня-сферы) через live-стрим графа.
class _SphereNodeCount extends StatelessWidget {
  final LifeGraphViewModel viewModel;
  final String sphereId;

  const _SphereNodeCount({required this.viewModel, required this.sphereId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GraphNode>>(
      stream: viewModel.graphBuilder.watchGraph(sphereId),
      builder: (context, snapshot) {
        final content = (snapshot.data?.length ?? 0) - 1;
        final text = content <= 0
            ? 'пусто'
            : '$content ${_plural(content, 'нода', 'ноды', 'нод')}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11.5,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.public_rounded, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          const Text(
            'Нет сфер жизни',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте первую сферу',
            style: TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Создать сферу'),
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
