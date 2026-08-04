import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';

/// Диалог создания сферы. Владеет собственным [TextEditingController] и
/// освобождает его в [dispose] — после полного удаления роута диалога
/// (когда TextField уже размонтирован), исключая «controller used after disposed».
class CreateSphereDialog extends StatefulWidget {
  final LifeGraphViewModel viewModel;

  const CreateSphereDialog({super.key, required this.viewModel});

  @override
  State<CreateSphereDialog> createState() => _CreateSphereDialogState();
}

class _CreateSphereDialogState extends State<CreateSphereDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      title: const Text('Новая сфера жизни'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Название (например: Работа, Семья, Здоровье)',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              widget.viewModel.createSphere(name: name);
              Navigator.pop(context);
            }
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}
