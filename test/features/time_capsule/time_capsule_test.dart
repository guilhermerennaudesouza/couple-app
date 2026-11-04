import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/time_capsule/domain/time_capsule_model.dart';
import 'package:couple_app/features/memories/domain/memory_model.dart';
import 'package:couple_app/features/wishlist/domain/wish_model.dart';

void main() {
  group('TimeCapsuleModel tests', () {
    final now = DateTime(2026, 11, 4, 12, 0, 0);
    final futureUnlock = DateTime(2026, 12, 25, 12, 0, 0);
    final pastUnlock = DateTime(2026, 10, 1, 12, 0, 0);

    test('canOpen prevents opening before unlock date when unopened', () {
      final capsule = TimeCapsuleModel(
        id: 'tc1',
        title: 'Christmas Surprise',
        unlockDate: futureUnlock,
        message: 'Open me on Christmas Day!',
        isOpened: false,
        createdBy: 'user_1',
      );

      // Current time is before unlock date
      expect(capsule.canOpen(at: now), isFalse);
    });

    test('canOpen allows opening on or after unlock date', () {
      final capsule = TimeCapsuleModel(
        id: 'tc2',
        title: 'Anniversary Note',
        unlockDate: futureUnlock,
        message: 'Happy Anniversary!',
        isOpened: false,
        createdBy: 'user_1',
      );

      // Exactly at unlock date
      expect(capsule.canOpen(at: futureUnlock), isTrue);

      // One second after unlock date
      final afterUnlock = futureUnlock.add(const Duration(seconds: 1));
      expect(capsule.canOpen(at: afterUnlock), isTrue);

      // Past unlock date
      final pastCapsule = TimeCapsuleModel(
        id: 'tc3',
        title: 'Autumn Milestones',
        unlockDate: pastUnlock,
        message: 'A blast from October!',
        isOpened: false,
        createdBy: 'user_1',
      );
      expect(pastCapsule.canOpen(at: now), isTrue);
    });

    test('canOpen allows opening when isOpened is true regardless of date', () {
      final openedCapsule = TimeCapsuleModel(
        id: 'tc4',
        title: 'Early Opened Letter',
        unlockDate: futureUnlock,
        message: 'Peekaboo!',
        isOpened: true,
        openedAt: now,
        createdBy: 'user_1',
      );

      // Even though now is before futureUnlock, it is already marked isOpened
      expect(openedCapsule.canOpen(at: now), isTrue);
    });

    test('timeRemaining calculates accurate countdown duration', () {
      final capsule = TimeCapsuleModel(
        id: 'tc5',
        title: 'New Year Toast',
        unlockDate: DateTime(2026, 11, 6, 14, 30, 0),
        message: 'Cheers!',
        createdBy: 'user_1',
      );

      final current = DateTime(2026, 11, 4, 12, 0, 0);
      final remaining = capsule.timeRemaining(at: current);

      // 2 days, 2 hours, 30 minutes = 50 hours and 30 minutes
      expect(remaining.inDays, equals(2));
      expect(remaining.inHours, equals(50));
      expect(remaining.inMinutes, equals(50 * 60 + 30));
    });

    test('timeRemaining returns Duration.zero when unlocked or past', () {
      final capsule = TimeCapsuleModel(
        id: 'tc6',
        title: 'Past Milestone',
        unlockDate: pastUnlock,
        message: 'Throwback!',
        createdBy: 'user_1',
      );

      expect(capsule.timeRemaining(at: now), equals(Duration.zero));
      expect(capsule.timeRemaining(at: pastUnlock), equals(Duration.zero));
    });

    test('open helper sets isOpened to true and stamps openedAt', () {
      final capsule = TimeCapsuleModel(
        id: 'tc7',
        title: 'Sealed Envelope',
        unlockDate: pastUnlock,
        message: 'Special memories from Paris',
        isOpened: false,
        createdBy: 'user_1',
      );

      final openedAt = DateTime(2026, 11, 4, 18, 0, 0);
      final opened = capsule.open(openedAt: openedAt);

      expect(opened.isOpened, isTrue);
      expect(opened.openedAt, equals(openedAt));
      expect(opened.id, equals('tc7'));
      expect(opened.message, equals('Special memories from Paris'));
    });

    test('TimeCapsuleModel full serialization round-trip maintains all fields', () {
      final unlock = DateTime(2027, 2, 14, 20, 0, 0);
      final created = DateTime(2026, 11, 4, 10, 0, 0);
      final openedAt = DateTime(2027, 2, 14, 20, 5, 0);

      final capsule = TimeCapsuleModel(
        id: 'capsule_val_1',
        title: 'Valentine 2027 Letter',
        unlockDate: unlock,
        photoUrls: const [
          'https://storage.googleapis.com/test/photo1.jpg',
          'https://storage.googleapis.com/test/photo2.jpg',
        ],
        message: 'A secret letter written today for next year!',
        isOpened: true,
        openedAt: openedAt,
        createdBy: 'uid_sweetheart',
        createdAt: created,
      );

      final map = capsule.toMap();
      final restored = TimeCapsuleModel.fromMap('capsule_val_1', map);

      expect(restored.id, equals('capsule_val_1'));
      expect(restored.title, equals('Valentine 2027 Letter'));
      expect(restored.unlockDate.isAtSameMomentAs(unlock), isTrue);
      expect(restored.photoUrls, equals(capsule.photoUrls));
      expect(restored.message, equals('A secret letter written today for next year!'));
      expect(restored.isOpened, isTrue);
      expect(restored.openedAt!.isAtSameMomentAs(openedAt), isTrue);
      expect(restored.createdBy, equals('uid_sweetheart'));
      expect(restored.createdAt.isAtSameMomentAs(created), isTrue);

      // Equality test
      expect(restored, equals(capsule));
    });

    test('TimeCapsuleModel copyWith and value equality', () {
      final base = TimeCapsuleModel(
        id: 'tc8',
        title: 'Original Title',
        unlockDate: futureUnlock,
        message: 'Original Message',
        createdBy: 'uid_1',
      );

      final identicalCopy = base.copyWith();
      expect(identicalCopy, equals(base));
      expect(identicalCopy.hashCode, equals(base.hashCode));

      final modified = base.copyWith(
        title: 'Updated Title',
        photoUrls: ['https://example.com/p1.jpg'],
        isOpened: true,
      );
      expect(modified.title, equals('Updated Title'));
      expect(modified.photoUrls.length, equals(1));
      expect(modified.isOpened, isTrue);
      expect(modified, isNot(equals(base)));
    });
  });

  group('MemoryModel tests', () {
    final memoryDate = DateTime(2026, 6, 15, 14, 30, 0);
    final createdAt = DateTime(2026, 11, 4, 9, 0, 0);

    test('MemoryModel full serialization round-trip maintains all fields', () {
      final memory = MemoryModel(
        id: 'mem_1',
        title: 'First Trip to Venice',
        date: memoryDate,
        caption: 'Gondola ride through the Grand Canal at sunset 🌅',
        photoUrls: const [
          'https://storage.googleapis.com/test/venice1.jpg',
          'https://storage.googleapis.com/test/venice2.jpg',
        ],
        location: 'Venice, Italy',
        createdBy: 'uid_alex',
        createdAt: createdAt,
      );

      final map = memory.toMap();
      final restored = MemoryModel.fromMap('mem_1', map);

      expect(restored.id, equals('mem_1'));
      expect(restored.title, equals('First Trip to Venice'));
      expect(restored.date.isAtSameMomentAs(memoryDate), isTrue);
      expect(restored.caption, equals('Gondola ride through the Grand Canal at sunset 🌅'));
      expect(restored.photoUrls, equals(memory.photoUrls));
      expect(restored.location, equals('Venice, Italy'));
      expect(restored.createdBy, equals('uid_alex'));
      expect(restored.createdAt.isAtSameMomentAs(createdAt), isTrue);

      // Direct map restoration without explicit id parameter
      final fromMapOnly = MemoryModel.fromMap(map);
      expect(fromMapOnly, equals(memory));
    });

    test('MemoryModel copyWith and value equality', () {
      final memory = MemoryModel(
        id: 'mem_2',
        title: 'Starry Beach Night',
        date: memoryDate,
        caption: 'Sitting by the campfire listening to waves',
        location: 'Malibu Beach',
        createdBy: 'uid_sam',
      );

      final cloned = memory.copyWith();
      expect(cloned, equals(memory));

      final edited = memory.copyWith(
        caption: 'Sitting by the campfire with s\'mores',
        location: 'Zuma Beach',
      );
      expect(edited.caption, equals('Sitting by the campfire with s\'mores'));
      expect(edited.location, equals('Zuma Beach'));
      expect(edited, isNot(equals(memory)));

      final clearedLocation = edited.copyWith(clearLocation: true);
      expect(clearedLocation.location, isNull);
    });
  });

  group('WishModel tests', () {
    final createdAt = DateTime(2026, 11, 4, 15, 0, 0);

    test('WishModel full serialization round-trip maintains all fields', () {
      final wish = WishModel(
        id: 'wish_1',
        title: 'Instant Camera for scrapbooking',
        description: 'Fujifilm Instax Mini 12 with pastel pink film pack',
        url: 'https://example.com/instax',
        estimatedPrice: 79.99,
        category: WishModel.categoryGifts,
        isPurchased: true,
        purchasedBy: 'uid_alex',
        createdBy: 'uid_sam',
        createdAt: createdAt,
      );

      final map = wish.toMap();
      final restored = WishModel.fromMap('wish_1', map);

      expect(restored.id, equals('wish_1'));
      expect(restored.title, equals('Instant Camera for scrapbooking'));
      expect(restored.description, equals('Fujifilm Instax Mini 12 with pastel pink film pack'));
      expect(restored.url, equals('https://example.com/instax'));
      expect(restored.estimatedPrice, equals(79.99));
      expect(restored.category, equals(WishModel.categoryGifts));
      expect(restored.isPurchased, isTrue);
      expect(restored.purchasedBy, equals('uid_alex'));
      expect(restored.createdBy, equals('uid_sam'));
      expect(restored.createdAt.isAtSameMomentAs(createdAt), isTrue);

      expect(restored, equals(wish));
    });

    test('WishModel handles resilient price parsing', () {
      // Int price in map
      final wish1 = WishModel.fromMap({'id': 'w1', 'title': 'T1', 'estimatedPrice': 50, 'createdBy': 'u1'});
      expect(wish1.estimatedPrice, equals(50.0));

      // Formatted String price with currency symbol in map
      final wish2 = WishModel.fromMap({'id': 'w2', 'title': 'T2', 'estimatedPrice': '\$129.50', 'createdBy': 'u1'});
      expect(wish2.estimatedPrice, equals(129.50));

      // Null price
      final wish3 = WishModel.fromMap({'id': 'w3', 'title': 'T3', 'estimatedPrice': null, 'createdBy': 'u1'});
      expect(wish3.estimatedPrice, isNull);
    });

    test('WishModel copyWith and value equality', () {
      final wish = WishModel(
        id: 'wish_2',
        title: 'Weekend Spa Retreat',
        category: WishModel.categoryTrips,
        estimatedPrice: 250.0,
        createdBy: 'uid_1',
      );

      final cloned = wish.copyWith();
      expect(cloned, equals(wish));

      final purchased = wish.copyWith(
        isPurchased: true,
        purchasedBy: 'uid_2',
      );
      expect(purchased.isPurchased, isTrue);
      expect(purchased.purchasedBy, equals('uid_2'));
      expect(purchased, isNot(equals(wish)));

      final clearedPurchased = purchased.copyWith(
        isPurchased: false,
        clearPurchasedBy: true,
      );
      expect(clearedPurchased.isPurchased, isFalse);
      expect(clearedPurchased.purchasedBy, isNull);
    });
  });
}
