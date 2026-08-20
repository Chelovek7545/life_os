import 'package:flutter/material.dart';
import 'package:life_os/core/ui/layout/split_view.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const EditorPage(),
    ),
  );
}

class EditorPage extends StatelessWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adobe-like resizable panels'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final orientation = MediaQuery.of(context).orientation;
            final width = constraints.maxWidth;

            final useWorkspace =
                width >= 900 && orientation == Orientation.landscape;

            if (!useWorkspace) {
              return const _CompactLayout();
            }

            return const _WorkspaceLayout();
          },
        ),
      ),
    );
  }
}

/// Компактный режим: одна колонка.
class _CompactLayout extends StatelessWidget {
  const _CompactLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        _CompactPanel(
          title: 'Layers',
          child: SizedBox(
            height: 180,
            child: _LayersContent(),
          ),
        ),
        SizedBox(height: 12),
        _CompactPanel(
          title: 'Editor',
          child: SizedBox(
            height: 220,
            child: Center(
              child: Text('Editor / Canvas'),
            ),
          ),
        ),
        SizedBox(height: 12),
        _CompactPanel(
          title: 'Timeline',
          child: SizedBox(
            height: 140,
            child: Center(
              child: Text('Timeline'),
            ),
          ),
        ),
        SizedBox(height: 12),
        _CompactPanel(
          title: 'Inspector',
          child: SizedBox(
            height: 220,
            child: _InspectorContent(),
          ),
        ),
      ],
    );
  }
}

/// Широкий режим: Adobe-подобный workspace.
class _WorkspaceLayout extends StatelessWidget {
  const _WorkspaceLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return SplitView(
      axis: Axis.horizontal,
      initialWeights: const [0.22, 0.56, 0.22],
      minSizes: const [220, 360, 260],
      onWeightsChanged: (weights) {
        debugPrint('Root horizontal weights: $weights');
      },
      children: [
        _Panel(
          title: 'Layers',
          color: Colors.blue.shade50,
          child: const _LayersContent(),
        ),

        // Центральный split: сверху редактор, снизу timeline.
        SplitView(
          axis: Axis.vertical,
          initialWeights: const [0.70, 0.30],
          minSizes: const [240, 160],
          onWeightsChanged: (weights) {
            debugPrint('Center vertical weights: $weights');
          },
          children: [
            _Panel(
              title: 'Editor',
              color: Colors.white,
              child: const Center(
                child: Text('Editor / Canvas'),
              ),
            ),
            _Panel(
              title: 'Timeline',
              color: Colors.orange.shade50,
              child: const Center(
                child: Text('Timeline'),
              ),
            ),
          ],
        ),

        _Panel(
          title: 'Inspector',
          color: Colors.green.shade50,
          child: const _InspectorContent(),
        ),
      ],
    );
  }
}

/// Панель для workspace-режима.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.color,
    required this.child,
    super.key,
  });

  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            color: Colors.black12,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Панель для компактного режима.
class _CompactPanel extends StatelessWidget {
  const _CompactPanel({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            color: Colors.black12,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _LayersContent extends StatelessWidget {
  const _LayersContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        ListTile(
          dense: true,
          title: Text('Background'),
        ),
        ListTile(
          dense: true,
          title: Text('Shape layer'),
        ),
        ListTile(
          dense: true,
          title: Text('Text layer'),
        ),
        ListTile(
          dense: true,
          title: Text('Adjustment layer'),
        ),
      ],
    );
  }
}

class _InspectorContent extends StatelessWidget {
  const _InspectorContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        ListTile(
          dense: true,
          title: Text('Opacity'),
          subtitle: Text('100%'),
        ),
        ListTile(
          dense: true,
          title: Text('Blend mode'),
          subtitle: Text('Normal'),
        ),
        ListTile(
          dense: true,
          title: Text('Position'),
          subtitle: Text('x: 0, y: 0'),
        ),
        ListTile(
          dense: true,
          title: Text('Size'),
          subtitle: Text('w: 128, h: 128'),
        ),
      ],
    );
  }
}