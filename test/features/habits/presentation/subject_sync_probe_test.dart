import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  test('behavior subject add is synchronous', () async {
    final subject = BehaviorSubject<HabitsScreenState>.seeded(
      const HabitsLoading(),
    );
    final states = <HabitsScreenState>[];
    final sub = subject.stream.listen(states.add);
    final before = states.length;
    subject.add(const HabitsLoaded(habits: []));
    debugPrint('DBG after add: len=${states.length}');
    await Future<void>.delayed(Duration.zero);
    debugPrint('DBG after microtask: len=${states.length}');
    expect(states.length, before + 1,
        reason: 'add() must deliver synchronously');
    expect(states.last, isA<HabitsLoaded>());
    sub.cancel();
    subject.close();
  });
}
