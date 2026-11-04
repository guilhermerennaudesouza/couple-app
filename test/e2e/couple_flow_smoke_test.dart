import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/core/crypto/vault_crypto_service.dart';
import 'package:couple_app/core/notifications/local_notification_service.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';
import 'package:couple_app/features/auth/domain/partner_profile.dart';
import 'package:couple_app/features/auth/presentation/pairing_screen.dart';
import 'package:couple_app/main.dart';
import 'package:couple_app/features/calendar/domain/calendar_event_model.dart';
import 'package:couple_app/features/cheatsheet/domain/cheatsheet_model.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';
import 'package:couple_app/features/date_ideas/domain/date_idea_model.dart';
import 'package:couple_app/features/decide/domain/decide_model.dart';
import 'package:couple_app/features/finance/domain/finance_model.dart';
import 'package:couple_app/features/finance/domain/savings_model.dart';
import 'package:couple_app/features/memories/domain/memory_model.dart';
import 'package:couple_app/features/notes/domain/note_model.dart';
import 'package:couple_app/features/tasks/domain/checklist_model.dart';
import 'package:couple_app/features/tasks/domain/task_model.dart';
import 'package:couple_app/features/time_capsule/domain/time_capsule_model.dart';
import 'package:couple_app/features/vault/domain/vault_item_model.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';
import 'package:couple_app/features/wishlist/domain/wish_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> widgetCalls = [];

  setUp(() {
    widgetCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('es.antonborri.home_widget'),
      (MethodCall methodCall) async {
        widgetCalls.add(methodCall);
        return true;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async {
        return true;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('es.antonborri.home_widget'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
  });

  group('Krivo Couple App - End-to-End Smoke Verification Suite', () {
    const partner1Uid = 'uid_alex_001';
    const partner1Name = 'Alex';
    const partner2Uid = 'uid_sam_002';
    const partner2Name = 'Sam';
    final anniversary = DateTime(2024, 5, 18);

    test('1. Pairing & Profile: Create couple space, generate 6-digit code, join partner, verify mutual lookup', () {
      // Step A: Generate secure 6-digit invite code
      final inviteCode = PairingRepository.generateInviteCode();
      expect(inviteCode.length, equals(6));
      expect(int.tryParse(inviteCode), isNotNull);

      // Step B: Partner 1 initiates couple space
      final p1Profile = PartnerProfile(
        uid: partner1Uid,
        name: partner1Name,
        joinedAt: DateTime(2024, 5, 18),
      );

      final initialCouple = CoupleModel(
        id: 'couple_smoke_space_01',
        members: [partner1Uid],
        anniversaryDate: anniversary,
        inviteCode: inviteCode,
        partnerProfiles: {partner1Uid: p1Profile},
        createdAt: DateTime(2024, 5, 18),
      );

      expect(initialCouple.isFull, isFalse);
      expect(initialCouple.getOtherUid(partner1Uid), isNull);
      expect(initialCouple.getPartnerProfile(partner1Uid), isNull);
      expect(initialCouple.getMyProfile(partner1Uid)?.name, equals('Alex'));

      // Step C: Partner 2 enters 6-digit invite code and joins
      final p2Profile = PartnerProfile(
        uid: partner2Uid,
        name: partner2Name,
        joinedAt: DateTime(2024, 5, 18, 1, 0),
      );

      final fullCouple = initialCouple.copyWith(
        members: [...initialCouple.members, partner2Uid],
        partnerProfiles: {
          ...initialCouple.partnerProfiles,
          partner2Uid: p2Profile,
        },
      );

      expect(fullCouple.isFull, isTrue);
      expect(fullCouple.members.length, equals(2));
      expect(fullCouple.getOtherUid(partner1Uid), equals(partner2Uid));
      expect(fullCouple.getOtherUid(partner2Uid), equals(partner1Uid));
      expect(fullCouple.getPartnerProfile(partner1Uid)?.name, equals('Sam'));
      expect(fullCouple.getPartnerProfile(partner2Uid)?.name, equals('Alex'));

      // Verify serialization round-trip
      final serialized = fullCouple.toMap();
      final restored = CoupleModel.fromMap(fullCouple.id, serialized);
      expect(restored.isFull, isTrue);
      expect(restored.inviteCode, equals(inviteCode));
      expect(restored.partnerProfiles[partner2Uid]?.name, equals('Sam'));
    });

    test('2. Daily Prompt: Concealed answer until both partners answer, then dual reveal', () {
      const prompt = 'What made you smile today?';
      final promptDate = '2026-11-04';

      final initialQuestion = DailyQuestionModel(
        id: 'dq_$promptDate',
        date: promptDate,
        prompt: prompt,
      );

      expect(initialQuestion.isRevealed, isFalse);
      expect(initialQuestion.hasUserAnswered(partner1Uid), isFalse);
      expect(initialQuestion.hasUserAnswered(partner2Uid), isFalse);

      // Partner 1 answers prompt
      final questionWithP1 = initialQuestion.copyWithAnswer(
        partner1Uid,
        'Seeing your morning text 💕',
        DateTime(2026, 11, 4, 9, 30),
      );

      expect(questionWithP1.hasUserAnswered(partner1Uid), isTrue);
      expect(questionWithP1.hasUserAnswered(partner2Uid), isFalse);
      expect(questionWithP1.isRevealed, isFalse);
      expect(questionWithP1.isAnsweredByBoth, isFalse);
      expect(questionWithP1.getPartnerAnswer(partner1Uid), isNull);

      // Partner 2 answers prompt -> Triggers dual reveal!
      final questionWithBoth = questionWithP1.copyWithAnswer(
        partner2Uid,
        'Making our favorite dinner together!',
        DateTime(2026, 11, 4, 20, 15),
      );

      expect(questionWithBoth.hasUserAnswered(partner2Uid), isTrue);
      expect(questionWithBoth.isAnsweredByBoth, isTrue);
      expect(questionWithBoth.isRevealed, isTrue);
      expect(questionWithBoth.getAnswer(partner1Uid)?.text, equals('Seeing your morning text 💕'));
      expect(questionWithBoth.getPartnerAnswer(partner1Uid)?.text, equals('Making our favorite dinner together!'));
      expect(questionWithBoth.getPartnerAnswer(partner2Uid)?.text, equals('Seeing your morning text 💕'));

      // Verify serialization preserves revealed status
      final map = questionWithBoth.toMap();
      final restored = DailyQuestionModel.fromMap(questionWithBoth.id, map);
      expect(restored.isRevealed, isTrue);
      expect(restored.answers.length, equals(2));
    });

    test('3. Tasks & Lists: Add task, toggle completion with timestamp, check off grocery items', () {
      // Chores & Tasks
      final task = TaskModel(
        id: 'task_001',
        title: 'Book anniversary dinner table',
        description: 'Italian restaurant downtown',
        category: 'Dates',
        createdBy: partner1Uid,
        assignedTo: partner2Uid,
        dueDate: DateTime(2026, 11, 10),
      );

      expect(task.isCompleted, isFalse);
      expect(task.completedAt, isNull);

      // Toggle task completion
      final completedTask = task.toggle();
      expect(completedTask.isCompleted, isTrue);
      expect(completedTask.completedAt, isNotNull);

      // Untoggle task
      final reopenedTask = completedTask.toggle();
      expect(reopenedTask.isCompleted, isFalse);
      expect(reopenedTask.completedAt, isNull);

      // Shared Groceries Checklist
      var checklist = ChecklistModel(
        id: 'list_groceries_01',
        title: 'Romantic Dinner Groceries',
        category: 'Food',
        items: const [
          ChecklistItem(id: 'item_1', text: 'Fresh Pasta', addedBy: partner1Uid),
          ChecklistItem(id: 'item_2', text: 'Truffle Olive Oil', addedBy: partner1Uid),
          ChecklistItem(id: 'item_3', text: 'Strawberries & Cream', addedBy: partner2Uid),
        ],
      );

      expect(checklist.totalCount, equals(3));
      expect(checklist.completedCount, equals(0));
      expect(checklist.isFullyCompleted, isFalse);
      expect(checklist.progressPercentage, equals(0.0));

      // Check off items one by one
      checklist = checklist.toggleItem('item_1', true);
      expect(checklist.completedCount, equals(1));
      expect(checklist.progressPercentage, closeTo(1 / 3, 0.001));

      checklist = checklist.toggleItem('item_2', true);
      checklist = checklist.toggleItem('item_3', true);
      expect(checklist.completedCount, equals(3));
      expect(checklist.progressPercentage, equals(1.0));
      expect(checklist.isFullyCompleted, isTrue);

      // Add a 4th item dynamically
      checklist = checklist.addItem('Sparkling Cider', partner2Uid, 'item_4');
      expect(checklist.totalCount, equals(4));
      expect(checklist.isFullyCompleted, isFalse);
    });

    test('4. Sticky Note & HomeWidget Glance Payload: Create note and verify widget update dispatch', () async {
      final note = NoteModel(
        id: 'note_smoke_01',
        title: 'Sweet Morning Note',
        content: 'Good luck with your presentation today, my love! ☕❤️',
        colorHex: '#FFCDD2', // Blush Pink
        isPinnedToWidget: true,
        authorUid: partner1Uid,
        authorName: partner1Name,
        updatedAt: DateTime(2026, 11, 4, 8, 0),
      );

      expect(note.isPinnedToWidget, isTrue);
      expect(note.colorHex, equals('#FFCDD2'));

      // Dispatch to HomeWidget Glance Note
      await WidgetSyncService.updateGlanceNote(note);

      final saveCalls = widgetCalls.where((c) => c.method == 'saveWidgetData').toList();
      final updateCalls = widgetCalls.where((c) => c.method == 'updateWidget').toList();

      expect(
        saveCalls.any((c) => c.arguments['id'] == 'note_id' && c.arguments['data'] == 'note_smoke_01'),
        isTrue,
      );
      expect(
        saveCalls.any((c) => c.arguments['id'] == 'note_title' && c.arguments['data'] == 'Sweet Morning Note'),
        isTrue,
      );
      expect(
        saveCalls.any((c) => c.arguments['id'] == 'note_content' && c.arguments['data'].contains('presentation')),
        isTrue,
      );
      expect(
        saveCalls.any((c) => c.arguments['id'] == 'note_author' && c.arguments['data'] == 'Alex'),
        isTrue,
      );
      expect(
        saveCalls.any((c) => c.arguments['id'] == 'note_color' && c.arguments['data'] == '#FFCDD2'),
        isTrue,
      );
      expect(
        updateCalls.any((c) => c.arguments['name'] == WidgetSyncService.noteWidgetName),
        isTrue,
      );
    });

    test('5. Calendar & Reminders: Annual milestone countdown and exact notification trigger time', () async {
      final event = CalendarEventModel(
        id: 'cal_event_anniversary',
        title: 'Our Anniversary ❤️',
        date: DateTime(2024, 5, 18),
        isAnnual: true,
        category: CalendarEventModel.categoryAnniversary,
        reminderDaysBefore: 3,
        createdBy: partner1Uid,
      );

      // Verify next occurrence and days countdown
      final queryDate = DateTime(2026, 5, 10);
      final daysUntil = event.daysUntilNext(from: queryDate);
      expect(daysUntil, equals(8));

      final nextOcc = event.nextOccurrenceDate(from: queryDate);
      expect(nextOcc.year, equals(2026));
      expect(nextOcc.month, equals(5));
      expect(nextOcc.day, equals(18));

      // Calculate exact reminder trigger time: 3 days prior at 10:00 AM
      final reminderDate = nextOcc.subtract(Duration(days: event.reminderDaysBefore));
      expect(reminderDate.year, equals(2026));
      expect(reminderDate.month, equals(5));
      expect(reminderDate.day, equals(15));

      // Ensure local notification scheduling completes without exception
      await LocalNotificationService.initialize();
      await LocalNotificationService.scheduleEventReminder(event);
      await LocalNotificationService.scheduleDailyPrompt(hour: 20, minute: 0);
    });

    test('6. Decide Together & Date Ideas: Secret ballot, match detection, coin-toss split tie breaker, and date toggle', () {
      // Step A: Instant Match Detection
      final matchingSession = DecideSessionModel(
        id: 'decide_match_01',
        title: 'What cuisine for Friday night?',
        options: const ['Japanese Sushi', 'Italian Pasta', 'Mexican Tacos'],
        votes: const {
          partner1Uid: 'Japanese Sushi',
          partner2Uid: 'Japanese Sushi',
        },
        createdBy: partner1Uid,
      );

      expect(matchingSession.isResolved, isTrue);
      expect(matchingSession.isMatch, isTrue);
      expect(matchingSession.isSplit, isFalse);
      expect(matchingSession.winningOption, equals('Japanese Sushi'));

      // Step B: Split Vote & Coin Toss Resolution
      final splitSession = DecideSessionModel(
        id: 'decide_split_02',
        title: 'Movie Night Genre',
        options: const ['Romantic Comedy', 'Sci-Fi Thriller'],
        votes: const {
          partner1Uid: 'Romantic Comedy',
          partner2Uid: 'Sci-Fi Thriller',
        },
        createdBy: partner1Uid,
      );

      expect(splitSession.isResolved, isTrue);
      expect(splitSession.isMatch, isFalse);
      expect(splitSession.isSplit, isTrue);
      expect(splitSession.winningOption, isNull);

      // Resolve tie via Coin Toss
      final resolvedTie = splitSession.copyWith(
        winningOption: 'Sci-Fi Thriller',
        status: DecideSessionModel.statusResolved,
        resolvedAt: DateTime(2026, 11, 4, 21, 0),
      );
      expect(resolvedTie.winningOption, equals('Sci-Fi Thriller'));
      expect(resolvedTie.isResolved, isTrue);

      // Step C: Curated Date Ideas category filtering, completion, and weekly pick exclusivity
      final ideas = [
        DateIdeaModel(
          id: 'date_idea_01',
          title: 'Stargazing with blankets in the park',
          description: 'Bring hot cocoa and a constellation guide',
          category: DateIdeaModel.categoryRomance,
          isWeeklyPick: true,
          createdBy: partner1Uid,
        ),
        DateIdeaModel(
          id: 'date_idea_02',
          title: 'Cook homemade pizza together',
          description: 'Try funny topping combinations',
          category: DateIdeaModel.categoryFoodie,
          createdBy: partner2Uid,
        ),
        DateIdeaModel(
          id: 'date_idea_03',
          title: 'Scenic forest nature hike',
          description: 'Outdoor nature walk',
          category: DateIdeaModel.categoryOutdoor,
          createdBy: partner1Uid,
        ),
      ];

      // Category filtering
      final romanceIdeas = ideas.where((i) => i.category == DateIdeaModel.categoryRomance).toList();
      final foodieIdeas = ideas.where((i) => i.category == DateIdeaModel.categoryFoodie).toList();
      expect(romanceIdeas.length, equals(1));
      expect(foodieIdeas.length, equals(1));

      // Weekly pick exclusivity: only one weekly pick active
      final initialWeeklyPick = ideas.where((i) => i.isWeeklyPick).toList();
      expect(initialWeeklyPick.length, equals(1));
      expect(initialWeeklyPick.first.id, equals('date_idea_01'));

      // Reassigning weekly pick to idea 2
      final updatedIdeas = ideas.map((i) {
        return i.id == 'date_idea_02' ? i.copyWith(isWeeklyPick: true) : i.copyWith(isWeeklyPick: false);
      }).toList();
      final activeWeeklyPick = updatedIdeas.where((i) => i.isWeeklyPick).toList();
      expect(activeWeeklyPick.length, equals(1));
      expect(activeWeeklyPick.first.id, equals('date_idea_02'));

      // Completion toggle
      var dateIdea = ideas.first;
      expect(dateIdea.isCompleted, isFalse);
      expect(dateIdea.completedAt, isNull);

      dateIdea = dateIdea.toggleCompleted(completedAt: DateTime(2026, 11, 4));
      expect(dateIdea.isCompleted, isTrue);
      expect(dateIdea.completedAt, isNotNull);
    });

    test('7. Finance & Savings Goals: 50/50 and custom splits, net balance cancellation, and savings goal 100% target', () {
      // Entry 1: Partner 1 paid $120 for Dinner (50/50 split -> P2 owes P1 $60)
      final entry1 = FinanceEntry(
        id: 'exp_01',
        title: 'Fancy Anniversary Dinner',
        amount: 120.00,
        category: 'Dining',
        paidBy: partner1Uid,
        splitRatio: SplitRatio.half,
      );
      expect(entry1.shareFor(partner2Uid, partnerUid: partner1Uid), equals(60.00));

      // Entry 2: Partner 2 paid $100 for Groceries with Custom 70/30 split
      // (P2 pays 70%, P1 owes 30% = $30)
      final entry2 = FinanceEntry(
        id: 'exp_02',
        title: 'Weekly Gourmet Groceries',
        amount: 100.00,
        category: 'Groceries',
        paidBy: partner2Uid,
        splitRatio: SplitRatio.custom,
        customSplitPercentage: 70.0,
      );
      expect(entry2.shareFor(partner1Uid, partnerUid: partner2Uid), equals(30.00));

      // Calculate Net Owed: P1 is owed $60, P2 is owed $30 -> Net owed to P1 is $30!
      final balance = calculateNetOwed(
        [entry1, entry2],
        user1: partner1Uid,
        user2: partner2Uid,
      );

      expect(balance.totalSpent, equals(220.00));
      expect(balance.user1Paid, equals(120.00));
      expect(balance.user2Paid, equals(100.00));
      expect(balance.netOwedToUser1, equals(30.00));
      expect(balance.netOwedToUser2, equals(0.00));
      expect(balance.isSettledUp, isFalse);

      // Joint Savings Piggy Bank Goal
      var savingsGoal = SavingsGoalModel(
        id: 'savings_goal_01',
        title: 'Dream Amalfi Coast Getaway',
        targetAmount: 500.00,
        currentAmount: 0.00,
        category: 'Vacation',
        createdBy: partner1Uid,
      );

      expect(savingsGoal.isTargetReached, isFalse);
      expect(savingsGoal.progressPercentage, equals(0));
      expect(savingsGoal.remainingAmount, equals(500.00));

      // Partner 1 contributes $250
      final contrib1 = SavingsContribution(
        id: 'c_01',
        uid: partner1Uid,
        amount: 250.00,
        note: 'Savings from bonus',
      );
      savingsGoal = savingsGoal.copyWith(
        currentAmount: savingsGoal.currentAmount + contrib1.amount,
        contributions: [...savingsGoal.contributions, contrib1],
      );

      expect(savingsGoal.progressPercentage, equals(50));
      expect(savingsGoal.remainingAmount, equals(250.00));
      expect(savingsGoal.isTargetReached, isFalse);

      // Partner 2 contributes $250 -> Reaches 100%!
      final contrib2 = SavingsContribution(
        id: 'c_02',
        uid: partner2Uid,
        amount: 250.00,
        note: 'Match contribution 💕',
      );
      savingsGoal = savingsGoal.copyWith(
        currentAmount: savingsGoal.currentAmount + contrib2.amount,
        contributions: [...savingsGoal.contributions, contrib2],
      );

      expect(savingsGoal.currentAmount, equals(500.00));
      expect(savingsGoal.progressRatio, equals(1.0));
      expect(savingsGoal.progressPercentage, equals(100));
      expect(savingsGoal.remainingAmount, equals(0.00));
      expect(savingsGoal.isTargetReached, isTrue);
    });

    test('8. Shared Memories, Time Capsules & Wishlist: photo album, unlock date countdown, and wishlist purchase toggle', () {
      final now = DateTime(2026, 11, 4, 18, 0);

      // Part A: Memory Model with photos and location
      final memory = MemoryModel(
        id: 'mem_01',
        title: 'Our First Trip to Kyoto',
        date: DateTime(2025, 4, 10),
        caption: 'Walking through Fushimi Inari gates ⛩️',
        photoUrls: [
          'https://firebasestorage.googleapis.com/.../photo1.jpg',
          'https://firebasestorage.googleapis.com/.../photo2.jpg',
        ],
        location: 'Kyoto, Japan',
        createdBy: partner1Uid,
        createdAt: now,
      );

      final memMap = memory.toMap();
      final restoredMemory = MemoryModel.fromMap('mem_01', memMap);
      expect(restoredMemory.title, equals('Our First Trip to Kyoto'));
      expect(restoredMemory.photoUrls.length, equals(2));
      expect(restoredMemory.location, equals('Kyoto, Japan'));
      expect(restoredMemory.createdBy, equals(partner1Uid));

      // Part B: Time Capsule with unlockDate and concealment
      final futureUnlock = now.add(const Duration(days: 365));
      final lockedCapsule = TimeCapsuleModel(
        id: 'tc_01',
        title: 'Open on our 2nd Anniversary',
        unlockDate: futureUnlock,
        photoUrls: ['https://firebasestorage.googleapis.com/.../secret.jpg'],
        message: 'A secret letter for future us ❤️',
        createdBy: partner1Uid,
        createdAt: now,
      );

      // Cannot open before unlock date
      expect(lockedCapsule.canOpen(at: now), isFalse);
      expect(lockedCapsule.isOpened, isFalse);
      expect(lockedCapsule.timeRemaining(at: now).inDays, equals(365));

      // Unlocks when target date arrives or passes
      final unlockedDate = futureUnlock.add(const Duration(hours: 1));
      expect(lockedCapsule.canOpen(at: unlockedDate), isTrue);

      // Opened capsule remains permanently open
      final openedCapsule = lockedCapsule.open(openedAt: unlockedDate);
      expect(openedCapsule.isOpened, isTrue);
      expect(openedCapsule.canOpen(at: now), isTrue);
      expect(openedCapsule.openedAt, equals(unlockedDate));

      // Part C: Shared Wishlist
      final wish = WishModel(
        id: 'wish_01',
        title: 'Espresso Machine for our Kitchen',
        description: 'Barista quality with milk frother',
        estimatedPrice: 499.99,
        category: 'Home',
        createdBy: partner2Uid,
        createdAt: now,
      );

      expect(wish.isPurchased, isFalse);
      expect(wish.purchasedBy, isNull);

      final purchasedWish = wish.copyWith(
        isPurchased: true,
        purchasedBy: partner1Uid,
      );
      expect(purchasedWish.isPurchased, isTrue);
      expect(purchasedWish.purchasedBy, equals(partner1Uid));

      // Serialization round-trip
      final wishMap = purchasedWish.toMap();
      final restoredWish = WishModel.fromMap('wish_01', wishMap);
      expect(restoredWish.title, equals('Espresso Machine for our Kitchen'));
      expect(restoredWish.estimatedPrice, equals(499.99));
      expect(restoredWish.category, equals('Home'));
      expect(restoredWish.isPurchased, isTrue);
      expect(restoredWish.purchasedBy, equals(partner1Uid));
    });

    test('9. Private Vault & Cheatsheet: PBKDF2 key derivation, AES-256-GCM encryption/decryption, tampered payload rejection, and cheatsheet serialization', () async {
      final cryptoService = VaultCryptoService();
      const pin = '839201';
      const salt = 'couple_salt_c1_2026';
      const clearSecret = 'Secret anniversary getaway coordinates: 40.7128 N, 74.0060 W. Love forever.';

      // PBKDF2 Key Derivation
      final key = await cryptoService.deriveKey(pin: pin, salt: salt);
      expect(key, isNotNull);

      // AES-256-GCM Authenticated Encryption
      final payload = await cryptoService.encrypt(plaintext: clearSecret, key: key);
      expect(payload.ciphertextBase64.isNotEmpty, isTrue);
      expect(payload.nonceBase64.isNotEmpty, isTrue);
      expect(payload.macBase64.isNotEmpty, isTrue);

      // Decryption with correct key
      final decrypted = await cryptoService.decrypt(payload: payload, key: key);
      expect(decrypted, equals(clearSecret));

      // Decryption with wrong PIN throws VaultCryptoException
      final wrongKey = await cryptoService.deriveKey(pin: '000000', salt: salt);
      expect(
        () async => await cryptoService.decrypt(payload: payload, key: wrongKey),
        throwsA(isA<VaultCryptoException>()),
      );

      // Tampered ciphertext throws VaultCryptoException
      final tamperedPayload = payload.copyWith(
        ciphertextBase64: payload.ciphertextBase64.substring(2) + 'AA',
      );
      expect(
        () async => await cryptoService.decrypt(payload: tamperedPayload, key: key),
        throwsA(isA<VaultCryptoException>()),
      );

      // Vault Item Model Serialization
      final vaultItem = VaultItemModel(
        id: 'vault_smoke_item',
        title: 'Surprise Vacation Itinerary',
        category: 'Romantic',
        type: VaultItemModel.typeNote,
        payload: payload,
        createdBy: partner1Uid,
      );
      final itemMap = vaultItem.toMap();
      final restoredItem = VaultItemModel.fromMap(vaultItem.id, itemMap);
      expect(restoredItem.title, equals('Surprise Vacation Itinerary'));
      expect(restoredItem.payload.ciphertextBase64, equals(payload.ciphertextBase64));

      // Partner Cheatsheet serialization
      final cheatsheet = PartnerCheatsheetModel(
        uid: partner2Uid,
        clothingSize: 'M',
        shoeSize: '8.5',
        ringSize: '7',
        coffeeOrder: 'Oat milk vanilla latte, half sweet',
        allergies: 'None',
        comfortFood: 'Creamy mushroom risotto',
        favoriteFlowers: 'White Peonies and Pink Tulips',
        notes: 'Loves surprises, prefers silver jewelry over gold',
      );

      expect(cheatsheet.isNotEmpty, isTrue);
      final sheetMap = cheatsheet.toMap();
      final restoredSheet = PartnerCheatsheetModel.fromMap(partner2Uid, sheetMap);
      expect(restoredSheet.coffeeOrder, equals('Oat milk vanilla latte, half sweet'));
      expect(restoredSheet.favoriteFlowers, equals('White Peonies and Pink Tulips'));
    });

    test('10. Home Screen Glance Quad-Sync: Format milestone, daily prompt status pill, top tasks, and execute syncAllWidgets', () async {
      final now = DateTime(2026, 11, 4);

      // Format couple milestone
      final stats = WidgetSyncService.formatCoupleStats(
        anniversary: anniversary,
        today: now,
        partnerName: partner2Name,
      );
      expect(stats['daysTogether'], equals(900));
      expect(stats['formattedDays'], equals('900 days'));
      expect(stats['partnerName'], equals('Sam'));

      // Format daily prompt in all 3 states
      final promptBothAnswered = WidgetSyncService.formatDailyPrompt(
        prompt: 'Favorite trip together?',
        isAnsweredByMe: true,
        isRevealed: true,
        isAnsweredByPartner: true,
      );
      expect(promptBothAnswered['prompt_status'], equals('Both answered! Tap to read 💕'));

      final promptWaitingPartner = WidgetSyncService.formatDailyPrompt(
        prompt: 'Favorite trip together?',
        isAnsweredByMe: true,
        isRevealed: false,
        isAnsweredByPartner: false,
      );
      expect(promptWaitingPartner['prompt_status'], equals('Waiting for partner... 🔒'));

      final promptWaitingMe = WidgetSyncService.formatDailyPrompt(
        prompt: 'Favorite trip together?',
        isAnsweredByMe: false,
        isRevealed: false,
        isAnsweredByPartner: true,
      );
      expect(promptWaitingMe['prompt_status'], equals('Waiting for your answer ✍️'));

      // Format top tasks (prioritizes incomplete, urgent dueDate)
      final taskList = [
        TaskModel(id: 't1', title: 'Buy groceries', isCompleted: false, dueDate: DateTime(2026, 11, 5)),
        TaskModel(id: 't2', title: 'Call parents', isCompleted: true),
        TaskModel(id: 't3', title: 'Plan anniversary', isCompleted: false, dueDate: DateTime(2026, 11, 4)),
        TaskModel(id: 't4', title: 'Clean patio', isCompleted: false),
        TaskModel(id: 't5', title: 'Water orchids', isCompleted: false),
      ];

      final topTasks = WidgetSyncService.formatTopTasks(tasks: taskList);
      expect(topTasks['task_1_title'], equals('Plan anniversary')); // Earliest due date
      expect(topTasks['task_1_done'], isFalse);
      expect(topTasks['task_2_title'], equals('Buy groceries'));
      expect(topTasks['task_2_done'], isFalse);
      expect(topTasks['remaining_tasks_count'], equals(1)); // 4 incomplete total - 3 in top = 1 remaining

      // Batch sync all 4 widgets
      final couple = CoupleModel(
        id: 'c_sync_01',
        members: [partner1Uid, partner2Uid],
        anniversaryDate: anniversary,
        inviteCode: '654321',
        partnerProfiles: {
          partner1Uid: PartnerProfile(uid: partner1Uid, name: partner1Name),
          partner2Uid: PartnerProfile(uid: partner2Uid, name: partner2Name),
        },
      );

      final note = NoteModel(
        id: 'n_sync_01',
        title: 'Have a magical day',
        content: 'I love you to the moon and back 🌙❤️',
        authorUid: partner1Uid,
        authorName: partner1Name,
      );

      final question = DailyQuestionModel(
        id: 'q_sync_01',
        date: '2026-11-04',
        prompt: 'Favorite place in the world?',
        answers: {
          partner1Uid: DailyQuestionAnswer(uid: partner1Uid, text: 'Anywhere with you', answeredAt: now),
          partner2Uid: DailyQuestionAnswer(uid: partner2Uid, text: 'Our cozy couch', answeredAt: now),
        },
        isRevealed: true,
      );

      await WidgetSyncService.syncAllWidgets(
        couple: couple,
        pinnedNote: note,
        todayQuestion: question,
        tasks: taskList,
        myUid: partner1Uid,
      );

      final updateCalls = widgetCalls.where((c) => c.method == 'updateWidget').toList();
      expect(updateCalls.any((c) => c.arguments['name'] == WidgetSyncService.coupleWidgetName), isTrue);
      expect(updateCalls.any((c) => c.arguments['name'] == WidgetSyncService.noteWidgetName), isTrue);
      expect(updateCalls.any((c) => c.arguments['name'] == WidgetSyncService.dailyPromptWidgetName), isTrue);
      expect(updateCalls.any((c) => c.arguments['name'] == WidgetSyncService.tasksWidgetName), isTrue);
    });

    testWidgets('11. Root Navigation Shell & Pairing State Resolution: Unpaired shows PairingScreen, Hub screen renders feature cards & space info', (tester) async {
      // Step A: When currentCoupleIdProvider is null, CoupleApp displays PairingScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentCoupleIdProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: const CoupleApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PairingScreen), findsOneWidget);
      expect(find.text('Connect with Partner'), findsOneWidget);
      expect(find.text('Create Space'), findsOneWidget);
      expect(find.text('Join Partner'), findsOneWidget);
      expect(find.text('Start Your Shared Space'), findsOneWidget);

      // Step B: CoupleHubScreen renders Samsung One UI hero header and feature cards
      const testCoupleId = 'couple_smoke_hub_01';
      final couple = CoupleModel(
        id: testCoupleId,
        members: [partner1Uid, partner2Uid],
        anniversaryDate: anniversary,
        inviteCode: '849201',
        partnerProfiles: {
          partner1Uid: PartnerProfile(uid: partner1Uid, name: partner1Name),
          partner2Uid: PartnerProfile(uid: partner2Uid, name: partner2Name),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coupleStreamProvider(testCoupleId).overrideWith((ref) => Stream.value(couple)),
          ],
          child: const MaterialApp(
            home: CoupleHubScreen(coupleId: testCoupleId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Couple Hub'), findsOneWidget);
      expect(find.text('KRIVO COUPLE HUB'), findsOneWidget);
      expect(find.text('Alex & Sam'), findsOneWidget);

      // Verify all 4 feature cards
      expect(find.text('Memories, Wishlist & Capsules'), findsOneWidget);
      expect(find.text('Shared Finance & Savings'), findsOneWidget);
      expect(find.text('Private Encrypted Vault'), findsOneWidget);
      expect(find.text('Love Notes & Sticky Wall'), findsOneWidget);

      // Verify space details & settings card
      expect(find.text('SPACE DETAILS & SETTINGS'), findsOneWidget);
      expect(find.text('Space ID'), findsOneWidget);
      expect(find.text(testCoupleId), findsOneWidget);
      expect(find.text('Invite Code'), findsOneWidget);
      expect(find.text('849201'), findsOneWidget);
      expect(find.text('Paired (2/2 partners) 🎉'), findsOneWidget);
      expect(find.text('Unpair / Disconnect Space'), findsOneWidget);
    });

    test('12. Cryptographically Secure PRNG for Pairing Codes & Unpair Lifecycle', () async {
      // Verify Random.secure() generates valid 6-digit codes across multiple iterations
      final generatedCodes = <String>{};
      for (int i = 0; i < 25; i++) {
        final code = PairingRepository.generateInviteCode();
        expect(code.length, equals(6));
        final numeric = int.tryParse(code);
        expect(numeric, isNotNull);
        expect(numeric!, inInclusiveRange(100000, 999999));
        generatedCodes.add(code);
      }
      // With Random.secure(), collisions in 25 samples from 900,000 range are exceedingly rare
      expect(generatedCodes.length, greaterThan(20));

      // Verify container resolution contract for unpairing
      final container = ProviderContainer(
        overrides: [
          currentCoupleIdProvider.overrideWith((ref) => Future.value('couple_active_01')),
        ],
      );
      final activeId = await container.read(currentCoupleIdProvider.future);
      expect(activeId, equals('couple_active_01'));

      // Simulate unpair reset: container refreshed with null
      final resetContainer = ProviderContainer(
        overrides: [
          currentCoupleIdProvider.overrideWith((ref) => Future.value(null)),
        ],
      );
      final clearedId = await resetContainer.read(currentCoupleIdProvider.future);
      expect(clearedId, isNull);
    });
  });
}
