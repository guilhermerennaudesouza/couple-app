# Phase 3 — Paridade de Features Assinatura do Krivo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver Krivo's signature couple features: realtime fullscreen "Desenhar Juntos" synced to Android `NoteGlanceWidget` on both phones + gallery export, "Tinder de Encontros" swipe deck with ~40 curated PT-BR ideas & "Deu Match!" → Calendar scheduling, interactive Daily Question (reactions, comments, hidden future custom prompts, search, countdown, nudge), and complete Edit flows across all remaining modules with PT-BR/EN localization.

**Architecture:** Realtime drawing uses `/couples/{coupleId}/shared_canvas/current` (normalized simplified strokes capped under ~200 KB) plus `/couples/{coupleId}/shared_canvas/widget_snapshot` (compressed ~60 KB PNG Base64) referenced by `drawingWidgetRevision` & `noteWidgetMode` inside `activity_state/latest`, so `WorkManager` performs a conditional 2nd read only when a new drawing is pinned. Swipe date ideas embed a 40-item PT-BR curated deck in app code and only write to Firestore `date_ideas` on swipe interaction. Custom daily questions are pre-bound to the next unused future `YYYY-MM-DD` date and filtered out of past archives until that date arrives.

**Tech Stack:** Flutter 3.x, Riverpod, Cloud Firestore (Spark $0), `dart:ui` (`PictureRecorder`), Android `MediaStore` (via `MainActivity` `MethodChannel`), Android Jetpack Glance (`BitmapFactory` + `ImageProvider`), `path_provider`, `workmanager`.

**Spec:** `docs/superpowers/specs/2026-11-19-krivo-parity-and-stabilization-design.md` (Section 5 — Fase 3)

## Global Constraints

- **Firebase Free Spark Tier (R$ 0):** No Storage bucket, no Cloud Functions. Strokes doc capped <= 200 KB; widget PNG snapshot capped <= 120 KB Base64.
- **Last-pinned wins widget mode:** Pinning a drawing sets `noteWidgetMode = 'drawing'`; pinning a love note sets `noteWidgetMode = 'note'`, synced for both partners.
- **Hidden future custom prompts:** Custom questions must stay concealed in past archives and never leak before their scheduled `YYYY-MM-DD` date arrives.
- **Curated swipe catalog isolation:** Built-in ~40 PT-BR ideas must never bulk-write into `/couples/{coupleId}/date_ideas`; only swiped/matched cards are persisted.
- **Zero data loss & backward compatibility:** Existing `date_ideas`, `daily_questions`, `notes`, `tasks`, `finance_entries`, `savings_goals`, `memories`, `wishlist`, `vault_items`, and `loyalty_coupons` documents must load with safe defaults.
- **Release build gate:** Validate `flutter build apk --release` (R8/ProGuard) at phase completion.

## Review Focus

1. **Stroke payload explosion on fast finger drawing:** Simplify points by minimum normalized distance and trim oldest strokes if JSON exceeds 200 KB so `/shared_canvas/current` never approaches Firestore's 1 MB limit.
2. **Drawing widget corruption / missing PNG file in Glance:** `NoteGlanceWidget.kt` must safely handle a missing, unreadable, or corrupt `drawing_image_path` file by falling back to the note/empty card without crashing Glance.
3. **Custom future question leak in archive or streak:** `watchPastQuestions` must strictly require `dq.date.compareTo(today) < 0` so future custom questions stay hidden surprises and never inflate past count or streak.
4. **Swipe Match race condition:** Recording a `'like'` vote must use a Firestore transaction (with cache fallback) so simultaneous right-swipes from both partners reliably set `matchedAt` and surface "Deu Match! 💕".
5. **Edit flows preserving metadata & disposing controllers:** Editing existing Tasks, Checklists, Expenses, Goals, Memories, Wishes, Vault items, and Coupons must preserve IDs/timestamps/settlement/used counts and dispose all modal `TextEditingController`s cleanly.

---

### Task 1: Desenhar Juntos em Tempo Real + Widget de Desenho + Salvar na Galeria

**Files:**
- Modify: `pubspec.yaml` (promote `path_provider` to direct dependency)
- Create: `lib/features/drawing/domain/shared_canvas_model.dart`
- Create: `lib/features/drawing/data/shared_canvas_repository.dart`
- Create: `lib/features/drawing/presentation/drawing_together_screen.dart`
- Modify: `lib/features/home/domain/activity_state_model.dart` (add `typeDrawing`, `noteWidgetMode`)
- Modify: `lib/features/notes/presentation/notes_screen.dart` (set `noteWidgetMode = 'note'` when pinning a note)
- Modify: `lib/features/widgets/widget_sync_service.dart` (sync `widget_mode` & `drawing_image_path`, `applyDrawingSnapshotBytes`)
- Modify: `lib/core/services/background_sync_service.dart` (conditional 2nd read on `shared_canvas/widget_snapshot` only when `drawingWidgetRevision` increments)
- Modify: `android/app/src/main/kotlin/com/personal/couple_app/NoteGlanceWidget.kt` (render drawing Bitmap when `widget_mode == "drawing"`, clickable route `"drawing"`)
- Modify: `android/app/src/main/kotlin/com/personal/couple_app/MainActivity.kt` (`saveImageToGallery` via `MediaStore`)
- Modify: `lib/features/home/presentation/couple_home_screen.dart` (shortcut to Desenhar Juntos)
- Modify: `lib/main.dart` (Hub card for Desenhar Juntos + `'drawing'` deep-link route + foreground sync of remote `drawingWidgetRevision`)
- Modify: `lib/core/l10n/app_strings.dart` (Phase 3 PT-BR/EN strings)
- Test: `test/features/drawing/shared_canvas_test.dart`

**Interfaces:**
- Consumes: `ActivityStateModel` (`drawingWidgetRevision`, `noteWidgetMode`), `ActivityStateRepository`, `WidgetSyncService`, `BackgroundSyncService`.
- Produces:
  - `CanvasPoint`, `CanvasStroke`, `SharedCanvasModel`, `DrawingWidgetSnapshotModel`.
  - `SharedCanvasModel.simplifyPoints(List<CanvasPoint>, {double minDistance})` and `SharedCanvasModel.trimStrokesToBudget(List<CanvasStroke>, {int maxBytes})`.
  - `SharedCanvasRepository` + `sharedCanvasRepositoryProvider` + `sharedCanvasStreamProvider`.
  - `DrawingTogetherScreen({required String coupleId, String? currentUid})`.
  - `WidgetSyncService.syncDrawingSnapshotToWidget({required Uint8List pngBytes, required String authorName, required bool isPortuguese})`.
  - `BackgroundSyncService.shouldFetchDrawingSnapshot({required ActivityStateModel state, required int lastAppliedRevision}) -> bool`.

- [ ] **Step 1: Write failing tests in `test/features/drawing/shared_canvas_test.dart`**
- [ ] **Step 2: Run test to confirm RED**
- [ ] **Step 3: Implement `SharedCanvasModel`, `SharedCanvasRepository`, `DrawingTogetherScreen`, `NoteGlanceWidget.kt` drawing mode, `MainActivity.kt` `saveImageToGallery`, foreground/background conditional snapshot sync, and Home/Hub/route integration**
- [ ] **Step 4: Run tests and verify GREEN**
- [ ] **Step 5: Commit**

---

### Task 2: Swipe de Ideias de Encontros ("Tinder de Encontros") + Catálogo 40 PT-BR + Match → Calendário + Sortear

**Files:**
- Create: `lib/features/date_ideas/data/curated_date_ideas_catalog.dart`
- Modify: `lib/features/date_ideas/domain/date_idea_model.dart` (add `votes`, `matchedAt`, `isMatched`, `userVote`, `likeCount`)
- Modify: `lib/features/date_ideas/data/date_ideas_repository.dart` (`recordSwipeVote`, `resetPassedVotes`, `buildSwipeDeck`, `pickRandomIdea`)
- Create: `lib/features/decide/presentation/date_ideas_swipe_view.dart`
- Modify: `lib/features/decide/presentation/decide_screen.dart` (toggle Swipe vs List, Match modal → schedule in Calendar, Random Picker 🎲, Review Passed button)
- Test: `test/features/date_ideas/date_ideas_swipe_test.dart`

**Interfaces:**
- Consumes: `CalendarRepository.addEvent`, `ActivityStateRepository.recordActivity`, `DateIdeaModel`.
- Produces:
  - `kCuratedDateIdeasPtBr` (40 curated PT-BR ideas across Cozy, Outdoor, Foodie, Romance, Adventurous, Budget).
  - `DateIdeaModel.votes`, `matchedAt`, `isMatched`, `userVote(String uid)`.
  - `DateIdeasRepository.buildSwipeDeck({required List<DateIdeaModel> coupleIdeas, required String myUid})`.
  - `DateIdeasRepository.recordSwipeVote(String coupleId, DateIdeaModel idea, {required String uid, required String vote}) -> Future<bool>` (`true` when vote produces a new match).
  - `DateIdeasRepository.resetPassedVotes(String coupleId, String uid)`.
  - `DateIdeasRepository.pickRandomIdea(List<DateIdeaModel> ideas, {Random? random}) -> DateIdeaModel?`.
  - `DateIdeasSwipeView` widget.

- [ ] **Step 1: Write failing tests in `test/features/date_ideas/date_ideas_swipe_test.dart`**
- [ ] **Step 2: Run test to confirm RED**
- [ ] **Step 3: Implement curated catalog, model/repository swipe & match logic, and `DateIdeasSwipeView` + `DecideScreen` integration**
- [ ] **Step 4: Run tests and verify GREEN**
- [ ] **Step 5: Commit**

---

### Task 3: Pergunta do Dia Interativa (Reações, Comentários, Perguntas Personalizadas Futuras, Busca, Cutucar & Contagem Regressiva)

**Files:**
- Modify: `lib/features/daily_question/domain/daily_question_model.dart` (`DailyQuestionComment`, `reactions`, `comments`, `isCustom`, `proposedByUid`)
- Modify: `lib/features/daily_question/data/daily_question_repository.dart` (`toggleReaction`, `addComment`, `findNextAvailableFutureDateKey`, `proposeCustomQuestion`, filter future dates out of `watchPastQuestions`)
- Modify: `lib/features/daily_question/presentation/daily_question_screen.dart` (reactions bar, comments thread, propose custom surprise question modal, nudge button with 1h cooldown in State 2, search bar in Past Memories, countdown timer to next question, recordActivity on past-question answer)
- Test: `test/features/daily_question/daily_question_interactive_test.dart`

**Interfaces:**
- Consumes: `ActivityStateRepository.sendDailyQuestionNudge`, `ActivityStateModel.canNudgePartner`, `CoupleDateUtils.formatDateKey`.
- Produces:
  - `DailyQuestionComment` (`id`, `uid`, `authorName`, `text`, `createdAt`).
  - `DailyQuestionModel.reactionOptions = ['❤️', '😂', '🥺', '🔥', '😍']`.
  - `DailyQuestionRepository.findNextAvailableFutureDateKey(Set<String> occupiedDateKeys, {DateTime? now}) -> String`.
  - `DailyQuestionRepository.proposeCustomQuestion(String coupleId, {required String prompt, required String proposedByUid}) -> Future<String>` (returns assigned `YYYY-MM-DD`).
  - `DailyQuestionRepository.filterPastQuestions(List<DailyQuestionModel> items, {required String todayKey, String query}) -> List<DailyQuestionModel>`.

- [ ] **Step 1: Write failing tests in `test/features/daily_question/daily_question_interactive_test.dart`**
- [ ] **Step 2: Run test to confirm RED**
- [ ] **Step 3: Implement model extensions, repository methods, and `DailyQuestionScreen` interactive UI**
- [ ] **Step 4: Run tests and verify GREEN**
- [ ] **Step 5: Commit**

---

### Task 4: Fluxos de Edição Completos (8 Módulos) + Localização PT-BR/EN v1.0.4 + Release APK Build Check

**Files:**
- Modify: `lib/features/tasks/presentation/tasks_screen.dart` (Edit Task + Edit Checklist title/category)
- Modify: `lib/features/finance/presentation/finance_screen.dart` (Edit Expense + Edit Savings Goal + use `parseBrlCurrency` across all currency inputs)
- Modify: `lib/features/memories/presentation/memories_screen.dart` (Edit Memory + Edit Wish)
- Modify: `lib/features/vault/presentation/vault_screen.dart` (Edit unlocked Vault Item re-encrypting with active key)
- Modify: `lib/features/loyalty/presentation/loyalty_screen.dart` (Edit Love Coupon + PT-BR/EN localization)
- Modify: `lib/features/adult_games/presentation/adult_games_screen.dart` (PT-BR/EN localization)
- Modify: `lib/features/cycle/presentation/cycle_screen.dart` (PT-BR/EN localization)
- Modify: `lib/features/stats/presentation/couple_stats_screen.dart` (PT-BR/EN localization)
- Test: `test/features/phase3_edit_and_l10n_test.dart`

**Interfaces:**
- Consumes: `TaskRepository.updateTask` / `updateList`, `FinanceRepository.addExpense` / `createSavingsGoal`, `MemoriesRepository.updateMemory` / `updateWish`, `VaultRepository.saveVaultItem`, `LoyaltyRepository.addCoupon`, `parseBrlCurrency`, `AppStrings`.
- Produces: Complete edit flows across all 8 entities + localized v1.0.4 headers/labels + verified `flutter build apk --release`.

- [ ] **Step 1: Write failing tests in `test/features/phase3_edit_and_l10n_test.dart`**
- [ ] **Step 2: Run test to confirm RED**
- [ ] **Step 3: Implement all 8 edit flows and v1.0.4 PT-BR/EN localization**
- [ ] **Step 4: Run full test suite, `flutter analyze --no-pub --no-fatal-infos`, `flutter build apk --debug`, and `flutter build apk --release`**
- [ ] **Step 5: Commit**
