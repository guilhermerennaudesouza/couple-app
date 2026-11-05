# In-App OTA Auto-Updater Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide seamless in-app checking, background downloading, and 1-tap installation of new application updates directly from GitHub Releases for sideloaded Samsung Galaxy devices.

**Architecture:** A standalone `AppUpdateService` inspects the local version via `package_info_plus`, checks the latest tag and asset URL on `api.github.com/repos/guilhermerennaudesouza/couple-app/releases/latest`, and streams the download progress and package installer intent using `ota_update`. The UI is presented via bilingual dialogs and a dedicated preferences section in `CoupleHubScreen`.

**Tech Stack:** Flutter 3.x, Dart, `ota_update`, `package_info_plus`, `http`, Android `REQUEST_INSTALL_PACKAGES`.

**Spec:** [Design Document in Chat](#design-document-in-app-ota-auto-updater-github-releases)

## Global Constraints

- 100% Free Spark Tier ($0 cost, zero paid cloud functions or external hosting).
- Default to Brazilian Portuguese (`pt-BR`) with full English (`en-US`) fallback.
- Support Android 14+ One UI on Samsung Galaxy S22 Ultra and Galaxy S24 Plus.
- Non-blocking: Network failures when contacting GitHub API must fail silently or gracefully without crashing the app.
- Never download updates on metered networks without explicit user tap.

## Review Focus

- Malformed / rate-limited GitHub API responses handled gracefully without throwing unhandled exceptions.
- Semantic version comparison accurately handles suffixes, e.g., `v1.0.1` vs `1.0.0+1`.
- Android `REQUEST_INSTALL_PACKAGES` permission declared in `AndroidManifest.xml`.
- In-progress downloads report percent progress and cancel cleanly if dismissed.
- Test suite and analyzer remain 100% clean (0 errors, 0 warnings).

---

### Task 1: Dependencies, Android Permissions & Bilingual Strings

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/core/l10n/app_strings.dart`
- Test: `test/core/l10n/app_strings_test.dart`

**Steps:**
- [ ] Add `ota_update: ^7.1.0`, `package_info_plus: ^9.0.1`, and `http: ^1.6.0` to `pubspec.yaml`.
- [ ] Run `flutter pub get`.
- [ ] Add `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>` to `android/app/src/main/AndroidManifest.xml`.
- [ ] Add localized strings to `AppStrings`:
  - `updateAvailableTitle`: `'Nova Atualização Disponível!'` / `'New Update Available!'`
  - `updateAvailableBody`: `'Uma nova versão ({version}) está disponível. Deseja atualizar agora?'` / `'A new version ({version}) is available. Would you like to update now?'`
  - `updateNow`: `'Atualizar Agora'` / `'Update Now'`
  - `updateLater`: `'Depois'` / `'Later'`
  - `updateChecking`: `'Verificando atualizações...'` / `'Checking for updates...'`
  - `updateUpToDate`: `'Você já está na versão mais recente!'` / `'You are on the latest version!'`
  - `updateDownloading`: `'Baixando atualização: {progress}%'` / `'Downloading update: {progress}%'`
  - `updateError`: `'Não foi possível baixar a atualização. Tente novamente mais tarde.'` / `'Could not download update. Please try again later.'`
  - `checkForUpdates`: `'Verificar Atualizações'` / `'Check for Updates'`
  - `appVersionLabel`: `'Versão do App'` / `'App Version'`
- [ ] Update `test/core/l10n/app_strings_test.dart` to verify new string keys.
- [ ] Run `flutter test test/core/l10n/app_strings_test.dart`.
- [ ] Commit: `feat(l10n): add update strings and Android package install permission`.

---

### Task 2: AppUpdateService Implementation & Unit Tests

**Files:**
- Create: `lib/core/services/app_update_service.dart`
- Create: `test/core/services/app_update_service_test.dart`

**Steps:**
- [ ] Write unit tests in `test/core/services/app_update_service_test.dart` verifying:
  - `isUpdateAvailable('1.0.0', 'v1.0.1')` returns `true`.
  - `isUpdateAvailable('1.0.1', 'v1.0.1')` returns `false`.
  - `isUpdateAvailable('1.1.0', 'v1.0.5')` returns `false`.
  - Parsing of GitHub Releases JSON payload extracts `tag_name` and `browser_download_url` for `CoupleApp-Release.apk`.
  - Graceful handling of network timeout / HTTP errors.
- [ ] Implement `AppUpdateService`:
  - `Future<AppUpdateInfo?> checkForUpdate({http.Client? client})`
  - `Stream<OtaEvent> startOtaUpdate(String downloadUrl)`
  - Class `AppUpdateInfo(String currentVersion, String latestVersion, String downloadUrl, String? releaseNotes)`
  - Semver comparison logic `isVersionNewer(String current, String latest)`
- [ ] Run `flutter test test/core/services/app_update_service_test.dart` to confirm all pass.
- [ ] Commit: `feat(services): implement AppUpdateService for GitHub OTA updates`.

---

### Task 3: UI Integration in CoupleHubScreen

**Files:**
- Modify: `lib/main.dart` (or `CoupleHubScreen` in `lib/main.dart`)
- Test: `test/e2e/couple_flow_smoke_test.dart`

**Steps:**
- [ ] In `CoupleHubScreen`, add state management for checking updates and active OTA download status.
- [ ] In `CoupleHubScreen._buildPreferencesSection`:
  - Add a "Versão do App" tile showing the installed version (e.g., `v1.0.0+1`).
  - Add a "Verificar Atualizações" button with a loading spinner while checking.
  - If already up-to-date, show a quick snackbar / toast confirming `updateUpToDate`.
- [ ] Implement `_showUpdateDialog(AppUpdateInfo updateInfo)`:
  - Modal with title, version number, release notes if available, and "Atualizar Agora" / "Depois" buttons.
  - When "Atualizar Agora" is tapped, display an in-modal progress bar showing the live percentage from `startOtaUpdate`.
- [ ] Add an automatic check on first build of `CoupleHubScreen` (flag `_hasCheckedUpdateOnLaunch`) to prompt if an update is found.
- [ ] Run `flutter test` to ensure existing smoke tests and hub tests pass.
- [ ] Commit: `feat(ui): add in-app update check and download dialog to CoupleHubScreen`.

---

### Task 4: End-to-End Verification, Analyzer & Build

**Files:**
- Modify: `android/app/build.gradle` (if needed for Gradle/packaging)
- Verify: `lib/` and `test/`

**Steps:**
- [ ] Run `flutter analyze lib/` to verify 0 errors and 0 warnings.
- [ ] Run full test suite `flutter test` (all 140+ tests pass).
- [ ] Rebuild release APK:
  `flutter build apk --release --split-per-abi --android-skip-build-dependency-validation`
- [ ] Copy fresh APK to `CoupleApp-Release.apk`.
- [ ] Commit & push to GitHub `master`.
- [ ] Update GitHub release `v1.0.0` or draft instructions for publishing `v1.0.1` when ready.
