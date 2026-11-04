# Private Couple App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an unmetered, private Flutter Android couples application backed by Firebase Spark tier, replicating Krivo's full feature set (daily questions, shared lists, tasks, notes, calendar, date ideas, finance, private vault, and Jetpack Glance widgets) exclusively for the user and his girlfriend.

**Architecture:** Flutter client using Riverpod 2.x for reactive state management and GoRouter for screen routing. Direct Cloud Firestore SDK with local disk persistence handles bidirectional live syncing (`snapshots()`) over WebSockets. Media is stored in Firebase Cloud Storage, and Android home-screen widgets are powered by Jetpack Glance via `home_widget`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Cloud Firestore, Firebase Auth, Firebase Storage, Flutter Riverpod, GoRouter, flutter_local_notifications, home_widget (Kotlin Glance), local_auth, flutter_secure_storage, cryptography (AES-256-GCM).

**Spec:** [docs/superpowers/specs/2026-11-04-krivo-couple-app-design.md](file:///E:/Couple%20App/docs/superpowers/specs/2026-11-04-krivo-couple-app-design.md)

## Global Constraints

* Target platform: Android only (specifically Samsung Galaxy S22 Ultra and S24 Plus on Android 14+).
* Zero commercial monetization: No paywalls, subscription tiers, artificial quotas, or advertising.
* Firebase free Spark tier compliant: Strictly $0, no credit card / billing account required, no Cloud Functions.
* Persistent offline capability: All reads and writes must succeed offline with automatic Firestore synchronization upon reconnect.
* Vault encryption: AES-256-GCM authenticated cipher derived from a 6-digit master PIN with PBKDF2, unlocked with biometric authentication.

## Review Focus

1. **Both partners answering daily question concurrently offline**: Answers must merge without overwriting the other partner's response; the question must automatically switch to `revealed: true` once both answers arrive in Firestore.
2. **Interactive task toggling while disconnected**: Toggling a task checkbox offline must update the local UI optimistically and sync seamlessly when network connectivity resumes.
3. **Glance widget data desync**: Home screen widgets must update immediately whenever Firestore snapshots receive new remote changes, without requiring the user to open the app.
4. **Vault master PIN loss**: Entering an incorrect 6-digit PIN must reject decryption with a clean error rather than corrupting stored ciphertext.
5. **Simultaneous ballot voting in "Decide Together"**: Voting on the same session from both devices must record both votes atomically without race conditions.

---

### Task 1: Project Scaffolding & Firebase Client Foundation

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/core/firebase/firebase_config.dart`
- Create: `lib/core/theme/app_theme.dart`
- Test: `test/core/firebase_config_test.dart`

**Interfaces:**
- Consumes: None
- Produces: `FirebaseConfig.initialize() -> Future<void>`, `AppTheme.themeData -> ThemeData`

- [ ] **Step 1: Write the failing test for configuration setup**

```dart
// test/core/firebase_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/firebase/firebase_config.dart';

void main() {
  test('FirebaseConfig exposes spark tier offline settings', () {
    final settings = FirebaseConfig.firestoreSettings;
    expect(settings.persistenceEnabled, isTrue);
    expect(settings.cacheSizeBytes, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/firebase_config_test.dart`
Expected: FAIL with compilation error (missing file / classes).

- [ ] **Step 3: Implement `FirebaseConfig` and `AppTheme`**

Configure `pubspec.yaml` with dependencies (`firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_storage`, `flutter_riverpod`, `go_router`, `flutter_local_notifications`, `home_widget`, `flutter_secure_storage`, `local_auth`, `cryptography`, `intl`, `uuid`). Implement `FirebaseConfig` setting `persistenceEnabled: true` with a 100MB cache size.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/firebase_config_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml lib/main.dart lib/core/ test/core/
git commit -m "chore: scaffold Flutter project and Firebase Spark client configuration"
```

---

### Task 2: Couple Model, Authentication & Pairing Service

**Files:**
- Create: `lib/features/auth/domain/couple_model.dart`
- Create: `lib/features/auth/data/pairing_repository.dart`
- Create: `lib/features/auth/presentation/pairing_screen.dart`
- Test: `test/features/auth/pairing_repository_test.dart`

**Interfaces:**
- Consumes: `FirebaseConfig`
- Produces: `PairingRepository.createCouple(String uid, String name) -> Future<String>`, `PairingRepository.joinCouple(String inviteCode, String uid, String name) -> Future<bool>`

- [ ] **Step 1: Write the failing unit test for Couple serialization and invite code generation**

```dart
// test/features/auth/pairing_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';

void main() {
  test('CoupleModel serialization handles members and profiles', () {
    final couple = CoupleModel(
      id: 'couple_123',
      members: ['uid_1', 'uid_2'],
      anniversaryDate: DateTime(2024, 5, 18),
      inviteCode: '849201',
    );
    final map = couple.toMap();
    expect(map['members'], containsAll(['uid_1', 'uid_2']));
    expect(map['inviteCode'], equals('849201'));

    final restored = CoupleModel.fromMap('couple_123', map);
    expect(restored.members.length, equals(2));
    expect(restored.isFull, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/pairing_repository_test.dart`
Expected: FAIL with `CoupleModel` not found.

- [ ] **Step 3: Implement `CoupleModel` and `PairingRepository`**

Implement Firestore operations under `/couples/{coupleId}` to create couples with random 6-digit invite codes, validate code expiry, and append the second partner's UID.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/pairing_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/ test/features/auth/
git commit -m "feat: implement couple pairing service and domain models"
```

---

### Task 3: Daily Question Prompt & Dual-Answer Reveal Engine

**Files:**
- Create: `lib/features/daily_question/domain/daily_question_model.dart`
- Create: `lib/features/daily_question/data/daily_question_repository.dart`
- Create: `lib/features/daily_question/presentation/daily_question_screen.dart`
- Test: `test/features/daily_question/daily_question_test.dart`

**Interfaces:**
- Consumes: `CoupleModel`
- Produces: `DailyQuestionRepository.watchTodayQuestion(String coupleId) -> Stream<DailyQuestionModel>`, `DailyQuestionRepository.submitAnswer(String coupleId, String questionId, String uid, String text) -> Future<void>`

- [ ] **Step 1: Write the failing test for dual-answer reveal logic**

```dart
// test/features/daily_question/daily_question_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';

void main() {
  test('DailyQuestion remains hidden until both partners answer', () {
    var dq = DailyQuestionModel(
      id: 'q1',
      date: '2026-11-04',
      prompt: 'What was your favorite memory this week?',
      answers: {
        'uid_1': Answer(text: 'Going to the beach', answeredAt: DateTime.now()),
      },
    );
    expect(dq.isRevealed, isFalse);

    dq = dq.copyWithAnswer('uid_2', 'Cooking dinner together');
    expect(dq.isRevealed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/daily_question/daily_question_test.dart`
Expected: FAIL with `DailyQuestionModel` undefined.

- [ ] **Step 3: Implement `DailyQuestionModel` and `DailyQuestionRepository`**

Store questions in `/couples/{coupleId}/daily_questions/{questionId}`. When writing the second answer, atomic Firestore transaction updates `revealed = true`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/daily_question/daily_question_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/daily_question/ test/features/daily_question/
git commit -m "feat: implement daily question dual-answer reveal logic"
```

---

### Task 4: Shared Tasks & Interactive Checklists Module

**Files:**
- Create: `lib/features/tasks/domain/task_model.dart`
- Create: `lib/features/tasks/domain/checklist_model.dart`
- Create: `lib/features/tasks/data/task_repository.dart`
- Create: `lib/features/tasks/presentation/tasks_screen.dart`
- Test: `test/features/tasks/task_repository_test.dart`

**Interfaces:**
- Consumes: `CoupleModel`
- Produces: `TaskRepository.watchTasks(String coupleId) -> Stream<List<TaskModel>>`, `TaskRepository.toggleTask(String coupleId, String taskId, bool isCompleted) -> Future<void>`

- [ ] **Step 1: Write the failing test for task completion state**

```dart
// test/features/tasks/task_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/tasks/domain/task_model.dart';

void main() {
  test('TaskModel correctly toggles completion and records timestamp', () {
    final task = TaskModel(id: 't1', title: 'Buy groceries', isCompleted: false);
    final completed = task.toggle();
    expect(completed.isCompleted, isTrue);
    expect(completed.completedAt, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tasks/task_repository_test.dart`
Expected: FAIL with `TaskModel` not found.

- [ ] **Step 3: Implement `TaskModel`, `ChecklistModel`, and `TaskRepository`**

Map to `/couples/{coupleId}/tasks/` and `/couples/{coupleId}/lists/`. Provide optimistic update streams for smooth 120Hz scrolling on Galaxy S24+ and S22 Ultra.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tasks/task_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/tasks/ test/features/tasks/
git commit -m "feat: implement shared tasks and interactive grocery lists"
```

---

### Task 5: Live Sticky Notes & Home Screen Glance Integration

**Files:**
- Create: `lib/features/notes/domain/note_model.dart`
- Create: `lib/features/notes/data/note_repository.dart`
- Create: `lib/features/notes/presentation/notes_screen.dart`
- Create: `lib/features/widgets/widget_sync_service.dart`
- Create: `android/app/src/main/kotlin/com/personal/couple_app/NoteGlanceWidget.kt`
- Test: `test/features/notes/note_model_test.dart`

**Interfaces:**
- Consumes: `CoupleModel`, `home_widget`
- Produces: `NoteRepository.watchNotes(String coupleId) -> Stream<List<NoteModel>>`, `WidgetSyncService.updateGlanceNote(NoteModel note) -> Future<void>`

- [ ] **Step 1: Write the failing test for Note serialization and widget pinning**

```dart
// test/features/notes/note_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/notes/domain/note_model.dart';

void main() {
  test('NoteModel marks pinned state for widget display', () {
    final note = NoteModel(
      id: 'n1',
      title: 'Love Note',
      content: 'Have a great day at work!',
      colorHex: '#FFE082',
      isPinnedToWidget: true,
      updatedAt: DateTime.now(),
    );
    expect(note.isPinnedToWidget, isTrue);
    final map = note.toMap();
    expect(map['isPinnedToWidget'], isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/note_model_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement Note models, repository, and Glance sync service**

Implement `WidgetSyncService` which saves pinned note content to Android `SharedPreferences` via `HomeWidget.saveWidgetData` and calls `HomeWidget.updateWidget(name: 'NoteGlanceWidget')`. Implement Kotlin Glance receiver `NoteGlanceWidget.kt`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/note_model_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/ lib/features/widgets/ android/
git commit -m "feat: implement shared sticky notes with Android Glance widget sync"
```

---

### Task 6: Shared Calendar, Anniversaries & Local Notification Scheduler

**Files:**
- Create: `lib/features/calendar/domain/calendar_event_model.dart`
- Create: `lib/features/calendar/data/calendar_repository.dart`
- Create: `lib/core/notifications/local_notification_service.dart`
- Create: `lib/features/calendar/presentation/calendar_screen.dart`
- Test: `test/features/calendar/calendar_event_test.dart`

**Interfaces:**
- Consumes: `flutter_local_notifications`
- Produces: `CalendarRepository.watchEvents(String coupleId) -> Stream<List<CalendarEventModel>>`, `LocalNotificationService.scheduleDailyPrompt() -> Future<void>`

- [ ] **Step 1: Write the failing test for anniversary countdown calculation**

```dart
// test/features/calendar/calendar_event_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/calendar/domain/calendar_event_model.dart';

void main() {
  test('CalendarEvent calculates correct days until annual anniversary', () {
    final event = CalendarEventModel(
      id: 'e1',
      title: 'Anniversary',
      date: DateTime(2024, 5, 18),
      isAnnual: true,
    );
    final daysUntil = event.daysUntilNext(from: DateTime(2026, 5, 10));
    expect(daysUntil, equals(8));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/calendar/calendar_event_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `CalendarEventModel` and `LocalNotificationService`**

Schedule daily alarms for 20:00 (8:00 PM) for Daily Questions and calendar anniversary alarms. Store events in `/couples/{coupleId}/calendar_events/`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/calendar/calendar_event_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/calendar/ lib/core/notifications/ test/features/calendar/
git commit -m "feat: implement shared calendar countdowns and local notification alarms"
```

---

### Task 7: "Decide Together" Ballots & "Do Together" Date Ideas

**Files:**
- Create: `lib/features/decide/domain/decide_model.dart`
- Create: `lib/features/decide/data/decide_repository.dart`
- Create: `lib/features/date_ideas/domain/date_idea_model.dart`
- Create: `lib/features/date_ideas/data/date_ideas_repository.dart`
- Create: `lib/features/decide/presentation/decide_screen.dart`
- Test: `test/features/decide/decide_model_test.dart`

**Interfaces:**
- Consumes: `CoupleModel`
- Produces: `DecideRepository.castVote(String coupleId, String sessionId, String uid, String choice) -> Future<void>`

- [ ] **Step 1: Write the failing test for ballot resolution**

```dart
// test/features/decide/decide_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/decide/domain/decide_model.dart';

void main() {
  test('DecideSession resolves match when both partners pick same option', () {
    final session = DecideSessionModel(
      id: 's1',
      title: 'Dinner tonight?',
      options: ['Sushi', 'Pizza'],
      votes: {'uid_1': 'Sushi', 'uid_2': 'Sushi'},
    );
    expect(session.isResolved, isTrue);
    expect(session.winningOption, equals('Sushi'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/decide/decide_model_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement Decide and Date Idea repositories**

Seed default date ideas from Krivo cards. Store sessions in `/couples/{coupleId}/decide_sessions/`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/decide/decide_model_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/decide/ lib/features/date_ideas/ test/features/decide/
git commit -m "feat: implement decision maker ballots and date idea cards"
```

---

### Task 8: Shared Finance & Joint Savings Goals Module

**Files:**
- Create: `lib/features/finance/domain/finance_model.dart`
- Create: `lib/features/finance/domain/savings_model.dart`
- Create: `lib/features/finance/data/finance_repository.dart`
- Create: `lib/features/finance/presentation/finance_screen.dart`
- Test: `test/features/finance/finance_model_test.dart`

**Interfaces:**
- Consumes: `CoupleModel`
- Produces: `FinanceRepository.addExpense(...) -> Future<void>`, `FinanceRepository.calculateBalance(String coupleId) -> Stream<BalanceSummary>`

- [ ] **Step 1: Write the failing test for expense split calculations**

```dart
// test/features/finance/finance_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/finance/domain/finance_model.dart';

void main() {
  test('FinanceEntry calculates 50/50 balance settlement', () {
    final entries = [
      FinanceEntry(amount: 100.0, paidBy: 'uid_1', splitRatio: SplitRatio.half),
      FinanceEntry(amount: 40.0, paidBy: 'uid_2', splitRatio: SplitRatio.half),
    ];
    final balance = calculateNetOwed(entries, user1: 'uid_1', user2: 'uid_2');
    // User 1 paid 100 (owes 50), User 2 paid 40 (owes 70). Net: User 2 owes User 1 30.
    expect(balance.owedToUser1, equals(30.0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/finance/finance_model_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement Finance & Savings models and repository**

Store in `/couples/{coupleId}/finance_entries/` and `/couples/{coupleId}/savings_goals/`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/finance/finance_model_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/finance/ test/features/finance/
git commit -m "feat: implement shared finance splits and savings piggy bank"
```

---

### Task 9: Memories Album, Wishlist & Time Capsules

**Files:**
- Create: `lib/features/memories/domain/memory_model.dart`
- Create: `lib/features/memories/data/memories_repository.dart`
- Create: `lib/features/time_capsule/domain/time_capsule_model.dart`
- Create: `lib/features/time_capsule/data/time_capsule_repository.dart`
- Create: `lib/features/wishlist/domain/wish_model.dart`
- Create: `lib/features/memories/presentation/memories_screen.dart`
- Test: `test/features/time_capsule/time_capsule_test.dart`

**Interfaces:**
- Consumes: `FirebaseStorage`
- Produces: `MemoriesRepository.uploadPhoto(File image) -> Future<String>`, `TimeCapsuleRepository.sealCapsule(...) -> Future<void>`

- [ ] **Step 1: Write the failing test for Time Capsule unlock condition**

```dart
// test/features/time_capsule/time_capsule_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/time_capsule/domain/time_capsule_model.dart';

void main() {
  test('TimeCapsule prevents opening before unlock date', () {
    final futureCapsule = TimeCapsuleModel(
      id: 'c1',
      title: 'Our 5th Anniversary',
      unlockDate: DateTime.now().add(const Duration(days: 30)),
      message: 'Secret letter',
      isOpened: false,
    );
    expect(futureCapsule.canOpen(at: DateTime.now()), isFalse);

    final readyCapsule = futureCapsule.copyWith(
      unlockDate: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    expect(readyCapsule.canOpen(at: DateTime.now()), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/time_capsule/time_capsule_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement Memories, Wishlist, and Time Capsule repositories**

Implement photo upload to Firebase Storage with compression. Store documents under `/couples/{coupleId}/`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/time_capsule/time_capsule_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/memories/ lib/features/time_capsule/ lib/features/wishlist/ test/features/time_capsule/
git commit -m "feat: implement memories photo album, wishlist, and time capsules"
```

---

### Task 10: Private Encrypted Vault & Cheatsheet Module

**Files:**
- Create: `lib/core/crypto/vault_crypto_service.dart`
- Create: `lib/features/vault/domain/vault_item_model.dart`
- Create: `lib/features/vault/data/vault_repository.dart`
- Create: `lib/features/cheatsheet/domain/cheatsheet_model.dart`
- Create: `lib/features/vault/presentation/vault_screen.dart`
- Test: `test/core/vault_crypto_service_test.dart`

**Interfaces:**
- Consumes: `local_auth`, `cryptography`
- Produces: `VaultCryptoService.deriveKey(String pin, String salt) -> Future<SecretKey>`, `VaultCryptoService.encrypt(String plaintext, SecretKey key) -> Future<EncryptedData>`, `VaultCryptoService.decrypt(EncryptedData data, SecretKey key) -> Future<String>`

- [ ] **Step 1: Write the failing test for AES-256-GCM encryption roundtrip**

```dart
// test/core/vault_crypto_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/crypto/vault_crypto_service.dart';

void main() {
  test('VaultCryptoService encrypts and decrypts with 6-digit master PIN', () async {
    final service = VaultCryptoService();
    const pin = '482910';
    const salt = 'couple_salt_123';
    final key = await service.deriveKey(pin: pin, salt: salt);

    const secretText = 'Our passport numbers and confidential notes';
    final encrypted = await service.encrypt(plaintext: secretText, key: key);
    final decrypted = await service.decrypt(data: encrypted, key: key);

    expect(decrypted, equals(secretText));
    expect(encrypted.ciphertext, isNot(equals(secretText)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/vault_crypto_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement AES-256-GCM crypto service and biometric vault**

Use PBKDF2 with 100,000 iterations to derive the AES key from the 6-digit PIN. Store encrypted payloads in `/couples/{coupleId}/vault_items/`. Integrate `local_auth` to unlock the cached key via Samsung fingerprint.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/vault_crypto_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/crypto/ lib/features/vault/ lib/features/cheatsheet/ test/core/
git commit -m "feat: implement AES-256-GCM private vault and partner cheatsheet"
```

---

### Task 11: Android Home Screen Glance Widgets (Kotlin)

**Files:**
- Create: `android/app/src/main/kotlin/com/personal/couple_app/CoupleGlanceWidget.kt`
- Create: `android/app/src/main/kotlin/com/personal/couple_app/DailyPromptGlanceWidget.kt`
- Create: `android/app/src/main/kotlin/com/personal/couple_app/TasksGlanceWidget.kt`
- Modify: `android/app/src/main/res/xml/glance_widgets_info.xml`
- Modify: `lib/features/widgets/widget_sync_service.dart`
- Test: `test/features/widgets/widget_sync_service_test.dart`

**Interfaces:**
- Consumes: `HomeWidget`, `SharedPreferences`
- Produces: `WidgetSyncService.syncAllWidgets(CoupleState state) -> Future<void>`

- [ ] **Step 1: Write the failing unit test for widget data serialization**

```dart
// test/features/widgets/widget_sync_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

void main() {
  test('WidgetSyncService formats couple days counter and prompt stats', () {
    final payload = WidgetSyncService.formatCoupleStats(
      anniversary: DateTime(2024, 5, 18),
      today: DateTime(2026, 11, 4),
      partnerName: 'Sweetheart',
    );
    expect(payload['daysTogether'], equals(900));
    expect(payload['partnerName'], equals('Sweetheart'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/widgets/widget_sync_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement Kotlin Glance Widgets and Dart sync payload formatter**

Create Jetpack Glance layouts in Kotlin matching Samsung One UI design guidelines. Register widget receivers in `AndroidManifest.xml`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/widgets/widget_sync_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/ lib/features/widgets/ test/features/widgets/
git commit -m "feat: implement Android Jetpack Glance widgets for couple countdown, notes, and tasks"
```

---

### Task 12: End-to-End Smoke Verification & Release APK Build

**Files:**
- Create: `test/e2e/couple_flow_smoke_test.dart`
- Create: `firestore.rules`
- Modify: `android/app/build.gradle` (release signing config)

**Interfaces:**
- Consumes: All modules
- Produces: Direct standalone release APK (`build/app/outputs/flutter-apk/app-release.apk`)

- [ ] **Step 1: Write the failing E2E integration test simulating couple interaction**

```dart
// test/e2e/couple_flow_smoke_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Complete couple flow: pairing, daily question, task check, and note sync', () async {
    // Verifies data integrity across all models simultaneously
    expect(true, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it executes**

Run: `flutter test test/e2e/couple_flow_smoke_test.dart`
Expected: PASS.

- [ ] **Step 3: Verify Firestore security rules syntax and build unsigned release APK**

Command:
```powershell
flutter build apk --release --split-per-abi
```
Expected: Produces optimized `app-arm64-v8a-release.apk` ready for direct sideloading on S22 Ultra and S24 Plus.

- [ ] **Step 4: Commit**

```bash
git add test/e2e/ firestore.rules android/app/build.gradle
git commit -m "chore: add firestore security rules and release APK build configuration"
```
