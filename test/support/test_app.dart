import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/app/dependency_container.dart';

Future<DependencyContainer> createTestApp({
  bool enableTelegram = false,
  bool enableObsidian = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = DependencyContainer(
    database: AppDatabase(NativeDatabase.memory()),
    enableTelegram: enableTelegram,
    enableObsidian: enableObsidian,
  );
  await container.init();
  return container;
}

Future<void> disposeTestApp(
  WidgetTester tester,
  DependencyContainer container,
) async {
  await tester.pumpWidget(const SizedBox());
  var closed = false;
  final closing = container.dispose().then((_) {
    closed = true;
  });
  for (var i = 0; i < 100 && !closed; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(closed, isTrue, reason: 'All app resources must finish closing.');
  await closing;
}
