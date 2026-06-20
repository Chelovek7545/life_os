import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';
import 'package:life_os/core/ui/semantic_tag.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/ui/vibrant_gradient_button.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';

void main() {
  runApp(const UIComponentsPreviewApp());
}

class UIComponentsPreviewApp extends StatelessWidget {
  const UIComponentsPreviewApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life OS UI Components Preview',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.surfaceContainer,
        brightness: Brightness.dark,
      ),
      home: const UIComponentsPreviewScreen(),
    );
  }
}

class UIComponentsPreviewScreen extends StatefulWidget {
  const UIComponentsPreviewScreen({Key? key}) : super(key: key);

  @override
  State<UIComponentsPreviewScreen> createState() => _UIComponentsPreviewScreenState();
}

class _UIComponentsPreviewScreenState extends State<UIComponentsPreviewScreen> {
  int _pillSwitcherIndex = 0;
  int _segmentedPillIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UI Components Preview'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Glass Panel Section
            _buildSectionTitle('Glass Panel'),
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This is a Glass Panel',
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A modern glassmorphism effect with blur and frosted glass appearance',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Pill Switcher Section
            _buildSectionTitle('Pill Switcher'),
            const SizedBox(height: 12),
            PillSwitcher(
              options: const ['Option 1', 'Option 2', 'Option 3'],
              onSelectionChanged: (index) {
                setState(() => _pillSwitcherIndex = index);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Selected: Option ${_pillSwitcherIndex + 1}',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Segmented Pill Control Section
            _buildSectionTitle('Segmented Pill Control'),
            const SizedBox(height: 12),
            SegmentedPillControl(
              tabs: const ['Tab 1', 'Tab 2', 'Tab 3'],
              onTabChanged: (index) {
                setState(() => _segmentedPillIndex = index);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Selected: Tab ${_segmentedPillIndex + 1}',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Semantic Tags Section
            _buildSectionTitle('Semantic Tags'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SemanticTag(
                  label: 'flutter',
                  accentColor: Colors.blue,
                ),
                SemanticTag(
                  label: 'ui',
                  accentColor: Colors.purple,
                  onRemove: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tag removed')),
                  ),
                ),
                SemanticTag(
                  label: 'design',
                  accentColor: Colors.green,
                ),
                SemanticTag(
                  label: 'components',
                  accentColor: Colors.orange,
                  onRemove: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tag removed')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Vibrant Gradient Button Section
            _buildSectionTitle('Vibrant Gradient Button'),
            const SizedBox(height: 12),
            VibrantGradientButton(
              text: 'Get Started',
              icon: Icons.rocket_launch,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Button pressed!')),
                );
              },
            ),
            const SizedBox(height: 32),

            // Task Card Section
            _buildSectionTitle('Task Card Examples'),
            const SizedBox(height: 12),
            
            // Normal Task Card
            TaskCard(
              title: 'Complete UI preview design',
              projectTitle: 'Life OS',
              dueDate: DateTime.now().add(const Duration(days: 2)),
              tags: [
              ],
              isCompleted: false,
              isOverdue: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task tapped')),
                );
              },
              onCheckChanged: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task completed')),
                );
              },
            ),
            const SizedBox(height: 12),

            // Overdue Task Card
            TaskCard(
              title: 'Fix critical bug in database',
              projectTitle: 'Backend',
              dueDate: DateTime.now().subtract(const Duration(days: 1)),
              tags: [
              ],
              isCompleted: false,
              isOverdue: true,
              leftBorderColor: Colors.red,
              onTap: () {},
              onCheckChanged: () {},
            ),
            const SizedBox(height: 12),

            // Completed Task Card
            TaskCard(
              title: 'Review pull request',
              projectTitle: 'Life OS',
              dueDate: DateTime.now().subtract(const Duration(days: 3)),
              tags: [
              ],
              isCompleted: true,
              isOverdue: false,
              onTap: () {},
              onCheckChanged: () {},
            ),
            const SizedBox(height: 32),

            // Additional Glass Panel Examples
            _buildSectionTitle('Glass Panel Variants'),
            const SizedBox(height: 12),
            
            // Without padding
            GlassPanel(
              borderRadius: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Glass Panel with Custom Border Radius',
                  style: AppTypography.bodyMd,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // With custom padding
            GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feature',
                        style: AppTypography.headlineLg.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'With icon and content',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.check_circle,
                    color: AppColors.primaryContainer,
                    size: 32,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.headlineLg.copyWith(
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }
}
