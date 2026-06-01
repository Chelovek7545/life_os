import 'package:flutter/material.dart';

class MainScreenN extends StatelessWidget {
  const MainScreenN({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your daily progress at a glance. Tap any card to open a detail view.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _SummaryCard(
                  title: 'Today',
                  subtitle: '4 tasks left',
                  icon: Icons.calendar_today,
                ),
                _SummaryCard(
                  title: 'Focus',
                  subtitle: '2 sessions planned',
                  icon: Icons.timer,
                ),
                _SummaryCard(
                  title: 'Routine',
                  subtitle: 'Morning habits',
                  icon: Icons.repeat,
                ),
                _SummaryCard(
                  title: 'Insights',
                  subtitle: 'Weekly summary',
                  icon: Icons.insights,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
