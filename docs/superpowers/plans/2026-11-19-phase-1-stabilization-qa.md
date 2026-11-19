# Fase 1 — Estabilização & QA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate every confirmed functional, concurrency, cryptography, notification, and Android Glance widget bug in Couple App (`v1.0.7+8`) while preserving 100% compatibility with existing couple data on Firebase's free Spark tier.

**Architecture:** Fix root causes layer-by-layer with pure testable helpers first (`CoupleDateUtils`, `parseBrlCurrency`, canonical UID), then harden Firestore repositories with atomic transactions and schema-safe migrations (UID alias migration, Vault PIN sentinel with legacy backfill, Firestore 1 MB photo guard), followed by screen QA fixes, Android notification receivers/timezone/deep-linking, and clickable non-blocking Jetpack Glance widgets.

**Tech Stack:** Flutter 3.x (Dart >=3.3.0), Riverpod 2.6, Cloud Firestore 5.x (Spark offline cache), `cryptography` (AES-256-GCM / PBKDF2), `flutter_local_notifications` + `flutter_timezone`, `qr_flutter` + `mobile_scanner`, `home_widget`, Android Kotlin Jetpack Glance 1.0.0 (`compileSdk 36`, `minSdk 24`).

**Spec:** [2026-11-19-krivo-parity-and-stabilization-design.md](file:///e:/Couple%20App/docs/superpowers/specs/2026-11-19-krivo-parity-and-stabilization-design.md) (Section 5 — Fase 1)

## Global Constraints

- Firebase Free Spark Tier ($0 forever): no Cloud Functions, no paid push servers, no Firebase Storage bucket required; Firestore document hard limit is 1 MB.
- Android-first targeting Samsung Galaxy S22 Ultra & S24 Plus (One UI, Android 14/15, `minSdk 24`, `targetSdk 36`, `release.keystore` preserved for OTA).
- Backward compatibility with existing couple Firestore documents: zero destructive schema breaks or data loss for paired couples.
- Brazilian Portuguese (`pt_BR`) is the primary locale (with `en_US` fallback); keep `flutter test` green and `flutter analyze` free of errors/warnings.

## Review Focus

1. **Brazilian currency edge inputs:** `parseBrlCurrency` receiving `"1.250,50"`, `"R$ 89,90"`, `"150,50"`, `"150.50"`, `""`, or `"abc"` must parse exact BRL decimals or return `null` without inflating by 100x. *(Test pinned in Task 1)*
2. **Midnight / DST boundary date math:** `CoupleDateUtils.daysTogether` and `isDateOverdue` evaluated at `23:55` vs `00:05` local time and with future anniversary dates must never drift by ±1 day or return negative days. *(Test pinned in Task 1)*
3. **Zero 9-day prompt collisions:** `DailyQuestionRepository.getPromptForDate` over 50 consecutive dates (explicitly covering `YYYY-MM-03`, `YYYY-MM-12`, `YYYY-MM-21`) must yield 50 distinct prompts before any repetition. *(Test pinned in Task 3)*
4. **Legacy Vault sentinel backfill safety:** When `vault_meta/config` is missing but `vault_items` already exist, entering a mismatched PIN must fail and NEVER overwrite/create a bogus sentinel; entering the valid PIN must decrypt an existing item and backfill `vault_meta/config`. *(Test pinned in Task 6)*
5. **Scratch-card widget spoiler protection:** Pinning an un-scratched scratch card (`isScratchCard == true && isScratched == false`) must pass masked text (`"🎁 Recado surpresa! Toque para raspar ✨"`) to `NoteGlanceWidget` and never leak `note.content`. *(Test pinned in Task 9)*

---

## File Structure Overview

- **Create:**
  - `lib/core/utils/couple_date_utils.dart` — single source of truth for `daysTogether`, `isDateOverdue`, `isDateToday`, `formatDateKey`.
  - `lib/core/utils/currency_parser.dart` — `parseBrlCurrency(String input)` for PT-BR and EN numeric inputs.
  - `lib/core/utils/current_date_provider.dart` — reactive `currentDateKeyProvider` updating on app resume and midnight rollover.
  - `lib/core/utils/photo_budget_utils.dart` — Firestore 1 MB guard (`maxPhotosPerDoc = 4`, `maxTotalBase64Bytes = 850 * 1024`) + simple LRU `Uint8List` Base64 decode cache.
  - `lib/core/notifications/notification_route_provider.dart` — `pendingNotificationRouteProvider` shared by local notifications and Android Glance widget taps.
  - `lib/features/vault/domain/vault_config_model.dart` — `VaultConfigModel` for `/couples/{coupleId}/vault_meta/config` sentinel verification.
  - `test/core/utils/couple_utils_test.dart`, `test/features/vault/vault_sentinel_test.dart`, `test/features/cycle/cycle_upgrade_test.dart`
- **Modify:**
  - `pubspec.yaml` (`qr_flutter`, `mobile_scanner`, `flutter_timezone`)
  - `lib/features/auth/domain/couple_model.dart`, `lib/features/auth/data/pairing_repository.dart`, `lib/features/auth/presentation/pairing_screen.dart`
  - `lib/features/daily_question/data/daily_question_repository.dart`, `lib/features/daily_question/presentation/daily_question_screen.dart`
  - `lib/features/decide/data/decide_repository.dart`, `lib/features/finance/data/finance_repository.dart`
  - `lib/features/wishlist/domain/wish_model.dart`, `lib/features/memories/data/memories_repository.dart`, `lib/features/memories/presentation/memories_screen.dart`
  - `lib/core/crypto/vault_crypto_service.dart`, `lib/features/vault/data/vault_repository.dart`, `lib/features/vault/presentation/vault_screen.dart`
  - `lib/features/tasks/data/task_repository.dart`, `lib/features/tasks/presentation/tasks_screen.dart`, `lib/features/calendar/presentation/calendar_screen.dart`
  - `lib/features/notes/domain/note_model.dart`, `lib/features/notes/presentation/notes_screen.dart`
  - `lib/features/loyalty/presentation/loyalty_screen.dart`, `lib/features/adult_games/data/adult_games_repository.dart`, `lib/features/adult_games/presentation/adult_games_screen.dart`
  - `lib/features/cycle/domain/cycle_model.dart`, `lib/features/cycle/data/cycle_repository.dart`, `lib/features/cycle/presentation/cycle_screen.dart`
  - `lib/features/stats/presentation/couple_stats_screen.dart`
  - `lib/core/notifications/local_notification_service.dart`, `lib/main.dart`, `android/app/src/main/AndroidManifest.xml`
  - `lib/features/widgets/widget_sync_service.dart`, `android/app/src/main/kotlin/com/personal/couple_app/{MainActivity,CoupleGlanceWidget,DailyPromptGlanceWidget,NoteGlanceWidget,TasksGlanceWidget}.kt`

---

### Task 1: Shared Date/Currency Utilities & Canonical UID Provider

**Files:**
- Create: `lib/core/utils/couple_date_utils.dart`
- Create: `lib/core/utils/currency_parser.dart`
- Modify: `lib/features/auth/data/pairing_repository.dart:30-37,218-230`
- Test: `test/core/utils/couple_utils_test.dart`

**Interfaces:**
- Consumes: `FirebaseAuth.instance`
- Produces:
  - `CoupleDateUtils.daysTogether(DateTime anniversary, {DateTime? now}) -> int`
  - `CoupleDateUtils.isDateOverdue(DateTime dueDate, {DateTime? now}) -> bool`
  - `CoupleDateUtils.isDateToday(DateTime date, {DateTime? now}) -> bool`
  - `CoupleDateUtils.formatDateKey(DateTime date) -> String` (`YYYY-MM-DD`)
  - `parseBrlCurrency(String raw) -> double?`
  - `currentUserUidProvider` (`StreamProvider<String?>` in `pairing_repository.dart`)

- [ ] **Step 1: Write failing tests for `CoupleDateUtils` and `parseBrlCurrency`**

Create `test/core/utils/couple_utils_test.dart` testing:
```dart
test('parseBrlCurrency parses Brazilian and decimal inputs accurately', () {
  expect(parseBrlCurrency('150,50'), 150.50);
  expect(parseBrlCurrency('1.250,90'), 1250.90);
  expect(parseBrlCurrency('R\$ 89,90'), 89.90);
  expect(parseBrlCurrency('150.50'), 150.50);
  expect(parseBrlCurrency('1200'), 1200.0);
  expect(parseBrlCurrency(''), isNull);
  expect(parseBrlCurrency('abc'), isNull);
});

test('CoupleDateUtils.daysTogether normalizes date boundaries and clamps future dates', () {
  final anniv = DateTime(2025, 11, 18, 23, 55);
  expect(CoupleDateUtils.daysTogether(anniv, now: DateTime(2025, 11, 19, 0, 5)), 1);
  expect(CoupleDateUtils.daysTogether(DateTime(2027, 1, 1), now: DateTime(2026, 11, 19)), 0);
});

test('CoupleDateUtils.isDateOverdue does not flag tasks due today as overdue', () {
  final now = DateTime(2026, 11, 19, 18, 30);
  expect(CoupleDateUtils.isDateOverdue(DateTime(2026, 11, 19, 0, 0), now: now), isFalse);
  expect(CoupleDateUtils.isDateToday(DateTime(2026, 11, 19, 0, 0), now: now), isTrue);
  expect(CoupleDateUtils.isDateOverdue(DateTime(2026, 11, 18, 23, 59), now: now), isTrue);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/utils/couple_utils_test.dart`
Expected: FAIL (missing files/symbols).

- [ ] **Step 3: Implement `CoupleDateUtils`, `parseBrlCurrency`, and `currentUserUidProvider`**

- In `lib/core/utils/couple_date_utils.dart`: implement `daysTogether` using UTC-normalized `(year, month, day)` clamped `>= 0`; `isDateOverdue` comparing date-only `DateTime(y, m, d).isBefore(todayMidnight)`; `isDateToday`; and `formatDateKey`.
- In `lib/core/utils/currency_parser.dart`: implement `parseBrlCurrency(String raw)` stripping whitespace/currency symbols, handling both `,` decimal (`1.250,90` → remove `.` then replace `,` with `.`) and `.` decimal (`150.50`), returning `null` if invalid or `< 0`.
- In `lib/features/auth/data/pairing_repository.dart`: add `final currentUserUidProvider = StreamProvider<String?>((ref) => FirebaseAuth.instance.authStateChanges().map((u) => u?.uid));` (safely catching uninitialized Firebase in unit tests by returning `Stream.value(null)`).

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/core/utils/couple_utils_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/couple_date_utils.dart lib/core/utils/currency_parser.dart lib/features/auth/data/pairing_repository.dart test/core/utils/couple_utils_test.dart
git commit -m "feat(core): add CoupleDateUtils, BRL currency parser, and canonical UID provider"
```

---

### Task 2: Pairing Transactions, UID History Migration, Real QR Code & Clean Unpair

**Files:**
- Modify: `pubspec.yaml` (add `qr_flutter: ^4.1.0`, `mobile_scanner: ^6.0.2`)
- Modify: `lib/features/auth/domain/couple_model.dart:5-136`
- Modify: `lib/features/auth/data/pairing_repository.dart:77-216`
- Modify: `lib/features/auth/presentation/pairing_screen.dart:70-85,455-565,720-791`
- Modify: `lib/main.dart:300-483,992-1035`
- Test: `test/features/auth/pairing_repository_test.dart`

**Interfaces:**
- Consumes: `currentUserUidProvider`, `WidgetSyncService.clearGlanceNote`, `LocalNotificationService.cancelAll`
- Produces:
  - `CoupleModel.uidAliases` (`Map<String, String>`) and `CoupleModel.resolveCanonicalUid(String uid) -> String`
  - `PairingRepository.parseInviteCodeFromQr(String raw) -> String?` (extracts 6-digit code from `coupleapp://join?code=123456` or raw `"123456"`)
  - `PairingRepository.migratePartnerUid(String coupleId, {required String oldUid, required String newUid}) -> Future<void>`
  - `PairingRepository.unpairCurrentUser(String coupleId, String uid) -> Future<void>`

- [ ] **Step 1: Add dependencies `qr_flutter` and `mobile_scanner` to `pubspec.yaml` and run `flutter pub get`**

Run: `flutter pub get`
Expected: Exits 0 without dependency conflicts.

- [ ] **Step 2: Write failing tests in `test/features/auth/pairing_repository_test.dart`**

Add tests for:
- `CoupleModel.fromMap` / `toMap` preserving `uidAliases` and defaulting to `{}` on legacy maps without `uidAliases`.
- `CoupleModel.resolveCanonicalUid(oldUid)` returning `newUid` when aliased and returning `uid` when unaliased.
- `PairingRepository.parseInviteCodeFromQr('coupleapp://join?code=482910') == '482910'`, `parseInviteCodeFromQr('482910') == '482910'`, and `parseInviteCodeFromQr('invalid') == null`.

- [ ] **Step 3: Run tests to verify failure**

Run: `flutter test test/features/auth/pairing_repository_test.dart`
Expected: FAIL on missing `uidAliases` and `parseInviteCodeFromQr`.

- [ ] **Step 4: Implement `CoupleModel.uidAliases`, transactional `joinCouple` + `migratePartnerUid` + `unpairCurrentUser`, real QR UI, and `otaSub` cleanup**

- In `lib/features/auth/domain/couple_model.dart`: add `final Map<String, String> uidAliases;` (default `const {}`), `resolveCanonicalUid(String uid)`, serialize/deserialize safely, update `copyWith`, `==`, `hashCode`.
- In `lib/features/auth/data/pairing_repository.dart`:
  - Add `static String? parseInviteCodeFromQr(String raw)`.
  - Wrap `joinCouple` update in `_firestore.runTransaction(...)`, checking `couple.isFull` inside the transaction; on name-match rejoin, record `uidAliases[oldUid] = uid` and call `await migratePartnerUid(couple.id, oldUid: oldUid, newUid: uid)` after transaction commits.
  - Implement `migratePartnerUid(coupleId, oldUid:, newUid:)`: best-effort batched updates across `daily_questions` (`answers` key move), `tasks` (`assignedTo`), `finance_entries` (`paidByUid`, `customShares`), `notes` (`authorUid`), `decide_sessions` (`votes` key move), `wishlist` (`createdBy`, `purchasedBy`), and `partner_cheatsheet/{oldUid}` copy-then-delete to `{newUid}`.
  - Implement `unpairCurrentUser(coupleId, uid)`: attempts `FieldValue.arrayRemove([uid])` on `/couples/{coupleId}` inside try/catch, then always calls `clearCurrentCoupleId()` and `LocalNotificationService.cancelAll()`.
- In `lib/features/auth/presentation/pairing_screen.dart`:
  - Remove `'user_${DateTime.now().millisecondsSinceEpoch}'` fallback: ensure `FirebaseAuth.instance.signInAnonymously()` succeeds before creating/joining, showing a clear PT-BR retry error if offline/unauthenticated.
  - Replace `_StylizedQrPainter` (lines `548-561`, `722-791`) with `QrImageView(data: 'coupleapp://join?code=${currentCouple.inviteCode}', version: QrVersions.auto, size: 160)`.
  - Add an `"Escanear QR Code"` button on the Join tab that opens a modal `MobileScanner` sheet and populates the 6-digit code controller via `PairingRepository.parseInviteCodeFromQr`.
- In `lib/main.dart`:
  - Update `_confirmUnpair` to call `unpairCurrentUser(widget.coupleId, uid)` and `WidgetSyncService.clearGlanceNote()` (upgraded to `clearAllWidgets()` in Task 9).
  - Ensure `_showUpdateDialog` cancels `otaSub` in `showDialog(...).whenComplete(() => otaSub?.cancel())`.

- [ ] **Step 5: Run tests to verify pass**

Run: `flutter test test/features/auth/pairing_repository_test.dart test/e2e/couple_flow_smoke_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/auth/ lib/main.dart test/features/auth/pairing_repository_test.dart
git commit -m "fix(auth): transactional pairing, UID history migration, real QR scanner, and clean unpair"
```

---

### Task 3: Daily Question Stability (Zero-Repeat Hash, Midnight Rollover, Offline Reveal & Past Answers)

**Files:**
- Create: `lib/core/utils/current_date_provider.dart`
- Modify: `lib/features/daily_question/data/daily_question_repository.dart:135-345`
- Modify: `lib/features/daily_question/presentation/daily_question_screen.dart:56-75,180-250,1080-1155`
- Test: `test/features/daily_question/daily_question_test.dart`

**Interfaces:**
- Consumes: `CoupleDateUtils.formatDateKey`, `currentUserUidProvider`
- Produces:
  - `currentDateKeyProvider` (`StateNotifierProvider<CurrentDateKeyNotifier, String>`)
  - `DailyQuestionRepository.getPromptForDate(String dateString, {String? languageCode})` (epoch-indexed deterministic permutation)

- [ ] **Step 1: Write failing tests in `test/features/daily_question/daily_question_test.dart`**

Add tests:
```dart
test('getPromptForDate yields 50 distinct prompts over 50 consecutive days with no 9-day collisions', () {
  final start = DateTime.utc(2026, 11, 1);
  final seen = <String>{};
  for (int i = 0; i < 50; i++) {
    final key = DailyQuestionRepository.formatDate(start.add(Duration(days: i)));
    seen.add(DailyQuestionRepository.getPromptForDate(key, languageCode: 'pt'));
  }
  expect(seen.length, 50);
  expect(
    DailyQuestionRepository.getPromptForDate('2026-11-03', languageCode: 'pt'),
    isNot(DailyQuestionRepository.getPromptForDate('2026-11-12', languageCode: 'pt')),
  );
  expect(
    DailyQuestionRepository.getPromptForDate('2026-11-12', languageCode: 'pt'),
    isNot(DailyQuestionRepository.getPromptForDate('2026-11-21', languageCode: 'pt')),
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/daily_question/daily_question_test.dart`
Expected: FAIL (current ASCII sum produces massive collisions; `seen.length` << 50).

- [ ] **Step 3: Implement epoch permutation hash, `currentDateKeyProvider`, offline PT fallback, and past-question answer input**

- In `lib/core/utils/current_date_provider.dart`: create `CurrentDateKeyNotifier` observing `WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` and scheduling a `Timer` to next local midnight so `currentDateKeyProvider` updates automatically across `00:00`.
- In `lib/features/daily_question/data/daily_question_repository.dart`:
  - Replace ASCII fold in `getPromptForDate` with days since `DateTime.utc(2025, 1, 1)` multiplied by coprime stride (`(days * 17 + 7) % bank.length`, handling negative days safely via `((idx % n) + n) % n`) — since `gcd(17, 50) == 1`, it visits all 50 prompts without repeating while still feeling shuffled.
  - Make `todayDailyQuestionProvider` and `pastDailyQuestionsProvider` watch `currentDateKeyProvider` so the stream automatically re-subscribes to the new date at midnight.
  - In `submitAnswer` offline fallback (`L288-306`): pass `languageCode: 'pt'` to `getPromptForDate(questionId, languageCode: 'pt')` and do not overwrite an existing document's `prompt` if already cached (merge only `answers.{uid}` if doc exists locally).
- In `lib/features/daily_question/presentation/daily_question_screen.dart`:
  - Use `ref.watch(currentUserUidProvider).valueOrNull` instead of `'guest_uid'`.
  - In `_buildPastQuestionCard` (`L1115-1137`): when `!dq.isRevealed && !dq.hasUserAnswered(myUid)`, render a compact button `"Responder esta pergunta"` that opens a bottom sheet / inline field calling `submitAnswer(coupleId, dq.id, myUid, text)`.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/features/daily_question/`
Expected: PASS (note: if any existing test asserted a specific index from the old ASCII hash, update that test to assert determinism + non-empty membership in `defaultQuestionBankPt`).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/current_date_provider.dart lib/features/daily_question/ test/features/daily_question/
git commit -m "fix(daily-question): eliminate 9-day hash repeats, handle midnight rollover, and unlock past questions"
```

---

### Task 4: Decide Together Revote Fix & Transactional Voting + Finance Contribution Transaction

**Files:**
- Modify: `lib/features/decide/data/decide_repository.dart:76-178`
- Modify: `lib/features/finance/data/finance_repository.dart:69-115,160-201`
- Test: `test/features/decide/decide_model_test.dart`
- Test: `test/features/finance/finance_model_test.dart`

**Interfaces:**
- Produces:
  - `DecideRepository.resetSessionForRevote` (uses `docRef.update` to replace `votes` with `{}`)
  - `DecideRepository.castVote` (uses `_firestore.runTransaction` with offline merge fallback)
  - `FinanceRepository.addContribution` (uses `_firestore.runTransaction` with `FieldValue.increment` + `arrayUnion` offline fallback)

- [ ] **Step 1: Write failing unit tests verifying revote map replacement and `settledByUid` persistence**

In `test/features/decide/decide_model_test.dart` and `test/features/finance/finance_model_test.dart`, add pure-model/payload assertions (and repository helper tests if mockable) covering:
- `DecideSessionModel` resolved split-decision state transitioning back to open with empty `votes` map.
- `FinanceEntry` serialization preserving `settledByUid` when settled.

- [ ] **Step 2: Run tests**

Run: `flutter test test/features/decide/ test/features/finance/`
Expected: New `settledByUid` assertion FAILS until added.

- [ ] **Step 3: Fix `DecideRepository` and `FinanceRepository`**

- In `lib/features/decide/data/decide_repository.dart`:
  - Fix `resetSessionForRevote` (`L165-173`): use `await docRef.update({'votes': <String, String>{}, 'status': DecideSessionModel.statusOpen, 'resolvedAt': null, 'winningOption': null});` (with fallback to `set` with `SetOptions(mergeFields: ['votes', 'status', 'resolvedAt', 'winningOption'])` if needed).
  - Wrap `castVote` (`L76-134`) in `_firestore.runTransaction(...)` so simultaneous votes atomically compute `existingVotes.length >= 2`, `status = statusResolved`, and `winningOption`, keeping the existing `set(..., SetOptions(merge: true))` as offline fallback.
- In `lib/features/finance/data/finance_repository.dart`:
  - Persist `'settledByUid': settledByUid` inside `settleAllBalances` (`L95-98, L105-108`) and add optional `settledByUid` field to `FinanceEntry`.
  - Wrap `addContribution` (`L160-195`) in `_firestore.runTransaction(...)` so concurrent deposits never overwrite each other, keeping the existing `FieldValue.increment` + `FieldValue.arrayUnion` offline fallback.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/features/decide/ test/features/finance/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/decide/ lib/features/finance/ test/features/decide/ test/features/finance/
git commit -m "fix(decide,finance): fix Firestore revote map clearing and add transactions for votes and savings"
```

---

### Task 5: Memories & Wishlist QA (BRL Price Fix, 1 MB Firestore Guard, Direct Spark Base64 & Decode Cache)

**Files:**
- Create: `lib/core/utils/photo_budget_utils.dart`
- Modify: `lib/features/wishlist/domain/wish_model.dart:136-188`
- Modify: `lib/features/memories/data/memories_repository.dart:81-106`
- Modify: `lib/features/memories/presentation/memories_screen.dart:35-65,1880-1920,2275-2315,2710-2735`
- Test: `test/core/utils/couple_utils_test.dart`

**Interfaces:**
- Consumes: `parseBrlCurrency` from Task 1
- Produces:
  - `PhotoBudgetUtils.maxPhotosPerDoc` (`4`)
  - `PhotoBudgetUtils.maxTotalBytes` (`850 * 1024`)
  - `PhotoBudgetUtils.canAddPhoto({required List<String> existingDataUris, required String candidateDataUri}) -> bool`
  - `PhotoBudgetUtils.decodeCachedBase64(String dataUri) -> Uint8List?` (LRU cache up to 40 images)

- [ ] **Step 1: Write failing tests for `PhotoBudgetUtils` and `WishModel`**

Add tests in `test/core/utils/couple_utils_test.dart`:
```dart
test('PhotoBudgetUtils enforces max 4 photos and 850KB Firestore document budget', () {
  final small = 'data:image/jpeg;base64,${'A' * 1000}';
  expect(PhotoBudgetUtils.canAddPhoto(existingDataUris: [small, small, small], candidateDataUri: small), isTrue);
  expect(PhotoBudgetUtils.canAddPhoto(existingDataUris: [small, small, small, small], candidateDataUri: small), isFalse);
  final huge = 'data:image/jpeg;base64,${'A' * (900 * 1024)}';
  expect(PhotoBudgetUtils.canAddPhoto(existingDataUris: const [], candidateDataUri: huge), isFalse);
});

test('WishModel parses Brazilian decimal prices and includes isSecretRadar in equality', () {
  final a = WishModel.fromMap('w1', {'title': 'Perfume', 'estimatedPrice': '150,50', 'isSecretRadar': true});
  final b = a.copyWith(isSecretRadar: false);
  expect(a.estimatedPrice, 150.50);
  expect(a == b, isFalse);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/couple_utils_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `PhotoBudgetUtils`, fix `WishModel`, remove Storage attempt in `MemoriesRepository`, and wire into `MemoriesScreen`**

- Create `lib/core/utils/photo_budget_utils.dart` with `canAddPhoto` (UTF-8 byte budget `<= 850 * 1024` and count `< 4`) and an LRU `LinkedHashMap<String, Uint8List>` cache (capacity 40) for `decodeCachedBase64`.
- In `lib/features/wishlist/domain/wish_model.dart`: delegate `_parsePrice` string parsing to `parseBrlCurrency` and include `isSecretRadar` and `occasion` in `==` and `hashCode`.
- In `lib/features/memories/data/memories_repository.dart`: make `uploadPhoto` return Base64 Data URI directly (Spark tier — avoids Storage timeout/retries).
- In `lib/features/memories/presentation/memories_screen.dart`:
  - Replace line `2718` (`replaceAll(RegExp(r'[^0-9.]'), '')`) with `parseBrlCurrency(_priceController.text)`.
  - Use `PhotoBudgetUtils.decodeCachedBase64` inside `buildPhotoThumbnail` (`L44-50`).
  - In `_AddMemorySheet._pickAndUploadPhoto` (`L1885`) and `_SealCapsuleSheet._pickAndUploadPhoto` (`L2279`): compress (`maxWidth: 960, maxHeight: 960, imageQuality: 65`) and check `PhotoBudgetUtils.canAddPhoto` before appending, showing a clear PT-BR `SnackBar` if max 4 photos or 850 KB limit is reached.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/core/utils/couple_utils_test.dart test/e2e/couple_flow_smoke_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/photo_budget_utils.dart lib/features/wishlist/ lib/features/memories/ test/core/utils/couple_utils_test.dart
git commit -m "fix(memories,wishlist): fix BRL decimal parsing, enforce 1MB Firestore photo budget, and cache Base64 decode"
```

---

### Task 6: Private Vault Shared PIN Sentinel, Safe Legacy Upgrade, Change/Reset PIN & Isolate PBKDF2

**Files:**
- Create: `lib/features/vault/domain/vault_config_model.dart`
- Modify: `lib/core/crypto/vault_crypto_service.dart:80-115`
- Modify: `lib/features/vault/data/vault_repository.dart:1-75`
- Modify: `lib/features/vault/presentation/vault_screen.dart:80-365,1115-1140,1605-1635`
- Test: `test/features/vault/vault_sentinel_test.dart`

**Interfaces:**
- Consumes: `VaultCryptoService` (`deriveKey`, `encrypt`, `decrypt`)
- Produces:
  - `VaultConfigModel` (`sentinel: EncryptedVaultPayload`, `updatedAt: DateTime`) with `static const sentinelPlaintext = 'KRIVO_VAULT_OK_V1'`
  - `VaultPinMode` enum: `createNew`, `unlockSentinel`, `legacyBackfill`
  - `VaultRepository.resolveVaultPinMode(String coupleId) -> Future<VaultPinMode>`
  - `VaultRepository.getVaultConfig(String coupleId) -> Future<VaultConfigModel?>`
  - `VaultRepository.saveVaultConfig(String coupleId, VaultConfigModel config) -> Future<void>`
  - `VaultRepository.reencryptAllItemsAndSentinel(String coupleId, {required List<VaultItemModel> reencryptedItems, required VaultConfigModel newConfig}) -> Future<void>`
  - `VaultRepository.resetVault(String coupleId) -> Future<void>`

- [ ] **Step 1: Write failing tests in `test/features/vault/vault_sentinel_test.dart`**

Test:
```dart
test('VaultCryptoService verifies sentinel with matching PIN and rejects wrong PIN', () async {
  final crypto = VaultCryptoService();
  final salt = 'krivo_vault_salt_couple1';
  final key1 = await crypto.deriveKey(pin: '123456', salt: salt);
  final key2 = await crypto.deriveKey(pin: '654321', salt: salt);
  final sentinel = await crypto.encrypt(plaintext: VaultConfigModel.sentinelPlaintext, key: key1);
  expect(await crypto.decrypt(payload: sentinel, key: key1), VaultConfigModel.sentinelPlaintext);
  expect(() => crypto.decrypt(payload: sentinel, key: key2), throwsA(isA<VaultCryptoException>()));
});

test('VaultPinMode resolution enforces legacy backfill when items exist without sentinel', () {
  expect(VaultConfigModel.resolveMode(hasConfig: true, hasExistingItems: true), VaultPinMode.unlockSentinel);
  expect(VaultConfigModel.resolveMode(hasConfig: false, hasExistingItems: true), VaultPinMode.legacyBackfill);
  expect(VaultConfigModel.resolveMode(hasConfig: false, hasExistingItems: false), VaultPinMode.createNew);
});
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/features/vault/vault_sentinel_test.dart`
Expected: FAIL (missing `VaultConfigModel`).

- [ ] **Step 3: Implement `Isolate.run` PBKDF2, `VaultConfigModel`, `VaultRepository` sentinel/reset/reencrypt methods, and `VaultScreen` lock flow**

- In `lib/core/crypto/vault_crypto_service.dart`: run PBKDF2 `deriveKey` via `Isolate.run(...)` when using default `_pbkdf2` so 100k iterations never drop UI frames.
- Create `lib/features/vault/domain/vault_config_model.dart` with `VaultPinMode`, `VaultConfigModel`, and `static VaultPinMode resolveMode({required bool hasConfig, required bool hasExistingItems})`.
- In `lib/features/vault/data/vault_repository.dart`: add `/couples/{coupleId}/vault_meta/config` read/write, `resolveVaultPinMode`, `reencryptAllItemsAndSentinel` (atomic `WriteBatch`), and `resetVault` (deletes all `vault_items` + `vault_meta/config` in batch).
- In `lib/features/vault/presentation/vault_screen.dart`:
  - Replace local-only `_hasStoredPin` detection in `_checkSecuritySetup` with `resolveVaultPinMode(coupleId)`:
    - `createNew`: confirm PIN twice → derive key → encrypt sentinel → save `vault_meta/config` + cache locally.
    - `unlockSentinel`: verify entered PIN by decrypting `vault_meta/config.sentinel == 'KRIVO_VAULT_OK_V1'` (and on biometric unlock, also verify cached key against sentinel!).
    - `legacyBackfill`: prompt *"Digite o PIN atual do Cofre"* → verify by decrypting the first existing `VaultItemModel` → only if decryption succeeds, write `vault_meta/config` sentinel and unlock; if wrong PIN, show error and never create sentinel.
  - Add **"Alterar PIN"** action in unlocked AppBar (asks current PIN, new PIN + confirm, decrypts all items, re-encrypts with new key + new sentinel via `reencryptAllItemsAndSentinel`, updates local cache).
  - Add **"Resetar Cofre"** link on the lock screen requiring two explicit confirmations (*"Todos os itens criptografados serão apagados permanentemente"*) calling `resetVault(coupleId)` + clearing local keys.
  - Dispose all `TextEditingController`s in `_showAddVaultItemSheet` and `_showEditCheatsheetSheet` via `whenComplete`, and remove `'user_uid'`/`'partner_uid'` fallbacks.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/features/vault/vault_sentinel_test.dart test/core/vault_crypto_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/crypto/vault_crypto_service.dart lib/features/vault/ test/features/vault/vault_sentinel_test.dart
git commit -m "fix(vault): shared Firestore PIN sentinel, safe legacy backfill, change/reset PIN, and Isolate PBKDF2"
```

---

### Task 7: Tasks, Calendar, Notes/Scratch Card & Krivo v1.0.4 Modules QA Fixes

**Files:**
- Modify: `lib/features/tasks/data/task_repository.dart:268-320`
- Modify: `lib/features/tasks/presentation/tasks_screen.dart:37-75,320-350,445-465,730-750`
- Modify: `lib/features/calendar/presentation/calendar_screen.dart:55-75,215-235,515-535,615-635,1065-1085`
- Modify: `lib/features/notes/domain/note_model.dart:142-167`
- Modify: `lib/features/notes/presentation/notes_screen.dart:325-365,975-995`
- Modify: `lib/features/loyalty/presentation/loyalty_screen.dart:440-460,540-560,630-805`
- Modify: `lib/features/adult_games/data/adult_games_repository.dart:150-160,280-314`
- Modify: `lib/features/adult_games/presentation/adult_games_screen.dart:140-205,640-700`
- Modify: `lib/features/cycle/domain/cycle_model.dart:1-179`
- Modify: `lib/features/cycle/data/cycle_repository.dart:75-145`
- Modify: `lib/features/cycle/presentation/cycle_screen.dart:35-220`
- Modify: `lib/features/stats/presentation/couple_stats_screen.dart:78-135`
- Test: `test/features/cycle/cycle_upgrade_test.dart`, `test/features/notes/note_model_test.dart`, `test/features/krivo_modules_test.dart`

**Interfaces:**
- Consumes: `CoupleDateUtils` (`daysTogether`, `isDateOverdue`, `isDateToday`, `formatDateKey`), `currentUserUidProvider`
- Produces:
  - `CycleDataModel` fields: `isConfigured: bool`, `symptomsDate: String?`, `trackerUid: String?`, and getter `activeTodaySymptoms({DateTime? today}) -> List<String>`
  - `AdultGamesRepository.clearNudge(String coupleId) -> Future<void>`

- [ ] **Step 1: Write failing tests in `test/features/cycle/cycle_upgrade_test.dart` and `test/features/notes/note_model_test.dart`**

Test:
- `CycleDataModel.fromMap(null).isConfigured == false` (no fake pre-configured state).
- `CycleDataModel.activeTodaySymptoms(today: DateTime(2026, 11, 19))` returns `currentSymptoms` when `symptomsDate == '2026-11-19'` and returns `[]` when `symptomsDate == '2026-11-18'`.
- `NoteModel` equality distinguishes `isScratchCard`, `isScratched`, and `drawingDataJson`.

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/features/cycle/cycle_upgrade_test.dart test/features/notes/note_model_test.dart`
Expected: FAIL.

- [ ] **Step 3: Apply QA fixes across Tasks, Calendar, Notes, Loyalty, Adult Games, Cycle & Stats**

- **Tasks (`task_repository.dart`, `tasks_screen.dart`):** convert `addChecklistItem` and `removeChecklistItem` to `_firestore.runTransaction` (with cache fallback); replace `dueDate.isBefore(DateTime.now())` with `CoupleDateUtils.isDateOverdue(task.dueDate!)`; add confirmation dialogs before deleting tasks/checklists; dispose and remove `_inlineItemControllers[listId]` when a checklist is deleted.
- **Calendar (`calendar_screen.dart`):** remove `'default_couple_id'` fallback (use `currentCoupleIdProvider`); pass filtered events into `_buildMonthGridSliver`; distinguish PT labels (`'Aniversário de Namoro'` vs `'Aniversário'`); dispose `titleController` and `descController` on sheet close.
- **Notes (`note_model.dart`, `notes_screen.dart`):** include `isScratchCard`, `isScratched`, `drawingDataJson` in `NoteModel.==` and `hashCode`; prevent author from scratching own note (`isConcealedForMe = note.isScratchCard && !note.isScratched && note.authorUid != effectiveUid`, showing `"Aguardando seu amor raspar 🎁"` badge for the author while allowing tap-to-edit); on edit save, preserve `existingNote.isScratched` instead of re-locking a revealed scratch card.
- **Loyalty (`loyalty_screen.dart`):** add `ChoiceChip` category selector (`LoyaltyCouponModel.couponCategories`) in `_showAddCouponSheet`, add delete confirmation dialogs for coupons and cards, and dispose modal controllers.
- **Adult Games (`adult_games_repository.dart`, `adult_games_screen.dart`):** fix `'Provoke'` typo, add `clearNudge(coupleId)`, sync active level with `session.selectedLevel` when updated by partner, add `"Dispensar"` button on the Spicy Nudge banner, and dispose custom-card controllers.
- **Cycle (`cycle_model.dart`, `cycle_repository.dart`, `cycle_screen.dart`):** add `isConfigured`, `symptomsDate`, `trackerUid` (backward compatible: existing Firestore doc with `lastPeriodStart` sets `isConfigured = true`); auto-reset symptoms via `activeTodaySymptoms()`; show empty setup prompt if `!cycle.isConfigured`; show partner care mode header (*"Cuidando de <Nome>"*) when `trackerUid != null && trackerUid != myUid`.
- **Couple Stats (`couple_stats_screen.dart`):** watch `todayDailyQuestionProvider(coupleId)` and count it if `isRevealed`, and replace custom `daysTogether` math with `CoupleDateUtils.daysTogether(couple.anniversaryDate)`.

- [ ] **Step 4: Run full feature test suites**

Run: `flutter test test/features/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tasks/ lib/features/calendar/ lib/features/notes/ lib/features/loyalty/ lib/features/adult_games/ lib/features/cycle/ lib/features/stats/ test/features/
git commit -m "fix(features): resolve QA bugs in tasks, calendar, scratch notes, coupons, adult games, cycle, and stats"
```

---

### Task 8: Android Local Notifications (Manifest Receivers, Local Timezone, Auto-Schedule, Partner Sync & Deep-Link)

**Files:**
- Modify: `pubspec.yaml` (add `flutter_timezone: ^3.0.1` or latest compatible with Flutter 3.x)
- Create: `lib/core/notifications/notification_route_provider.dart`
- Modify: `android/app/src/main/AndroidManifest.xml:90-110`
- Modify: `lib/core/notifications/local_notification_service.dart:1-255`
- Modify: `lib/main.dart:34-160`
- Test: `test/e2e/couple_flow_smoke_test.dart`

**Interfaces:**
- Consumes: `tasksStreamProvider`, `calendarEventsStreamProvider`
- Produces:
  - `pendingNotificationRouteProvider` (`StateProvider<String?>`)
  - `LocalNotificationService.scheduleTaskReminder(TaskModel task) -> Future<void>`
  - `LocalNotificationService.consumeLaunchRoute() -> Future<String?>`
  - `reminderSyncProvider` (`Provider.family<void, String>` syncing upcoming calendar + task alarms on both phones)

- [ ] **Step 1: Add `flutter_timezone` to `pubspec.yaml` and run `flutter pub get`**

Run: `flutter pub get`
Expected: Exits 0.

- [ ] **Step 2: Register Android notification receivers in `AndroidManifest.xml`**

Inside `<application>` in `android/app/src/main/AndroidManifest.xml`, add:
- `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` (`android:exported="false"`)
- `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver` (`android:exported="false"`, intent-filters `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`, `com.htc.intent.action.QUICKBOOT_POWERON`).

- [ ] **Step 3: Upgrade `LocalNotificationService`, create `pendingNotificationRouteProvider`, and wire auto-scheduling & deep-link handling in `main.dart`**

- Create `lib/core/notifications/notification_route_provider.dart` exporting `pendingNotificationRouteProvider` and `parseRouteToTabIndex(String payload)` (`daily_question` → 0, `tasks` → 1, `calendar_event:*` → 2, `decide` → 3, `notes` → push `NotesScreen`, `cycle` → push `CycleScreen`, `adult_games` → push `AdultGamesScreen`).
- In `lib/core/notifications/local_notification_service.dart`:
  - Call `FlutterTimezone.getLocalTimezone()` and `tz.setLocalLocation(tz.getLocation(tzName))` inside `initialize()` with safe fallback to `tz.getLocation('America/Sao_Paulo')`.
  - Accept optional `void Function(String payload)? onNotificationTap` in `initialize()`, invoke it from `onDidReceiveNotificationResponse`, and expose `consumeLaunchRoute()` via `getNotificationAppLaunchDetails()`.
  - Add `scheduleTaskReminder(TaskModel task)` (fires at 09:00 on `dueDate` if incomplete and in the future; ID offset `140000 + hash % 50000`) and `cancelTaskReminder(String taskId)`.
- In `lib/main.dart`:
  - Call `LocalNotificationService.scheduleDailyPrompt(hour: 20, minute: 0)` automatically when a paired `coupleId` becomes active (guarded once per session + respecting user toggle).
  - Watch `reminderSyncProvider(coupleId)` inside `MainNavigationShell` to schedule reminders for all upcoming `calendar_events` and incomplete `tasks` with `dueDate` on **both** partners' phones.
  - Listen to `pendingNotificationRouteProvider` in `MainNavigationShell` to switch `_currentIndex` or push the target screen (`NotesScreen`, `CycleScreen`, `AdultGamesScreen`), then clear the provider to `null`.

- [ ] **Step 4: Write unit test for route parsing & run tests**

Add route-mapping assertions in `test/core/utils/couple_utils_test.dart` and run:
Run: `flutter test test/core/ test/e2e/couple_flow_smoke_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml lib/core/notifications/ lib/main.dart test/
git commit -m "fix(notifications): add Android boot/alarm receivers, local BRT timezone, partner reminder sync, and deep-link routing"
```

---

### Task 9: Android Jetpack Glance Widgets (Clickable Deep-Links, No `runBlocking`, Scratch Privacy, Dynamic Days & Debounced Sync)

**Files:**
- Modify: `lib/features/widgets/widget_sync_service.dart:15-402`
- Modify: `android/app/src/main/kotlin/com/personal/couple_app/MainActivity.kt`
- Modify: `android/app/src/main/kotlin/com/personal/couple_app/CoupleGlanceWidget.kt`
- Modify: `android/app/src/main/kotlin/com/personal/couple_app/DailyPromptGlanceWidget.kt`
- Modify: `android/app/src/main/kotlin/com/personal/couple_app/NoteGlanceWidget.kt`
- Modify: `android/app/src/main/kotlin/com/personal/couple_app/TasksGlanceWidget.kt`
- Modify: `lib/main.dart` (listen to `MethodChannel('com.personal.couple_app/widget_route')`)
- Test: `test/features/widgets/widget_sync_service_test.dart`

**Interfaces:**
- Consumes: `DailyQuestionRepository.translatePrompt`, `CoupleDateUtils.daysTogether`, `pendingNotificationRouteProvider`
- Produces:
  - `WidgetSyncService.formatNoteForWidget(NoteModel note, {bool isPortuguese = true}) -> Map<String, String>`
  - `WidgetSyncService.clearAllWidgets() -> Future<void>`
  - Native Android channel `com.personal.couple_app/widget_route` (`getInitialRoute` + `onRoute` push from `MainActivity.onNewIntent`)

- [ ] **Step 1: Write failing tests in `test/features/widgets/widget_sync_service_test.dart`**

Add tests:
```dart
test('formatNoteForWidget masks un-scratched scratch cards to prevent home-screen spoilers', () {
  final secretNote = NoteModel(
    id: 'n1',
    title: 'Segredo',
    content: 'Comprei sua aliança!',
    authorUid: 'u1',
    authorName: 'Gui',
    isScratchCard: true,
    isScratched: false,
  );
  final payload = WidgetSyncService.formatNoteForWidget(secretNote, isPortuguese: true);
  expect(payload['note_content'], isNot(contains('aliança')));
  expect(payload['note_content'], contains('raspar'));
});

test('syncAllWidgets translates English bank prompt to Portuguese before formatting', () {
  final translated = DailyQuestionRepository.translatePrompt(
    DailyQuestionRepository.defaultQuestionBank.first,
    languageCode: 'pt',
  );
  expect(translated, DailyQuestionRepository.defaultQuestionBankPt.first);
});
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/features/widgets/widget_sync_service_test.dart`
Expected: FAIL (`formatNoteForWidget` not defined).

- [ ] **Step 3: Update `WidgetSyncService`, `MainActivity.kt`, and all 4 Kotlin Glance widgets**

- In `lib/features/widgets/widget_sync_service.dart`:
  - Add `formatNoteForWidget(NoteModel note, {bool isPortuguese = true})`: if `note.isScratchCard && !note.isScratched`, return masked title/content (`"🎁 Recado surpresa! Toque para raspar ✨"` / `"🎁 Surprise note! Tap to scratch ✨"`); use it in `updateGlanceNote`.
  - In `syncAllWidgets`: save `'language'` and `'app_locale'` **first** (before `syncCoupleStats`/`syncDailyPrompt`), translate `todayQuestion.prompt` via `DailyQuestionRepository.translatePrompt`, and use `CoupleDateUtils.daysTogether`.
  - Add a 400 ms `Timer` debounce inside `widgetSyncProvider` to coalesce multi-stream bursts.
  - Add `clearAllWidgets()` clearing note, couple, prompt, and task keys and updating all 4 widgets (wired into `_confirmUnpair` in `main.dart`).
- In `android/app/src/main/kotlin/com/personal/couple_app/`:
  - Remove the custom `onUpdate` `kotlinx.coroutines.runBlocking` override in all 4 receivers (`CoupleGlanceWidget.kt`, `DailyPromptGlanceWidget.kt`, `NoteGlanceWidget.kt`, `TasksGlanceWidget.kt`) — rely on `GlanceAppWidgetReceiver`'s built-in non-blocking coroutine update.
  - Attach `.clickable(actionStartActivity<MainActivity>(actionParametersOf(ActionParameters.Key<String>("widget_route") to "<route>")))` on the root `Box` of all 4 widgets (`"couple"`, `"daily_question"`, `"notes"`, `"tasks"`).
  - In `CoupleGlanceWidget.kt`: parse saved `anniversary` ISO string via `java.time.LocalDate` and compute `ChronoUnit.DAYS.between(annivDate, LocalDate.now()).coerceAtLeast(0)` at render time (falling back to stored int if parsing fails).
  - In `MainActivity.kt`: read `intent?.getStringExtra("widget_route")` in `configureFlutterEngine` and `onNewIntent`, forwarding it over `MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.personal.couple_app/widget_route")` to set `pendingNotificationRouteProvider` in `main.dart`.

- [ ] **Step 4: Run full verification suite (`flutter test`, `flutter analyze`, and Android Kotlin compilation check)**

Run: `flutter test`
Expected: All tests pass (150+ tests).

Run: `flutter analyze --no-pub`
Expected: 0 errors, 0 warnings.

Run: `flutter build apk --debug`
Expected: Succeeds (verifies Kotlin Glance widgets, `AndroidManifest.xml`, and `MainActivity.kt` compile cleanly!).

- [ ] **Step 5: Commit**

```bash
git add lib/features/widgets/ lib/main.dart android/app/src/main/kotlin/ test/features/widgets/
git commit -m "fix(widgets): make Glance widgets clickable with deep-links, remove main-thread runBlocking, mask scratch cards, and compute days dynamically"
```
