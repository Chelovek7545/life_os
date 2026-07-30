import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService', () {
    testWidgets('hasBlur defaults to true', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.init();

      expect(SettingsService.hasBlur.value, isTrue);
    });

    testWidgets('setHasBlur updates the notifier value', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.init();

      await SettingsService.setHasBlur(false);
      expect(SettingsService.hasBlur.value, isFalse);

      await SettingsService.setHasBlur(true);
      expect(SettingsService.hasBlur.value, isTrue);
    });
  });
}
