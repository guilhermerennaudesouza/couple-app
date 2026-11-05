import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/theme/app_theme.dart';

void main() {
  group('AppTheme Dark Mode Contrast Tests', () {
    test('textSecondaryDark has high luminance and WCAG contrast on dark backgrounds', () {
      // Backgrounds in Dark Mode
      const bgDark = AppTheme.backgroundDark;
      const surfaceDark = AppTheme.surfaceDark;
      const textSecondaryDark = AppTheme.textSecondaryDark;

      // Verify textSecondaryDark luminance is >= 0.70 (bright off-white / silver, not dim brownish grey)
      expect(textSecondaryDark.computeLuminance(), greaterThan(0.70));

      // Calculate relative contrast ratio: (L1 + 0.05) / (L2 + 0.05)
      final lText = textSecondaryDark.computeLuminance();
      final lBg = bgDark.computeLuminance();
      final contrastBg = (lText + 0.05) / (lBg + 0.05);

      final lSurface = surfaceDark.computeLuminance();
      final contrastSurface = (lText + 0.05) / (lSurface + 0.05);

      // Must exceed 7:1 (WCAG AAA standard for normal text)
      expect(contrastBg, greaterThan(7.0));
      expect(contrastSurface, greaterThan(7.0));
    });

    testWidgets('AppTheme adaptive helpers return correct color for brightness', (tester) async {
      late BuildContext lightCtx;
      late BuildContext darkCtx;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (ctx) {
              lightCtx = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(AppTheme.textPrimaryOf(lightCtx), AppTheme.textPrimaryLight);
      expect(AppTheme.textSecondaryOf(lightCtx), AppTheme.textSecondaryLight);
      expect(lightCtx.textPrimary, AppTheme.textPrimaryLight);
      expect(lightCtx.textSecondary, AppTheme.textSecondaryLight);
      expect(lightCtx.isDarkMode, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('dark_app'),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Builder(
            key: const ValueKey('dark_builder'),
            builder: (ctx) {
              darkCtx = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(AppTheme.textPrimaryOf(darkCtx), AppTheme.textPrimaryDark);
      expect(AppTheme.textSecondaryOf(darkCtx), AppTheme.textSecondaryDark);
      expect(darkCtx.textPrimary, AppTheme.textPrimaryDark);
      expect(darkCtx.textSecondary, AppTheme.textSecondaryDark);
      expect(darkCtx.isDarkMode, isTrue);
    });

    test('darkTheme textTheme has high contrast defaults', () {
      final theme = AppTheme.darkTheme;
      expect(theme.textTheme.bodyMedium?.color, AppTheme.textSecondaryDark);
      expect(theme.textTheme.bodyLarge?.color, AppTheme.textPrimaryDark);
      expect(theme.colorScheme.onSurfaceVariant, AppTheme.textSecondaryDark);
    });
  });
}
