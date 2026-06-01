import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/main_screen.dart';

class MyApp extends StatelessWidget {
  final DependencyContainer diContainer;

  const MyApp({super.key, required this.diContainer});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life OS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MainScreen(diContainer: diContainer,),
    );
  }
}


