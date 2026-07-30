import 'package:flutter/material.dart';
import 'package:life_os/features/settings/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Локальные состояния настроек
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'Русский';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки'), centerTitle: true),
      body: ListView(
        children: [
          // --- СЕКЦИЯ: ВНЕШНИЙ ВИД И УВЕДОМЛЕНИЯ ---
          _buildSectionHeader(context, 'Основные'),

          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Тёмная тема'),
            subtitle: const Text('Включить ночное оформление'),
            value: _isDarkMode,
            onChanged: (bool value) {
              // setState(() {
              //   _isDarkMode = value;
              // });
              // TODO: Вызов метода контроллера темы / AppState
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Уведомления'),
            subtitle: const Text('Получать push-уведомления'),
            value: _notificationsEnabled,
            onChanged: (bool value) {
              // setState(() {
              //   _notificationsEnabled = value;
              // });
            },
          ),

          const Divider(),

          // --- СЕКЦИЯ: ЯЗЫК И РЕГИОН ---
          _buildSectionHeader(context, 'Предпочтения'),

          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Язык приложения'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedLanguage,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: (){}
            //() => _showLanguageDialog(context),
          ),

          const Divider(),

          _buildSectionHeader(context, 'Optimization'),

          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.hasBlur,
            builder: (context, isBlurEnabled, child) {
              return SwitchListTile(
                secondary: const Icon(Icons.blur_on),
                title: const Text('Эффект размытия (Blur)'),
                subtitle: const Text(
                  'Включить размытие для элементов GlassPanel',
                ),
                value: isBlurEnabled,
                onChanged: (bool value) {
                  SettingsService.setHasBlur(value);
                },
              );
            },
          ),
          const Divider(),

          // --- СЕКЦИЯ: О ПРИЛОЖЕНИИ ---
          _buildSectionHeader(context, 'О системе'),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('О программе'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Pulse',
                applicationVersion: '0.0.1',
                applicationLegalese: '© 2026 Developer',
              );
            },
          ),
        ],
      ),
    );
  }

  // Заголовок секции
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // Диалог выбора языка
  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выберите язык'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Русский'),
                value: 'Русский',
                groupValue: _selectedLanguage,
                onChanged: (String? value) {
                  setState(() => _selectedLanguage = value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                title: const Text('English'),
                value: 'English',
                groupValue: _selectedLanguage,
                onChanged: (String? value) {
                  setState(() => _selectedLanguage = value!);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
