import 'package:flutter_test/flutter_test.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  test('state stream delivers the latest value to late subscribers', () async {
    final subject = BehaviorSubject<HabitsScreenState>.seeded(
      const HabitsLoading(),
    );
    expect(await subject.first, isA<HabitsLoading>());
    subject.add(HabitsLoaded(habits: []));
    expect(subject.value, isA<HabitsLoaded>());
    expect(await subject.first, isA<HabitsLoaded>());
    await subject.close();
  });
}
