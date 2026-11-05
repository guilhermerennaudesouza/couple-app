import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _kThemeModeKey = 'app_theme_mode';

/// StateNotifier that manages and persists the current application [ThemeMode].
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final FlutterSecureStorage _storage;

  ThemeModeNotifier({
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        super(ThemeMode.system) {
    loadThemeMode();
  }

  /// Loads saved theme mode from storage.
  Future<void> loadThemeMode() async {
    try {
      final saved = await _storage.read(key: _kThemeModeKey);
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'light') {
        state = ThemeMode.light;
      } else {
        state = ThemeMode.system;
      }
    } catch (_) {
      state = ThemeMode.system;
    }
  }

  /// Sets and persists a new [ThemeMode].
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final value = mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system';
      await _storage.write(key: _kThemeModeKey, value: value);
    } catch (_) {
      // Ignored for storage failures
    }
  }
}

/// Global provider for application [ThemeMode].
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
