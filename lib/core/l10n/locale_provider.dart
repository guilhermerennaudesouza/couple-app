import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _kLocaleKey = 'app_locale';

/// Supported application locales.
const kLocalePtBr = Locale('pt', 'BR');
const kLocaleEnUs = Locale('en', 'US');

/// StateNotifier that manages and persists the current application [Locale].
///
/// Defaults to Portuguese (`pt-BR`) to ensure zero friction for Portuguese speakers,
/// while respecting any saved preference or device-detected Portuguese locale.
class LocaleNotifier extends StateNotifier<Locale> {
  final FlutterSecureStorage _storage;

  LocaleNotifier({
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        super(kLocalePtBr) {
    loadLocale();
  }

  bool get isPortuguese => state.languageCode == 'pt';

  /// Loads saved locale from storage, or auto-detects device locale.
  Future<void> loadLocale() async {
    try {
      final saved = await _storage.read(key: _kLocaleKey);
      if (saved == 'en_US' || saved == 'en') {
        state = kLocaleEnUs;
        return;
      } else if (saved == 'pt_BR' || saved == 'pt') {
        state = kLocalePtBr;
        return;
      }

      // If no preference saved, check platform locale
      final deviceLocale = ui.PlatformDispatcher.instance.locale;
      if (deviceLocale.languageCode == 'pt') {
        state = kLocalePtBr;
      } else {
        // Default to Portuguese as primary couple language request
        state = kLocalePtBr;
      }
    } catch (_) {
      state = kLocalePtBr;
    }
  }

  /// Sets and persists a new [Locale].
  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      final value = locale.languageCode == 'pt' ? 'pt_BR' : 'en_US';
      await _storage.write(key: _kLocaleKey, value: value);
    } catch (_) {
      // Ignored for storage failures
    }
  }

  /// Toggles between Portuguese (pt-BR) and English (en-US).
  Future<void> toggleLanguage() async {
    if (isPortuguese) {
      await setLocale(kLocaleEnUs);
    } else {
      await setLocale(kLocalePtBr);
    }
  }
}

/// Global provider for application [Locale].
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
