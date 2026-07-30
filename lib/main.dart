import 'package:flutter/material.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/features/settings/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = DependencyContainer();
  container.init();
  await SettingsService.init();
  //debugRepaintRainbowEnabled = true;
  runApp(MyApp(diContainer: container));
}
