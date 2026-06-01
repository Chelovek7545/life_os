import 'package:flutter/material.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
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
          _ProjectCard(
            title: 'Morning Routine',
            description: 'Wake up, meditate, review the day.',
            progress: 0.7,
          ),
          _ProjectCard(
            title: 'Product Launch',
            description: 'Finalize milestones and sprint tasks.',
            progress: 0.45,
          ),
          _ProjectCard(
            title: 'Weekly Review',
            description: 'Reflect, plan, and adjust your goals.',
            progress: 0.8,
          ),
          _ProjectCard(
            title: 'Side Project',
            description: 'Design new app screens and workflow.',
            progress: 0.3,
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
