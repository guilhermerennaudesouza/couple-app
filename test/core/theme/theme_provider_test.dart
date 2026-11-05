import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Initial theme mode defaults to system', () async {
      final notifier = ThemeModeNotifier(storage: const FlutterSecureStorage());
      await notifier.loadThemeMode();
      expect(notifier.state, ThemeMode.system);
    });

    test('Set theme mode updates state and persists', () async {
      final storage = const FlutterSecureStorage();
      final notifier = ThemeModeNotifier(storage: storage);
      await notifier.loadThemeMode();

      await notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);
      expect(await storage.read(key: 'app_theme_mode'), 'dark');

      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);
      expect(await storage.read(key: 'app_theme_mode'), 'light');

      await notifier.setThemeMode(ThemeMode.system);
      expect(notifier.state, ThemeMode.system);
      expect(await storage.read(key: 'app_theme_mode'), 'system');
    });

    test('Loads previously persisted dark mode', () async {
      FlutterSecureStorage.setMockInitialValues({'app_theme_mode': 'dark'});
      final notifier = ThemeModeNotifier(storage: const FlutterSecureStorage());
      await notifier.loadThemeMode();
      expect(notifier.state, ThemeMode.dark);
    });
  });
}
