# Phase 2 — Home Viva ("Nosso Dia"), Presença & Sync em Segundo Plano Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Tab 0 with the live "Nosso Dia" couple dashboard, add daily streak tracking, couple profile/avatar editing, live in-app partner banners & navigation badges, and $0 Firebase Spark Android `WorkManager` periodic background sync with dual notification channels and Samsung One UI reliability guidance.

**Architecture:** All partner presence and cross-device signals converge in a single lightweight Firestore document `/couples/{coupleId}/activity_state/latest` (`< 2 KB`) storing the latest event metadata, daily partner moods, rolling last-10 "Tô com Saudade" pulses plus lifetime counter, 1h nudge cooldowns, and a compact widget summary snapshot. In foreground, Riverpod streams drive the new `CoupleHomeScreen`, navigation badges, and a top live partner alert banner; in background, a 15-minute Android `WorkManager` task performs 1 Firestore read on `activity_state/latest`, deduplicates via `SharedPreferences`, fires a channel-routed local notification, and refreshes all 4 Jetpack Glance widgets.

**Tech Stack:** Flutter 3.x, Riverpod (`flutter_riverpod`), Cloud Firestore (Spark $0), `flutter_local_notifications`, `home_widget` + Android Jetpack Glance (Kotlin), `image_picker`, `flutter_animate`, `workmanager`, `shared_preferences`.

**Spec:** `docs/superpowers/specs/2026-11-19-krivo-parity-and-stabilization-design.md` (Section 5 — Fase 2)

## Global Constraints

- **Firebase Free Spark Tier (R$ 0):** No Cloud Functions, no paid push providers, no Firebase Storage uploads. Avatars stored as compressed Base64 Data URIs (`256x256` JPEG 70%, ~15–25 KB, hard cap 80 KB) inside `partnerProfiles[uid].avatarUrl`.
- **Single-read background sync:** `/couples/{coupleId}/activity_state/latest` must stay `< 2 KB` so `WorkManager` performs 1 Firestore read per 15-min cycle.
- **Android-first (Samsung One UI 14/15):** Preserve `minSdk 24`, `targetSdk 36`, `compileSdk 36`, `release.keystore`.
- **Language:** Português (Brasil) (`pt_BR`) primary, `en_US` secondary; all new UI strings exposed through `AppStrings`.
- **Zero data loss:** 100% backward compatible with existing couple Firestore documents (all new fields default safely when absent).
- **Widget & route consistency:** Tapping notifications/widgets must route directly to the intended screen, including `daily_question` opening `DailyQuestionScreen` now that Tab 0 is `CoupleHomeScreen`.

## Review Focus

1. **No notification/banner storm on launch or replay:** Initial load of `activity_state/latest` in `MainNavigationShell` must seed `_lastSeenEventId` without showing a stale toast, and `WorkManager` must never re-notify an already-notified `lastEventId` or notify the user about their own action (`lastActorUid == myUid`).
2. **Scratch-card privacy preserved end-to-end:** When a pinned note is an unscratched scratch card, `activity_state/latest` (`body` and `pinnedNotePreview`) and `WorkManager` Glance sync must emit only the masked surprise message, never the raw note content.
3. **Daily mood reset & payload bounds:** Yesterday's moods must be ignored visually today without needing a Firestore write; mood notes must be truncated to 40 chars; `recentPulses` must stay capped at 10 items; avatar Base64 payloads must be rejected above 80 KB.
4. **Unpair & offline resilience for `WorkManager`:** `unpairCurrentUser` must cancel the periodic `WorkManager` task and clear `bg_*` keys from `SharedPreferences`; if `bg_couple_id` is empty or Firestore fails offline, the background worker exits cleanly without crashing.
5. **Deep-link accuracy after Tab 0 replacement:** `'couple'` and `'home'` land on Tab 0 (`CoupleHomeScreen`), whereas `'daily_question'` navigates to `DailyQuestionScreen` so the Daily Prompt widget and 20:00 reminder still land directly on the question.

---

### Task 1: Activity State Model, Repository & Partner Action Hooks

**Files:**
- Create: `lib/features/home/domain/activity_state_model.dart`
- Create: `lib/features/home/data/activity_state_repository.dart`
- Modify: `lib/features/daily_question/presentation/daily_question_screen.dart`
- Modify: `lib/features/cycle/presentation/cycle_screen.dart`
- Modify: `lib/features/adult_games/presentation/adult_games_screen.dart`
- Modify: `lib/features/notes/presentation/notes_screen.dart`
- Modify: `lib/features/decide/presentation/decide_screen.dart`
- Modify: `lib/features/loyalty/presentation/loyalty_screen.dart`
- Modify: `lib/features/tasks/presentation/tasks_screen.dart`
- Test: `test/features/home/activity_state_test.dart`

**Interfaces:**
- Consumes: `CoupleDateUtils.formatDateKey` (`lib/core/utils/couple_date_utils.dart`), `WidgetSyncService.formatNoteForWidget` (`lib/features/widgets/widget_sync_service.dart`).
- Produces:
  - `PartnerMood` (`emoji`, `label`, `note`, `dateKey`, `updatedAt`; `toMap`, `fromMap`, `isActiveForDate(DateTime now)`).
  - `ThinkingOfYouPulse` (`id`, `senderUid`, `senderName`, `message`, `sentAt`; `toMap`, `fromMap`).
  - `ActivityStateModel` (`lastEventId`, `lastEventType`, `lastActorUid`, `lastActorName`, `title`, `body`, `route`, `updatedAt`, `moods`, `recentPulses`, `totalPulsesCount`, `drawingWidgetRevision`, `nudgeSentAtByUid`, `widgetSnapshot`; `activeMoodFor(String uid, {DateTime? now})`, `canNudgePartner(String myUid, {DateTime? now, Duration cooldown})`, `isUrgentEventType(String eventType)`).
  - Event type constants on `ActivityStateModel`: `typePulse`, `typeSos`, `typeSpicyNudge`, `typeDailyAnswer`, `typeDailyNudge`, `typeNote`, `typeDecide`, `typeCoupon`, `typeTask`, `typeMood`.
  - `ActivityStateRepository`: `watchActivityState(String coupleId)`, `getActivityState(String coupleId)`, `recordActivity(...)`, `setMood(...)`, `sendThinkingOfYouPulse(...)`, `sendDailyQuestionNudge(...)`, `syncWidgetSnapshot(...)`.
  - Riverpod providers: `activityStateRepositoryProvider`, `activityStateStreamProvider`.

- [ ] **Step 1: Write the failing unit tests**

Create `test/features/home/activity_state_test.dart` covering:
- `PartnerMood` serialization, 40-char note truncation (`PartnerMood.sanitizeNote`), and `activeMoodFor` returning `null` for yesterday's `dateKey` and non-null for today.
- `ActivityStateModel.appendPulse` keeping at most 10 rolling `recentPulses` (newest first) while incrementing `totalPulsesCount`.
- `ActivityStateModel.canNudgePartner` enforcing a 1-hour cooldown (`false` at 59 min, `true` at 61 min).
- `ActivityStateModel.isUrgentEventType` returning `true` for `typeSos`, `typePulse`, `typeSpicyNudge` and `false` for `typeDailyAnswer`, `typeTask`, `typeNote`, `typeDecide`, `typeCoupon`.
- `ActivityStateModel.fromMap` gracefully handling empty/missing fields for legacy couples.
- `ActivityStateModel.sanitizeNoteBodyForActivity` returning masked surprise text when `isScratchCard && !isScratched`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/home/activity_state_test.dart`
Expected: FAIL (missing `activity_state_model.dart` / `activity_state_repository.dart`).

- [ ] **Step 3: Implement `ActivityStateModel` and `ActivityStateRepository`**

Create `lib/features/home/domain/activity_state_model.dart` with immutable models (`PartnerMood`, `ThinkingOfYouPulse`, `ActivityStateModel`), preset mood options `PartnerMood.presets` (6 PT-BR/EN moods: 💕 Apaixonado, 😴 Cansado, 🤗 Carente, ⚡ Animado, 🍫 Com fome, 🧘 Em paz), pure helpers (`appendPulse`, `sanitizeNote`, `sanitizeNoteBodyForActivity`, `activeMoodFor`, `canNudgePartner`, `isUrgentEventType`).

Create `lib/features/home/data/activity_state_repository.dart` operating on `/couples/{coupleId}/activity_state/latest`:
- `recordActivity` writes event fields via `set(..., SetOptions(merge: true))` and catches errors safely (best-effort so primary user flows never fail if activity logging fails).
- `setMood` trims/truncates `note` to 40 chars, sets `dateKey = CoupleDateUtils.formatDateKey(now)`, updates `moods.$uid`, and records a `typeMood` activity.
- `sendThinkingOfYouPulse` runs a transaction (with offline fallback) to prepend a `ThinkingOfYouPulse` to `recentPulses` (capped at 10), increment `totalPulsesCount`, and set `lastEventType = typePulse`.
- `sendDailyQuestionNudge` checks 1h cooldown (`canNudgePartner`), updates `nudgeSentAtByUid.$myUid`, and records `typeDailyNudge` targeting `'daily_question'`.
- `syncWidgetSnapshot` merges compact widget summary fields (`daysTogether`, `anniversaryIso`, `partnerName`, `dailyStreak`, `pinnedNoteTitle`, `pinnedNoteContent`, `pinnedNoteAuthor`, `pinnedNoteColor`, `promptText`, `promptStatus`, `isRevealed`, `topTasks`, `remainingTasksCount`) into `widgetSnapshot` keeping total doc well under 2 KB.

- [ ] **Step 4: Wire best-effort `recordActivity` calls into existing feature screens**

Wire `ref.read(activityStateRepositoryProvider).recordActivity(...)` into:
- `DailyQuestionScreen`: after submitting an answer (`typeDailyAnswer`, route `'daily_question'`).
- `CycleScreen`: after `sendCareRequest` (`typeSos`, route `'cycle'`).
- `AdultGamesScreen`: after `sendSpicyNudge` (`typeSpicyNudge`, route `'adult_games'`).
- `NotesScreen`: after saving a note (`typeNote`, route `'notes'`, using `ActivityStateModel.sanitizeNoteBodyForActivity` so unscratched scratch cards never leak secret text).
- `DecideScreen`: after creating a decision ballot (`typeDecide`, route `'decide'`).
- `LoyaltyScreen`: after redeeming a love coupon (`typeCoupon`, route `'loyalty'`).
- `TasksScreen`: after creating a task assigned to partner or shared (`typeTask`, route `'tasks'`).

- [ ] **Step 5: Run tests and verify they pass**

Run: `flutter test --no-pub test/features/home/activity_state_test.dart`
Expected: PASS (all tests green).

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/ lib/features/daily_question/presentation/daily_question_screen.dart lib/features/cycle/presentation/cycle_screen.dart lib/features/adult_games/presentation/adult_games_screen.dart lib/features/notes/presentation/notes_screen.dart lib/features/decide/presentation/decide_screen.dart lib/features/loyalty/presentation/loyalty_screen.dart lib/features/tasks/presentation/tasks_screen.dart test/features/home/activity_state_test.dart
git commit -m "feat(home): add activity_state/latest model, repository, and partner event hooks"
```

---

### Task 2: Daily Streak Computation, Retrospective Integration & Glance Widget Badge

**Files:**
- Create: `lib/core/utils/couple_streak_utils.dart`
- Modify: `lib/features/daily_question/data/daily_question_repository.dart`
- Modify: `lib/features/daily_question/presentation/daily_question_screen.dart`
- Modify: `lib/features/stats/presentation/couple_stats_screen.dart`
- Modify: `lib/features/widgets/widget_sync_service.dart`
- Modify: `android/app/src/main/kotlin/com/personal/couple_app/CoupleGlanceWidget.kt`
- Test: `test/core/utils/couple_streak_utils_test.dart`

**Interfaces:**
- Consumes: `DailyQuestionModel` (`lib/features/daily_question/domain/daily_question_model.dart`), `activityStateStreamProvider` (Task 1).
- Produces:
  - `CoupleStreakUtils.calculateDailyStreak(Iterable<DailyQuestionModel> questions, {DateTime? now}) -> int`.
  - `dailyStreakProvider = Provider.family<int, String>` in `lib/features/daily_question/data/daily_question_repository.dart`.
  - `WidgetSyncService.syncCoupleStats(..., int dailyStreak = 0)` and `daily_streak` key saved to `HomeWidget` + rendered in `CoupleGlanceWidget.kt`.

- [ ] **Step 1: Write the failing unit tests**

Create `test/core/utils/couple_streak_utils_test.dart` covering:
- Empty list -> `0`.
- Consecutive revealed questions ending today (3 days) -> `3`.
- Consecutive revealed questions ending yesterday (today not answered yet) -> `2` (does not reset before midnight).
- Gap of 2 days (last revealed 2 days ago) -> `0`.
- Unrevealed questions do not count toward streak.
- Duplicate date entries or unsorted order produce exact streak without double-counting.
- `CoupleStatsSummary` includes `dailyStreak` and `totalPulsesCount` (with backward-compatible default `0`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/core/utils/couple_streak_utils_test.dart`
Expected: FAIL (missing `couple_streak_utils.dart`).

- [ ] **Step 3: Implement `CoupleStreakUtils` and `dailyStreakProvider`**

Create `lib/core/utils/couple_streak_utils.dart` implementing `calculateDailyStreak`:
- Collect unique `YYYY-MM-DD` keys where `q.isRevealed == true`.
- Anchor at `today` if `todayKey` is present, else `yesterday` if `yesterdayKey` is present, else return `0`.
- Walk backward day by day while `revealedKeys.contains(formatDateKey(cursor))`.

Add `dailyStreakProvider = Provider.family<int, String>` in `lib/features/daily_question/data/daily_question_repository.dart` combining `todayDailyQuestionProvider(coupleId)` and `pastDailyQuestionsProvider(coupleId)`.

- [ ] **Step 4: Surface streak in `DailyQuestionScreen`, `CoupleStatsScreen`, `WidgetSyncService`, and `CoupleGlanceWidget.kt`**

- `DailyQuestionScreen`: display a compact `🔥 $streak` streak chip in the header when `streak > 0`.
- `CoupleStatsScreen`: extend `CoupleStatsSummary` with `dailyStreak` and `totalPulsesCount` (default `0`), read `dailyStreakProvider` + `activityStateStreamProvider`, add stat tiles for **"Ofensiva Diária 🔥"** and **"Carinhos Enviados 💓"**.
- `WidgetSyncService`: pass `dailyStreak` (from `dailyStreakProvider` inside `widgetSyncProvider`) into `syncAllWidgets` / `syncCoupleStats` saving `daily_streak` (`int`), clear it in `clearAllWidgets()`, and push widget summary snapshot to `ActivityStateRepository.syncWidgetSnapshot` inside `widgetSyncProvider`.
- `CoupleGlanceWidget.kt`: read `daily_streak` from `HomeWidget` prefs and render a compact `🔥 $dailyStreak dias` / `🔥 $dailyStreak day streak` pill when `dailyStreak > 0`.

- [ ] **Step 5: Run tests and verify they pass**

Run: `flutter test --no-pub test/core/utils/couple_streak_utils_test.dart test/features/widgets/widget_sync_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/utils/couple_streak_utils.dart lib/features/daily_question/ lib/features/stats/presentation/couple_stats_screen.dart lib/features/widgets/widget_sync_service.dart android/app/src/main/kotlin/com/personal/couple_app/CoupleGlanceWidget.kt test/core/utils/couple_streak_utils_test.dart
git commit -m "feat(streak): compute daily revealed streak and surface in daily question, stats, and CoupleGlanceWidget"
```

---

### Task 3: Couple Profile & Avatar Editing + Shared `PartnerAvatarWidget`

**Files:**
- Create: `lib/core/widgets/partner_avatar_widget.dart`
- Create: `lib/features/auth/presentation/edit_couple_profile_sheet.dart`
- Modify: `lib/features/auth/data/pairing_repository.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `lib/features/daily_question/presentation/daily_question_screen.dart`
- Modify: `lib/main.dart` (Hub hero header avatars & edit shortcut)
- Test: `test/features/auth/couple_profile_avatar_test.dart`

**Interfaces:**
- Consumes: `PhotoBudgetUtils.decodeCachedBase64` (`lib/core/utils/photo_budget_utils.dart`), `CoupleModel` & `PartnerProfile`, `CalendarEventModel.categoryAnniversary`.
- Produces:
  - `PartnerAvatarWidget({required String name, String? avatarUrl, double radius, Color? accentColor})` supporting `data:image/...;base64,`, `http(s)://`, and styled initials fallback.
  - `PairingRepository.maxAvatarDataUriBytes = 80 * 1024`, `PairingRepository.isValidAvatarDataUri(String dataUri) -> bool`.
  - `PairingRepository.updatePartnerProfile(String coupleId, String uid, {String? name, String? avatarUrl, bool clearAvatar = false})`.
  - `PairingRepository.updateAnniversaryDate(String coupleId, DateTime anniversaryDate)`.
  - `showEditCoupleProfileSheet(BuildContext context, {required String coupleId, required CoupleModel couple, required String myUid})`.

- [ ] **Step 1: Write the failing unit & widget tests**

Create `test/features/auth/couple_profile_avatar_test.dart` covering:
- `PairingRepository.isValidAvatarDataUri` accepting a valid small `data:image/jpeg;base64,...` URI and rejecting payloads over 80 KB or non-image strings.
- `PartnerAvatarWidget` rendering initials when `avatarUrl` is null/empty.
- `PartnerAvatarWidget` rendering a `MemoryImage` avatar without throwing when given a valid 1x1 PNG Base64 Data URI, and falling back to initials on malformed Base64.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/auth/couple_profile_avatar_test.dart`
Expected: FAIL (missing `partner_avatar_widget.dart` and `isValidAvatarDataUri`).

- [ ] **Step 3: Implement `PartnerAvatarWidget`, `PairingRepository` profile/anniversary methods, and `EditCoupleProfileSheet`**

- Create `lib/core/widgets/partner_avatar_widget.dart`:
  - Uses `PhotoBudgetUtils.decodeCachedBase64` for `data:image/` or `base64:` strings.
  - Uses `NetworkImage` with `onBackgroundImageError` fallback for `http://` / `https://`.
  - Renders stylized initials (`first 1–2 chars uppercase`) when empty or decode fails.
- Update `lib/features/auth/data/pairing_repository.dart`:
  - Add `maxAvatarDataUriBytes = 80 * 1024` and `isValidAvatarDataUri`.
  - Add `updatePartnerProfile` updating `partnerProfiles.$uid` via transaction/merge without touching the other partner's profile.
  - Add `updateAnniversaryDate` updating `anniversaryDate` on `/couples/{coupleId}` and updating (or creating if missing) the `category == 'anniversary'` event in `/couples/{coupleId}/calendar_events`.
- Create `lib/features/auth/presentation/edit_couple_profile_sheet.dart`:
  - Modal bottom sheet with avatar preview + "Escolher foto" (`ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256, imageQuality: 70)`) + "Remover foto", TextField for name/nickname (disposed cleanly), DatePicker tile for `anniversaryDate`, and Save button with loading state & validation feedback.
- Add profile/home/sync localization getters to `lib/core/l10n/app_strings.dart`.
- Update `CoupleHubScreen` hero card in `lib/main.dart` and avatar builder in `DailyQuestionScreen` to use `PartnerAvatarWidget` and expose the Edit Profile action.

- [ ] **Step 4: Run tests and verify they pass**

Run: `flutter test --no-pub test/features/auth/couple_profile_avatar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/partner_avatar_widget.dart lib/features/auth/presentation/edit_couple_profile_sheet.dart lib/features/auth/data/pairing_repository.dart lib/core/l10n/app_strings.dart lib/features/daily_question/presentation/daily_question_screen.dart lib/main.dart test/features/auth/couple_profile_avatar_test.dart
git commit -m "feat(profile): add PartnerAvatarWidget and couple profile/avatar/anniversary editing"
```

---

### Task 4: New Tab 0 "Nosso Dia" (`CoupleHomeScreen`), Navigation Badges & Live Partner Alert Banner

**Files:**
- Create: `lib/features/home/presentation/couple_home_screen.dart`
- Modify: `lib/core/notifications/notification_route_provider.dart`
- Modify: `lib/main.dart`
- Test: `test/features/home/couple_home_screen_test.dart`

**Interfaces:**
- Consumes:
  - `ActivityStateModel`, `PartnerMood`, `activityStateStreamProvider`, `activityStateRepositoryProvider` (Task 1).
  - `dailyStreakProvider` (Task 2).
  - `PartnerAvatarWidget`, `showEditCoupleProfileSheet` (Task 3).
  - `coupleStreamProvider`, `currentUserUidProvider`, `todayDailyQuestionProvider`, `cycleDataStreamProvider`, `adultGameSessionStreamProvider`, `decideSessionsStreamProvider`, `loyaltyCouponsStreamProvider`, `notesStreamProvider`, `tasksStreamProvider`, `calendarEventsStreamProvider`.
- Produces:
  - `CoupleHomeScreen({required String coupleId, required ValueChanged<int> onSwitchTab, String? currentUid})`.
  - Pure badge helpers in `lib/features/home/presentation/couple_home_screen.dart` (or `lib/features/home/domain/home_badge_utils.dart`): `countPendingTasks(List<TaskModel>)`, `countOpenBallotsNeedingVote(List<DecideSessionModel>, String myUid)`, `shouldShowLivePartnerBanner({required ActivityStateModel state, required String myUid, required String? lastSeenEventId})`.
  - Updated `parseRouteToTabIndex`: `'home'` and `'couple'` -> `0`; `'daily_question'` -> `null` (so `_handleRoute` pushes `DailyQuestionScreen` cleanly); `'loyalty'` handled in `_handleRoute`.

- [ ] **Step 1: Write the failing unit & widget tests**

Create `test/features/home/couple_home_screen_test.dart` covering:
- `parseRouteToTabIndex('couple') == 0`, `parseRouteToTabIndex('home') == 0`, `parseRouteToTabIndex('daily_question') == null` (pushes `DailyQuestionScreen`).
- `shouldShowLivePartnerBanner`: returns `false` when `lastSeenEventId == null` (initial seed), `false` when `lastActorUid == myUid`, `false` when `lastEventId == lastSeenEventId`, and `true` when a new event arrives from the partner.
- `countPendingTasks` and `countOpenBallotsNeedingVote` returning exact badge counts (ignoring completed tasks, resolved ballots, and ballots already voted on by `myUid`).
- Widget test pumping `CoupleHomeScreen` with overridden Riverpod providers verifying:
  - Couple header with both names, days together, and 🔥 streak badge renders.
  - Active SOS banner renders and hides when cleared.
  - Active Spicy Nudge from partner renders.
  - Unscratched scratch card pinned note from partner shows masked preview text, never secret content.
  - Daily Question card shows status and navigates on tap.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/home/couple_home_screen_test.dart`
Expected: FAIL (missing `couple_home_screen.dart` and updated route mapping).

- [ ] **Step 3: Implement `CoupleHomeScreen`, badge helpers, deep-link update, and live banner in `MainNavigationShell`**

- Create `lib/features/home/presentation/couple_home_screen.dart`:
  1. **Couple Header:** overlapping/side-by-side `PartnerAvatarWidget`s, couple names, days together, 🔥 streak pill, edit-profile icon button.
  2. **Conditional Active Attention Banners:**
     - SOS Carinho (`cycle.activeCareRequest != null && cycle.activeCareRequest!.isNotEmpty`): button *"Estou indo cuidar 💕"* calling `CycleRepository.clearCareRequest`.
     - Convite Picante (`session.nudgeMessage != null && session.nudgeSenderUid != myUid`): buttons *"Abrir jogo 🔥"* and *"Dispensar"* (`AdultGamesRepository.clearNudge`).
     - Open Decide Ballot (`openBallotsNeedingVote > 0`): tapping switches to Tab 3.
     - Recently Redeemed Coupon (within 24h, `lastRedeemedBy != myUid`): tapping pushes `LoyaltyScreen`.
  3. **"Como estamos hoje" Presence Card:**
     - Today's mood for me and partner (`activityState.activeMoodFor(uid)`), interactive mood chip selector (`PartnerMood.presets`) + optional 40-char note dialog/input.
     - **"Enviar Carinho / Tô com Saudade 💓"** button with `HapticFeedback.mediumImpact()`, animated floating hearts burst, lifetime counter, and expandable recent pulses list.
  4. **Daily Question Highlight Card:**
     - Live status (*"Responda hoje ✍️"*, *"Aguardando <Parceiro> 🔒"* + **"Cutucar"** button honoring 1h cooldown via `canNudgePartner`, or *"Revelado! Toque para ver 💕"*), tapping pushes `DailyQuestionScreen(coupleId: coupleId)`.
  5. **Compact Live Summary Cards:**
     - Pinned Note preview (masked via `WidgetSyncService.formatNoteForWidget` when unscratched scratch card and `authorUid != myUid`) -> pushes `NotesScreen`.
     - Top 2 urgent incomplete tasks -> `onSwitchTab(1)`.
     - Next upcoming calendar event with days countdown -> `onSwitchTab(2)`.
- Update `lib/core/notifications/notification_route_provider.dart`:
  - `parseRouteToTabIndex`: `'home'` and `'couple'` -> `0`; `'daily_question'` -> `null`.
- Update `lib/main.dart`:
  - Replace Tab 0 child in `IndexedStack` with `CoupleHomeScreen(coupleId: coupleId, onSwitchTab: (i) => setState(() => _currentIndex = i))`.
  - Update `_handleRoute`: `'daily_question'` switches to Tab 0 and pushes `DailyQuestionScreen(coupleId: coupleId)`; `'loyalty'` pushes `LoyaltyScreen(coupleId: coupleId)`.
  - Add `Badge` to Tab 1 (`countPendingTasks`) and Tab 3 (`countOpenBallotsNeedingVote`) in `NavigationBar`.
  - Add top animated live partner alert banner in `MainNavigationShell` listening to `activityStateStreamProvider(coupleId)` with initial-seed guard (`_hasSeededActivityState`) so no stale banner fires on launch.

- [ ] **Step 4: Run tests and verify they pass**

Run: `flutter test --no-pub test/features/home/couple_home_screen_test.dart test/core/notifications/notification_route_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/couple_home_screen.dart lib/core/notifications/notification_route_provider.dart lib/main.dart test/features/home/couple_home_screen_test.dart test/core/notifications/notification_route_test.dart
git commit -m "feat(home): launch Nosso Dia Tab 0 dashboard, navigation badges, and live partner alert banner"
```

---

### Task 5: Dual Android Notification Channels, Samsung One UI Guide & `WorkManager` Background Sync

**Files:**
- Modify: `pubspec.yaml` (add `workmanager`, `shared_preferences`)
- Modify: `android/app/src/main/AndroidManifest.xml` (add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`)
- Modify: `android/app/src/main/kotlin/com/personal/couple_app/MainActivity.kt` (add Samsung battery optimization & exact alarm settings intents via `MethodChannel`)
- Modify: `lib/core/notifications/local_notification_service.dart` (2 Android channels: `krivo_urgent_partner_channel` vs `krivo_couples_channel`, plus `showPartnerAlert`)
- Create: `lib/core/services/background_sync_service.dart`
- Modify: `lib/features/auth/data/pairing_repository.dart` (clear background sync & prefs on `unpairCurrentUser`)
- Modify: `lib/main.dart` (initialize `BackgroundSyncService`, register periodic sync when paired, add "Garantir alertas no Samsung" guide card in Hub → Preferências)
- Test: `test/core/services/background_sync_service_test.dart`

**Interfaces:**
- Consumes: `ActivityStateModel` (Task 1), `FirebaseConfig.initialize`, `LocalNotificationService`, `WidgetSyncService`.
- Produces:
  - `LocalNotificationService.urgentChannelId = 'krivo_urgent_partner_channel'`, `LocalNotificationService.routineChannelId = 'krivo_couples_channel'`.
  - `LocalNotificationService.channelIdForEventType(String eventType) -> String`.
  - `LocalNotificationService.showPartnerAlert({required String eventId, required String eventType, required String title, required String body, required String route})`.
  - `BackgroundSyncService`: `initialize()`, `registerPeriodicSync({required String coupleId, required String myUid, required bool isPortuguese})`, `cancelPeriodicSync()`, `processActivityPayload(...)` (pure unit-testable evaluator).

- [ ] **Step 1: Add `workmanager` and `shared_preferences` dependencies & fetch packages**

Add `workmanager` and `shared_preferences` to `pubspec.yaml` and run `flutter pub get`.

- [ ] **Step 2: Write the failing unit tests**

Create `test/core/services/background_sync_service_test.dart` covering:
- `LocalNotificationService.channelIdForEventType`: `'sos'`, `'pulse'`, `'spicy_nudge'` route to `urgentChannelId`; `'daily_answer'`, `'task'`, `'note'`, `'decide'`, `'coupon'` route to `routineChannelId`.
- `BackgroundSyncService.processActivityPayload`:
  - Fires notification and persists new `lastEventId` when `lastActorUid != myUid` and `lastEventId != lastNotifiedEventId`.
  - Skips notification when `lastActorUid == myUid` (never self-notifies).
  - Skips notification when `lastEventId == lastNotifiedEventId` (idempotent dedupe).
  - Still updates Glance widgets from `widgetSnapshot` even when no new notification is fired.
  - Handles empty/missing `lastEventId` or empty `widgetSnapshot` without throwing.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test --no-pub test/core/services/background_sync_service_test.dart`
Expected: FAIL (missing `background_sync_service.dart` and `channelIdForEventType`).

- [ ] **Step 4: Implement dual channels, `BackgroundSyncService`, Android manifest/MainActivity helpers, and Hub Samsung card**

- Update `lib/core/notifications/local_notification_service.dart`:
  - Define `urgentChannelId = 'krivo_urgent_partner_channel'` (**"Urgentes do Par"**, `Importance.max`) and `routineChannelId = 'krivo_couples_channel'` (**"Rotina do Casal"**, `Importance.high`).
  - Create both channels in `initialize()`.
  - Add `channelIdForEventType(String eventType)` and `showPartnerAlert(...)`.
- Create `lib/core/services/background_sync_service.dart`:
  - Top-level `@pragma('vm:entry-point') void backgroundSyncCallbackDispatcher()`.
  - `processActivityPayload` pure function for dedupe + partner alert + widget snapshot update.
  - `runBackgroundSyncOnce`: reads `bg_couple_id`, `bg_my_uid`, `bg_is_pt`, `last_notified_event_id` from `SharedPreferences`; returns `true` immediately if unpaired (`bg_couple_id` empty); calls `FirebaseConfig.initialize()`; fetches **1 doc** `/couples/{coupleId}/activity_state/latest`; executes `processActivityPayload`; updates Glance widgets via `HomeWidget`.
  - `registerPeriodicSync` saves `bg_couple_id`, `bg_my_uid`, `bg_is_pt` to `SharedPreferences` and registers a 15-minute `Workmanager().registerPeriodicTask` (`ExistingPeriodicWorkPolicy.keep`, `Constraints(networkType: NetworkType.connected)`).
  - `cancelPeriodicSync` cancels the task and clears `bg_*` keys from `SharedPreferences`.
- Update `android/app/src/main/AndroidManifest.xml` adding `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- Update `android/app/src/main/kotlin/com/personal/couple_app/MainActivity.kt` adding a `MethodChannel("com.personal.couple_app/device_settings")` handling:
  - `isIgnoringBatteryOptimizations` (`PowerManager.isIgnoringBatteryOptimizations`)
  - `openBatteryOptimizationSettings` (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` with fallback to `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`)
  - `openExactAlarmSettings` (`ACTION_REQUEST_SCHEDULE_EXACT_ALARM` on Android 12+ with fallback to app details)
- Update `lib/features/auth/data/pairing_repository.dart`: invoke `BackgroundSyncService.cancelPeriodicSync()` inside `unpairCurrentUser`.
- Update `lib/main.dart`:
  - Call `await BackgroundSyncService.initialize();` in `main()`.
  - Call `BackgroundSyncService.registerPeriodicSync(...)` when paired session starts (and when locale/uid changes).
  - Add the **"Garantir alertas no Samsung"** guide card inside `CoupleHubScreen` → Preferências with 2 direct action buttons (Battery Optimization Exemption + Exact Alarms / Notification Channels).

- [ ] **Step 5: Run tests, analyzer, and debug APK build**

Run:
1. `flutter test --no-pub` -> Expected: all tests PASS.
2. `flutter analyze --no-pub` -> Expected: 0 errors, 0 warnings.
3. `flutter build apk --debug` -> Expected: `Built build\app\outputs\flutter-apk\app-debug.apk`.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/personal/couple_app/MainActivity.kt lib/core/notifications/local_notification_service.dart lib/core/services/background_sync_service.dart lib/features/auth/data/pairing_repository.dart lib/main.dart test/core/services/background_sync_service_test.dart
git commit -m "feat(sync): add WorkManager 15-min background sync, dual Android notification channels, and Samsung reliability guide"
```
