import 'package:flutter/material.dart';
import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/di.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize(
    inferenceEngines: [MediaPipeEngine(), LiteRtLmEngine()],
  );
  final container = DependencyContainer();
  container.init();

  runApp(MyApp(diContainer: container));
}
