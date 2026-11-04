import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';
import 'package:couple_app/features/auth/domain/partner_profile.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';

void main() {
  group('CoupleModel & PartnerProfile Tests', () {
    test('CoupleModel serialization handles members and profiles', () {
      final couple = CoupleModel(
        id: 'couple_123',
        members: ['uid_1', 'uid_2'],
        anniversaryDate: DateTime(2024, 5, 18),
        inviteCode: '849201',
        partnerProfiles: {
          'uid_1': PartnerProfile(
            uid: 'uid_1',
            name: 'Partner A',
            avatarUrl: 'https://example.com/a.png',
            fcmToken: 'token_1',
            joinedAt: DateTime(2024, 5, 18),
          ),
          'uid_2': PartnerProfile(
            uid: 'uid_2',
            name: 'Partner B',
            avatarUrl: 'https://example.com/b.png',
            fcmToken: 'token_2',
            joinedAt: DateTime(2024, 5, 18),
          ),
        },
        createdAt: DateTime(2024, 5, 18),
      );
      final map = couple.toMap();
      expect(map['members'], containsAll(['uid_1', 'uid_2']));
      expect(map['inviteCode'], equals('849201'));

      final restored = CoupleModel.fromMap('couple_123', map);
      expect(restored.id, equals('couple_123'));
      expect(restored.members.length, equals(2));
      expect(restored.isFull, isTrue);
      expect(restored.partnerProfiles['uid_1']?.name, equals('Partner A'));
      expect(restored.partnerProfiles['uid_2']?.name, equals('Partner B'));
      expect(restored.partnerProfiles['uid_1']?.avatarUrl, equals('https://example.com/a.png'));
    });

    test('CoupleModel identifies incomplete pairing state', () {
      final couple = CoupleModel(
        id: 'couple_new',
        members: ['uid_1'],
        anniversaryDate: DateTime(2024, 5, 18),
        inviteCode: '123456',
        partnerProfiles: {
          'uid_1': PartnerProfile(
            uid: 'uid_1',
            name: 'Partner A',
            joinedAt: DateTime(2024, 5, 18),
          ),
        },
        createdAt: DateTime.now(),
      );
      expect(couple.isFull, isFalse);
      expect(couple.getPartnerProfile('uid_1'), isNull);
      expect(couple.getOtherUid('uid_1'), isNull);
    });

    test('CoupleModel getOtherUid returns null when !isFull or when queried with a non-member UID', () {
      final incompleteCouple = CoupleModel(
        id: 'couple_incomplete',
        members: ['uid_1'],
        anniversaryDate: DateTime(2024, 5, 18),
        inviteCode: '123456',
      );
      expect(incompleteCouple.isFull, isFalse);
      expect(incompleteCouple.getOtherUid('uid_1'), isNull);
      expect(incompleteCouple.getOtherUid('uid_unknown'), isNull);

      final fullCouple = CoupleModel(
        id: 'couple_full',
        members: ['uid_1', 'uid_2'],
        anniversaryDate: DateTime(2024, 5, 18),
        inviteCode: '654321',
      );
      expect(fullCouple.isFull, isTrue);
      // Valid members return the other partner's UID
      expect(fullCouple.getOtherUid('uid_1'), equals('uid_2'));
      expect(fullCouple.getOtherUid('uid_2'), equals('uid_1'));
      // Non-member UID returns null
      expect(fullCouple.getOtherUid('uid_non_member'), isNull);
      expect(fullCouple.getPartnerProfile('uid_non_member'), isNull);
    });

    test('CoupleModel getPartnerProfile returns the other partner profile', () {
      final partnerA = PartnerProfile(
        uid: 'uid_1',
        name: 'Partner A',
        joinedAt: DateTime(2024, 5, 18),
      );
      final partnerB = PartnerProfile(
        uid: 'uid_2',
        name: 'Partner B',
        joinedAt: DateTime(2024, 5, 19),
      );

      final couple = CoupleModel(
        id: 'couple_full',
        members: ['uid_1', 'uid_2'],
        anniversaryDate: DateTime(2024, 5, 18),
        inviteCode: '654321',
        partnerProfiles: {
          'uid_1': partnerA,
          'uid_2': partnerB,
        },
        createdAt: DateTime(2024, 5, 18),
      );

      expect(couple.isFull, isTrue);
      expect(couple.getPartnerProfile('uid_1')?.uid, equals('uid_2'));
      expect(couple.getPartnerProfile('uid_1')?.name, equals('Partner B'));
      expect(couple.getPartnerProfile('uid_2')?.uid, equals('uid_1'));
      expect(couple.getPartnerProfile('uid_2')?.name, equals('Partner A'));
      expect(couple.getOtherUid('uid_1'), equals('uid_2'));
      expect(couple.getOtherUid('uid_2'), equals('uid_1'));
    });

    test('PartnerProfile serialization and copyWith', () {
      final profile = PartnerProfile(
        uid: 'uid_test',
        name: 'Alex',
        avatarUrl: 'https://example.com/alex.jpg',
        fcmToken: 'fcm_123',
        joinedAt: DateTime(2024, 1, 1),
      );

      final map = profile.toMap();
      expect(map['uid'], equals('uid_test'));
      expect(map['name'], equals('Alex'));
      expect(map['avatarUrl'], equals('https://example.com/alex.jpg'));
      expect(map['fcmToken'], equals('fcm_123'));

      final fromMap = PartnerProfile.fromMap(map);
      expect(fromMap.uid, equals('uid_test'));
      expect(fromMap.name, equals('Alex'));

      final updated = fromMap.copyWith(name: 'Alexander', fcmToken: 'fcm_456');
      expect(updated.name, equals('Alexander'));
      expect(updated.fcmToken, equals('fcm_456'));
      expect(updated.uid, equals('uid_test'));
    });

    test('CoupleModel getMyProfile returns own profile', () {
      final partnerA = PartnerProfile(
        uid: 'uid_1',
        name: 'Partner A',
        joinedAt: DateTime(2024, 5, 18),
      );
      final couple = CoupleModel(
        id: 'couple_1',
        members: ['uid_1'],
        anniversaryDate: DateTime(2024, 5, 18),
        inviteCode: '112233',
        partnerProfiles: {'uid_1': partnerA},
      );
      expect(couple.getMyProfile('uid_1')?.name, equals('Partner A'));
      expect(couple.getMyProfile('uid_2'), isNull);
    });

    test('CoupleModel.fromMap handles missing or null optional fields safely', () {
      final couple = CoupleModel.fromMap('c_empty', {});
      expect(couple.id, equals('c_empty'));
      expect(couple.members, isEmpty);
      expect(couple.inviteCode, equals(''));
      expect(couple.partnerProfiles, isEmpty);
      expect(couple.isFull, isFalse);
    });
  });

  group('PairingRepository Unit Tests', () {
    test('generateInviteCode returns a 6-digit numeric string', () {
      final code = PairingRepository.generateInviteCode();
      expect(code.length, equals(6));
      expect(int.tryParse(code), isNotNull);
      expect(int.parse(code), inInclusiveRange(100000, 999999));
    });

    test('PairingException produces informative message', () {
      const ex = PairingException('Space is full');
      expect(ex.toString(), equals('Space is full'));
      expect(ex.message, equals('Space is full'));
    });
  });
}
