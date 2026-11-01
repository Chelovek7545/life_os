import 'package:flutter/material.dart';

class PluginPanelSurface extends StatelessWidget {
  const PluginPanelSurface({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.controls,
  });
  final String title;
  final String? subtitle;
  final Widget? controls;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (controls != null) ...[const SizedBox(height: 12), controls!],
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}
