import 'package:flutter/material.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/di.dart';

void main() {
  final container = DependencyContainer();
  container.init();
  //debugRepaintRainbowEnabled = true;
  runApp(MyApp(diContainer: container));
}
