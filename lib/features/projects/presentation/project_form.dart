// features/projects/presentation/create_project_form.dart
import 'package:flutter/material.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
class CreateProjectForm extends StatefulWidget {
  final Function(Project) onProjectCreated;

  const CreateProjectForm({
    super.key, 
    required this.onProjectCreated,
  });

  @override
  State<CreateProjectForm> createState() => _CreateProjectFormState();
}

class _CreateProjectFormState extends State<CreateProjectForm> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Default values mapping to your Project.create factory defaults
  String _selectedColor = '#4A90D9'; 
  String? _selectedGoalId; // Can be integrated with your goals feature later

  // A quick palette of preset hex colors for your Life OS style
  final List<String> _colorPalette = [
    '#4A90D9', // Default Blue
    '#E74C3C', // Red
    '#2ECC71', // Green
    '#F1C40F', // Yellow
    '#9B59B6', // Purple
    '#E67E22', // Orange
    '#34495E', // Dark Slate
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Using your Project.create factory constructor
      final newProject = Project.create(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        color: _selectedColor,
        // goalId: _selectedGoalId ?? '', // Pass if needed
      );

      widget.onProjectCreated(newProject);
    }
  }

  // Helper to convert hex string back to Flutter Color object


  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Create New Project',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),

          // Project Name Input
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Project Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.folder_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a project name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description Input
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 40.0), // Align icon with top line
                child: Icon(Icons.description_outlined),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Color Picker Label
          Text(
            'Project Theme Color',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),

          // Horizontal Color Selection List
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _colorPalette.length,
              itemBuilder: (context, index) {
                final hexColor = _colorPalette[index];
                final isSelected = _selectedColor == hexColor;
                final color = parseHexColor(hexColor);

                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hexColor),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6.0),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3.0)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Submit Button
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: const Text('Create Project'),
          ),
        ],
      ),
    );
  }
}