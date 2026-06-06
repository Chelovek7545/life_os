import 'package:flutter/material.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/projects/presentation/projects_state.dart';
import 'package:life_os/features/projects/presentation/projects_view_model.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.viewModel});

  final ProjectsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () => viewModel.addProjects(Project.create(name: 'new')),
            child: Text("new"),
          ),
          const Text(
            'Projects & Routines',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          const Text(
            'Organize your ongoing projects and repeatable routines in one place.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<ProjectsScreenState>(
              stream: viewModel.state,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                return snapshot.data!.when(
                  loading: () => Center(child: CircularProgressIndicator()),
                  empty: (_) => Text("empty"),
                  error: (e) => Text(e),
                  loaded: (projects, _, curProject) {
                    if (projects.isEmpty) {
                      return const Center(
                        child: Text(
                          'No tasks available yet.',
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    }
            
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        return _ProjectCard(
                          title: project.name,
                          description: project.description,
                          progress: 0.3,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String title;
  final String description;
  final double progress;

  const _ProjectCard({
    required this.title,
    required this.description,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 8),
            Text('${(progress * 100).round()}% complete'),
          ],
        ),
      ),
    );
  }
}
