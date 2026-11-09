import 'package:agent_bridge/local_assistant.dart';
import 'package:flutter/material.dart';

class AssistantSettingsForm extends StatefulWidget {
  const AssistantSettingsForm({
    super.key,
    required this.settings,
    required this.busy,
    required this.onSave,
    required this.onCancel,
  });
  final AssistantSettings settings;
  final bool busy;
  final Future<void> Function(AssistantSettings) onSave;
  final VoidCallback onCancel;
  @override
  State<AssistantSettingsForm> createState() => _AssistantSettingsFormState();
}

class _AssistantSettingsFormState extends State<AssistantSettingsForm> {
  final _form = GlobalKey<FormState>();
  late final _python = TextEditingController(
    text: widget.settings.pythonExecutable,
  );
  late final _model = TextEditingController(
    text: widget.settings.modelDirectory,
  );
  late String _device = widget.settings.device;
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Заполните поле' : null;
  @override
  void dispose() {
    _python.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: ListView(
      key: const ValueKey('assistant.settings-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Локальная модель',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Рекомендуемая модель: Qwen2.5-1.5B-Instruct INT4. Укажите Python из окружения OpenVINO и папку скачанной модели.',
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: const ValueKey('assistant.python'),
          controller: _python,
          enabled: !widget.busy,
          validator: _required,
          decoration: const InputDecoration(
            labelText: 'Python',
            hintText: 'Полный путь к python.exe',
            contentPadding: EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('assistant.model'),
          controller: _model,
          enabled: !widget.busy,
          validator: _required,
          decoration: const InputDecoration(
            labelText: 'Папка модели',
            hintText: 'Папка с openvino_model.xml',
            contentPadding: EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const ValueKey('assistant.device'),
          isExpanded: true,
          initialValue: _device,
          decoration: const InputDecoration(
            labelText: 'Устройство',
            contentPadding: EdgeInsets.all(14),
          ),
          items: const [
            DropdownMenuItem(value: 'NPU', child: Text('NPU · Intel AI Boost')),
            DropdownMenuItem(value: 'GPU', child: Text('GPU · Intel Graphics')),
            DropdownMenuItem(value: 'CPU', child: Text('CPU · процессор')),
          ],
          onChanged: widget.busy
              ? null
              : (value) => setState(() => _device = value!),
        ),
        const SizedBox(height: 16),
        const Text(
          'Модель загружается при первом сообщении. Первая компиляция для NPU может занять несколько минут. Переключение устройства всегда явное.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('assistant.save-settings'),
          onPressed: widget.busy
              ? null
              : () {
                  if (_form.currentState!.validate()) {
                    widget.onSave(
                      AssistantSettings(
                        pythonExecutable: _python.text.trim(),
                        modelDirectory: _model.text.trim(),
                        device: _device,
                      ),
                    );
                  }
                },
          child: const Text('Сохранить'),
        ),
        TextButton(
          onPressed: widget.busy ? null : widget.onCancel,
          child: const Text('Вернуться к чату'),
        ),
      ],
    ),
  );
}
