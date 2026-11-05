# Dark Mode Contrast & Bilingual Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:**
1. Fix Dark Mode contrast across all screens by replacing hardcoded light text colors with adaptive theme-aware styling and brightening `textSecondaryDark` to WCAG AAA compliant off-white/silver (`0xFFE5DEE1`).
2. Implement bilingual localization (Brazilian Portuguese `pt-BR` and English `en-US`), defaulting to Brazilian Portuguese so Naoma has immediate native support, with persisted language switching.
3. Add Theme Mode toggle (Light, Dark, System Default) and Language toggle in Settings (Couple Hub) and on the Pairing Screen.
4. Update question bank and curated date ideas with Portuguese translations.
5. Recompile and verify the production release APK for Galaxy S22 Ultra & Galaxy S24 Plus.

---

### Task 1: Dark Mode Contrast Fix & Adaptive Theme Helpers

- [ ] **Step 1: Write unit tests for adaptive colors in `test/core/theme/app_theme_test.dart`**
  - Verify `AppTheme.textSecondaryDark` has high luminance / contrast (> 7:1 against `backgroundDark` and `surfaceDark`).
  - Verify `AppTheme.darkTheme.textTheme` properly sets high-contrast colors on body and title styles.
  - Verify `AppTheme.textPrimaryOf(context)` and `AppTheme.textSecondaryOf(context)` return dark or light colors based on brightness.
- [ ] **Step 2: Update `lib/core/theme/app_theme.dart`**
  - Brighten `textSecondaryDark` from `0xFFAFA3A9` to `0xFFE5DEE1` (89% luminance, WCAG AAA).
  - Add `textPrimaryOf(BuildContext context)` and `textSecondaryOf(BuildContext context)`.
  - Add `BuildContext` extension `ThemeContextExt` with getters: `isDarkMode`, `textPrimary`, `textSecondary`, `cardColor`, `outlineColor`.
  - Update `darkTheme` with full `textTheme` using `textPrimaryDark` and `textSecondaryDark`, `hintStyle`, and `onSurfaceVariant: textSecondaryDark`.
- [ ] **Step 3: Run theme tests and ensure pass**
  - Command: `flutter test test/core/theme/app_theme_test.dart`
- [ ] **Step 4: Commit theme improvements**
  - `git commit -am "fix(theme): brighten dark mode secondary text and add adaptive color helpers"`

---

### Task 2: State Providers for Theme & Locale with Persistence

- [ ] **Step 1: Write tests for `theme_provider` and `locale_provider` in `test/core/theme/theme_provider_test.dart` and `test/core/l10n/locale_provider_test.dart`**
  - Test initial values (locale defaults to `pt-BR`, theme defaults to `system`).
  - Test persistence read and write with `flutter_secure_storage`.
  - Test state change notifications.
- [ ] **Step 2: Implement `lib/core/theme/theme_provider.dart`**
  - Create `themeModeProvider` (`StateNotifier<ThemeMode>`) reading/writing key `'app_theme_mode'`.
- [ ] **Step 3: Implement `lib/core/l10n/locale_provider.dart`**
  - Create `localeProvider` (`StateNotifier<Locale>`) reading/writing key `'app_locale'`.
  - Default to `Locale('pt', 'BR')` when no preference is saved.
  - Provide quick methods `setLocale(Locale)`, `toggleLanguage()`.
- [ ] **Step 4: Run provider tests and ensure pass**
  - Command: `flutter test test/core/theme/theme_provider_test.dart test/core/l10n/locale_provider_test.dart`
- [ ] **Step 5: Commit providers**
  - `git commit -am "feat(core): add persisted themeModeProvider and localeProvider"`

---

### Task 3: Bilingual String Dictionary (`AppStrings`)

- [ ] **Step 1: Write test for string coverage in `test/core/l10n/app_strings_test.dart`**
  - Verify every string key exists in both English and Portuguese.
  - Verify date and number formatters support both locales.
- [ ] **Step 2: Create `lib/core/l10n/app_strings.dart`**
  - Define `AppStrings` with strongly-typed getters for all UI text across:
    - Navigation tabs: Today / Hoje, Tasks / Tarefas, Calendar / Calendário, Decide / Decidir, Hub / Espaço.
    - Hub & Settings: Space Details, Language, Theme, Light, Dark, System, Copy, Unpair, Feature Cards.
    - Pairing: Welcome, Create Space, Join Space, Invite Code, Partner Name, Anniversary, Connected.
    - Daily Questions: Daily Question, Partner Answered, Locked, Reveal, History.
    - Tasks: New Task, Categories (Chores, Shopping, Romance, Travel), Done.
    - Calendar: Add Event, Milestone, Date Night, Countdown.
    - Decide: Date Ideas, Spin Wheel, Filter, Budget.
    - Notes: Sticky Wall, Add Note, Pin to Widget.
    - Finance: Shared Expenses, Split 50/50, Piggy Bank, Target.
    - Memories: Milestones, Photos, Wishlist, Time Capsule.
    - Vault: Biometric Lock, AES-256 Secrets, Cheatsheet, Cards.
  - Expose helper `AppStrings.of(BuildContext context)` or Riverpod `appStringsProvider`.
- [ ] **Step 3: Run string tests and ensure pass**
  - Command: `flutter test test/core/l10n/app_strings_test.dart`
- [ ] **Step 4: Commit localization dictionary**
  - `git commit -am "feat(l10n): add comprehensive bilingual AppStrings dictionary"`

---

### Task 4: Translate Daily Questions Bank & Curated Date Ideas

- [ ] **Step 1: Write tests for localized prompt bank and date ideas in `test/features/daily_question/data/daily_question_repository_test.dart` and `test/features/decide/data/date_ideas_repository_test.dart`**
  - Verify Portuguese prompts exist for all question IDs.
  - Verify Portuguese curated date ideas exist.
- [ ] **Step 2: Update `daily_question_repository.dart`**
  - Provide bilingual prompts: `{ 'en': '...', 'pt': '...' }` or localized getter based on active locale.
- [ ] **Step 3: Update `date_ideas_repository.dart`**
  - Provide bilingual date ideas: English and Portuguese titles/descriptions.
- [ ] **Step 4: Run repository tests and ensure pass**
  - Command: `flutter test test/features/daily_question/ test/features/decide/`
- [ ] **Step 5: Commit translated content**
  - `git commit -am "feat(content): add Portuguese translations for prompt bank and date ideas"`

---

### Task 5: Wire `lib/main.dart` & `CoupleHubScreen` to Adaptive Colors, Strings & Toggles

- [ ] **Step 1: Update `CoupleApp` in `lib/main.dart`**
  - Convert to `ConsumerWidget`.
  - Connect `themeMode: ref.watch(themeModeProvider)` and `locale: ref.watch(localeProvider)`.
  - Add `supportedLocales` and `localizationsDelegates`.
- [ ] **Step 2: Update `MainNavigationShell` in `lib/main.dart`**
  - Localize bottom navigation labels using `AppStrings.of(context)`.
- [ ] **Step 3: Update `CoupleHubScreen` in `lib/main.dart`**
  - Replace all hardcoded `AppTheme.textPrimaryLight` and `AppTheme.textSecondaryLight` with `context.textPrimary` and `context.textSecondary`.
  - Add "PREFERÊNCIAS / PREFERENCES" section with:
    - Language switcher toggle (🇧🇷 Português / 🇺🇸 English).
    - Theme switcher segmented button (☀️ Claro, 🌙 Escuro, ⚙️ Sistema).
  - Localize all labels, titles, buttons, and unpair dialogs.
- [ ] **Step 4: Run smoke tests and widget tests**
  - Command: `flutter test test/e2e/couple_flow_smoke_test.dart`
- [ ] **Step 5: Commit `main.dart` updates**
  - `git commit -am "feat(ui): add theme and language toggles in Hub and fix dark mode contrast in shell"`

---

### Task 6: Audit and Update All Feature Screens for Dark Mode Contrast & Strings

- [ ] **Step 1: Update `lib/features/auth/presentation/pairing_screen.dart`**
  - Replace hardcoded `textSecondaryLight` and `textPrimaryLight` with adaptive text colors.
  - Add quick language toggle button in AppBar so Naoma can toggle language immediately on first run.
  - Localize all strings with `AppStrings`.
- [ ] **Step 2: Update `lib/features/daily_question/presentation/daily_question_screen.dart`**
  - Replace hardcoded grey colors with adaptive text colors.
  - Localize UI strings and prompt displays.
- [ ] **Step 3: Update `lib/features/tasks/presentation/tasks_screen.dart` & `lib/features/calendar/presentation/calendar_screen.dart`**
  - Replace hardcoded grey colors with adaptive text colors.
  - Localize strings.
- [ ] **Step 4: Update `lib/features/decide/presentation/decide_screen.dart` & `lib/features/notes/presentation/notes_screen.dart`**
  - Replace hardcoded grey colors with adaptive text colors.
  - Localize strings.
- [ ] **Step 5: Update `lib/features/finance/presentation/finance_screen.dart`, `lib/features/memories/presentation/memories_screen.dart`, `lib/features/vault/presentation/vault_screen.dart`**
  - Replace hardcoded grey colors with adaptive text colors.
  - Localize strings.
- [ ] **Step 6: Run full test suite**
  - Command: `flutter test`
- [ ] **Step 7: Commit all screen updates**
  - `git commit -am "fix(screens): resolve dark mode contrast issues and localize all feature screens"`

---

### Task 7: Full Verification & Release APK Compilation

- [ ] **Step 1: Run complete unit & widget test suite**
  - Command: `flutter test` (all tests passing).
- [ ] **Step 2: Build release APK locally with Flutter SDK**
  - Command: `& "C:\src\flutter\bin\flutter.bat" build apk --release --split-per-abi --android-skip-build-dependency-validation`
- [ ] **Step 3: Copy output APK to `E:\Couple App\CoupleApp-Release.apk`**
  - Verify size, architecture (`app-arm64-v8a-release.apk`), and file presence.
- [ ] **Step 4: Commit and present to user**
  - Inform user with clear sideload instructions for Galaxy S22 Ultra and Galaxy S24 Plus.
