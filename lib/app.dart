import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/core/theme/app_theme.dart';
import 'package:life_os/main_screen.dart';

class MyApp extends StatelessWidget {
  final DependencyContainer diContainer;

  const MyApp({super.key, required this.diContainer});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Life OS',
      //      themeMode: ThemeMode.dark,
      theme: AppTheme.darkTheme,
      // ThemeData(

      //   colorScheme: ColorScheme.fromSeed(
      //     brightness: Brightness.dark,
      //     seedColor:   Colors.deepPurple),
      //   useMaterial3: true,
      // ),
      // darkTheme: ThemeData(
      //   brightness: Brightness.dark,
      //   primaryColor: Colors.black,
      //   scaffoldBackgroundColor: Colors.black,
      //   colorScheme: const ColorScheme.dark(primary: Colors.indigo),
      // ),
      home: MainScreen(diContainer: diContainer),
    );
  }
}
