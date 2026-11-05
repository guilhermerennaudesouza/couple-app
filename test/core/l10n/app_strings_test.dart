import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/l10n/app_strings.dart';

void main() {
  group('AppStrings Tests', () {
    test('Portuguese and English strings have valid non-empty values', () {
      final pt = AppStrings.ofLocale(const Locale('pt', 'BR'));
      final en = AppStrings.ofLocale(const Locale('en', 'US'));

      expect(pt.navToday, 'Hoje');
      expect(en.navToday, 'Today');

      expect(pt.navTasks, 'Tarefas');
      expect(en.navTasks, 'Tasks');

      expect(pt.navCalendar, 'Calendário');
      expect(en.navCalendar, 'Calendar');

      expect(pt.navDecide, 'Decidir');
      expect(en.navDecide, 'Decide');

      expect(pt.navHub, 'Espaço');
      expect(en.navHub, 'Hub');

      expect(pt.settings, 'Preferências');
      expect(en.settings, 'Preferences');

      expect(pt.language, 'Idioma');
      expect(en.language, 'Language');

      expect(pt.theme, 'Tema');
      expect(en.theme, 'Theme');

      expect(pt.themeLight, 'Claro');
      expect(en.themeLight, 'Light');

      expect(pt.themeDark, 'Escuro');
      expect(en.themeDark, 'Dark');

      expect(pt.themeSystem, 'Sistema');
      expect(en.themeSystem, 'System');

      expect(pt.unpairBtn, contains('Desconectar'));
      expect(en.unpairBtn, contains('Unpair'));

      expect(pt.updateAvailableTitle, contains('Atualização'));
      expect(en.updateAvailableTitle, contains('Update'));
      expect(pt.checkForUpdates, 'Verificar Atualizações');
      expect(en.checkForUpdates, 'Check for Updates');
      expect(pt.updateNow, 'Atualizar Agora');
      expect(en.updateNow, 'Update Now');
      expect(pt.appVersionLabel, 'Versão do App');
      expect(en.appVersionLabel, 'App Version');
    });

    testWidgets('AppStrings.of resolves correctly from context', (tester) async {
      late AppStrings resolvedStrings;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
          locale: const Locale('pt', 'BR'),
          home: Builder(
            builder: (ctx) {
              resolvedStrings = AppStrings.of(ctx);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedStrings.isPortuguese, isTrue);
      expect(resolvedStrings.navToday, 'Hoje');
    });
  });
}
