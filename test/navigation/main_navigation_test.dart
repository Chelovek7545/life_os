import 'package:life_os/navigation/main_navigation.dart';
import 'package:test/test.dart';

void main() {
  group('MainNavigationRouteNames', () {
    test('has expected route constants', () {
      expect(MainNavigationRouteNames.loaderWidget, '/');
      expect(MainNavigationRouteNames.auth, '/auth');
      expect(MainNavigationRouteNames.tasks, '/tasks');
      expect(MainNavigationRouteNames.main, '/main');
      expect(MainNavigationRouteNames.projects, '/projects');
      expect(MainNavigationRouteNames.timer, '/timer');
      expect(MainNavigationRouteNames.resources, '/resources');
    });

    test('all route names start with /', () {
      expect(MainNavigationRouteNames.loaderWidget.startsWith('/'), isTrue);
      expect(MainNavigationRouteNames.auth.startsWith('/'), isTrue);
      expect(MainNavigationRouteNames.tasks.startsWith('/'), isTrue);
      expect(MainNavigationRouteNames.main.startsWith('/'), isTrue);
      expect(MainNavigationRouteNames.projects.startsWith('/'), isTrue);
      expect(MainNavigationRouteNames.timer.startsWith('/'), isTrue);
      expect(MainNavigationRouteNames.resources.startsWith('/'), isTrue);
    });
  });
}
