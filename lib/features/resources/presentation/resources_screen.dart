import 'package:flutter/material.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as gv;

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key, required this.repo});

  final GraphNotesRepository repo;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: EdgeInsets.all(isLandscape ? 24.0 : 16.0),
      child: ListView(
        children: [
          const Text(
            'Ресурсы',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          const Text(
            'Helpful guides, notes, and tools for your workflow.',
            
          ),
          const SizedBox(height: 24),

          // 👇 Автоматическое обновление при изменении заметок
          ListenableBuilder(
            listenable: repo,
            builder: (context, _) {
              final notes = repo.getAllNotes();
              return _NotesSummaryCard(notes: notes);
            },
          ),

          const SizedBox(height: 24),
          _ResourceCard(
            title: 'Guides',
            subtitle: 'Step-by-step support for routines and habits.',
            icon: Icons.menu_book,
          ),
          _ResourceCard(
            title: 'Templates',
            subtitle: 'Use reusable layouts for projects and tasks.',
            icon: Icons.grid_view,
          ),
          _ResourceCard(
            title: 'Tools',
            subtitle: 'Productivity apps, timers, and trackers.',
            icon: Icons.build,
          ),
          _ResourceCard(
            title: 'Notes',
            subtitle: 'Capture ideas and reminders quickly.',
            icon: Icons.note,
          ),
        ],
      ),
    );
  }
}

class _NotesSummaryCard extends StatelessWidget {
  const _NotesSummaryCard({super.key, required this.notes});

  final List<gv.GraphNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No notes yet.'),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              notes[index].text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ResourceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
