import 'package:flutter/material.dart';
import 'package:life_os/app.dart';
import 'package:life_os/app/dependency_container.dart';
import 'package:life_os/features/settings/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = DependencyContainer();
  await SettingsService.init();
  try {
    await container.init();
  } catch (_) {
    await container.dispose();
    rethrow;
  }
  //debugRepaintRainbowEnabled = true;
  runApp(MyApp(diContainer: container));
}
