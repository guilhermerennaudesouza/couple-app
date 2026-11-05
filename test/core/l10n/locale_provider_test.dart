import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/l10n/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleProvider Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Initial locale defaults to Portuguese (pt-BR)', () async {
      final notifier = LocaleNotifier(storage: const FlutterSecureStorage());
      await notifier.loadLocale();
      expect(notifier.state, const Locale('pt', 'BR'));
      expect(notifier.isPortuguese, isTrue);
    });

    test('Set locale updates state and persists', () async {
      final storage = const FlutterSecureStorage();
      final notifier = LocaleNotifier(storage: storage);
      await notifier.loadLocale();

      await notifier.setLocale(const Locale('en', 'US'));
      expect(notifier.state, const Locale('en', 'US'));
      expect(notifier.isPortuguese, isFalse);
      expect(await storage.read(key: 'app_locale'), 'en_US');

      await notifier.toggleLanguage();
      expect(notifier.state, const Locale('pt', 'BR'));
      expect(notifier.isPortuguese, isTrue);
      expect(await storage.read(key: 'app_locale'), 'pt_BR');
    });

    test('Loads previously persisted English locale', () async {
      FlutterSecureStorage.setMockInitialValues({'app_locale': 'en_US'});
      final notifier = LocaleNotifier(storage: const FlutterSecureStorage());
      await notifier.loadLocale();
      expect(notifier.state, const Locale('en', 'US'));
      expect(notifier.isPortuguese, isFalse);
    });
  });
}
