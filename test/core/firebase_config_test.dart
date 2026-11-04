import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/firebase/firebase_config.dart';
import 'package:couple_app/core/theme/app_theme.dart';

void main() {
  test('FirebaseConfig exposes spark tier offline settings', () {
    final settings = FirebaseConfig.firestoreSettings;
    expect(settings.persistenceEnabled, isTrue);
    expect(settings.cacheSizeBytes, greaterThan(0));
    expect(settings.cacheSizeBytes, equals(104857600));
  });

  test('AppTheme produces valid Material 3 theme configuration', () {
    final theme = AppTheme.themeData;
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, equals(AppTheme.primaryRose));
    expect(theme.scaffoldBackgroundColor, equals(AppTheme.backgroundLight));
  });
}
