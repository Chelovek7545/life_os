import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_screen_state.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_view_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.viewModel});
  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final padding = EdgeInsets.all(isLandscape ? AppMargins.lg : AppMargins.xl);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: isLandscape ? 16 : 24),
          Expanded(
            child: StreamBuilder<DashboardScreenState>(
              stream: viewModel.state,
              builder: (context, asyncSnapshot) {
                if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                return asyncSnapshot.data!.when(
                  initial: () => const Center(child: Text("initial")),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e) => Text(e),
                  loaded: (items) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        int crossAxisCount;
                        if (width > 900) {
                          crossAxisCount = 4;
                        } else if (width > 600) {
                          crossAxisCount = 3;
                        } else {
                          crossAxisCount = 2;
                        }

                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemBuilder: (context, index) => RepaintBoundary(
                            key: ValueKey(items[index].title),
                            child: _Card(
                              title: items[index].title,
                              subtitle: items[index].value,
                              icon: items[index].icon,
                            ),
                          ),
                          itemCount: items.length,
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

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _Card({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: theme.colorScheme.primary),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
