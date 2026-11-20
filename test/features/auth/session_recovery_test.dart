import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';
import 'package:couple_app/features/auth/domain/partner_profile.dart';
import 'package:couple_app/features/auth/presentation/session_recovery_screen.dart';

void main() {
  final sampleCouple = CoupleModel(
    id: 'couple_abc',
    members: const ['uid_a', 'uid_b'],
    anniversaryDate: DateTime(2024, 5, 18),
    inviteCode: '123456',
    partnerProfiles: {
      'uid_a': PartnerProfile(
        uid: 'uid_a',
        name: 'Gui',
        avatarUrl: 'data:image/png;base64,AAAA',
        fcmToken: 'token_a',
        joinedAt: DateTime(2024, 5, 18),
      ),
      'uid_b': PartnerProfile(
        uid: 'uid_b',
        name: 'Ana',
        joinedAt: DateTime(2024, 5, 19),
      ),
    },
    createdAt: DateTime(2024, 5, 18),
  );

  group('isSessionOutOfSyncWithCouple', () {
    test('returns true when couple is loaded and myUid is not in members', () {
      expect(
        isSessionOutOfSyncWithCouple(couple: sampleCouple, myUid: 'uid_new'),
        isTrue,
      );
    });

    test('returns false when myUid is a member', () {
      expect(
        isSessionOutOfSyncWithCouple(couple: sampleCouple, myUid: 'uid_a'),
        isFalse,
      );
      expect(
        isSessionOutOfSyncWithCouple(couple: sampleCouple, myUid: 'uid_b'),
        isFalse,
      );
    });

    test('returns false when couple is null or myUid is empty', () {
      expect(
        isSessionOutOfSyncWithCouple(couple: null, myUid: 'uid_new'),
        isFalse,
      );
      expect(
        isSessionOutOfSyncWithCouple(couple: sampleCouple, myUid: ''),
        isFalse,
      );
      expect(
        isSessionOutOfSyncWithCouple(couple: sampleCouple, myUid: '   '),
        isFalse,
      );
    });
  });

  group('buildReclaimedCouple', () {
    test('replaces selected old UID in full couple and preserves profile & alias', () {
      final result = buildReclaimedCouple(
        sampleCouple,
        newUid: 'uid_new',
        replacingOldUid: 'uid_a',
      );

      expect(result.members, equals(['uid_new', 'uid_b']));
      expect(result.members.length, equals(2));
      expect(result.partnerProfiles.containsKey('uid_a'), isFalse);
      expect(result.partnerProfiles['uid_new']?.uid, equals('uid_new'));
      expect(result.partnerProfiles['uid_new']?.name, equals('Gui'));
      expect(
        result.partnerProfiles['uid_new']?.avatarUrl,
        equals('data:image/png;base64,AAAA'),
      );
      expect(result.partnerProfiles['uid_new']?.fcmToken, equals('token_a'));
      expect(result.partnerProfiles['uid_b']?.name, equals('Ana'));
      expect(result.uidAliases['uid_a'], equals('uid_new'));
    });

    test('joins open slot when couple has fewer than 2 members', () {
      final halfCouple = CoupleModel(
        id: 'couple_half',
        members: const ['uid_a'],
        anniversaryDate: DateTime(2024, 5, 18),
        inviteCode: '123456',
        partnerProfiles: {
          'uid_a': PartnerProfile(
            uid: 'uid_a',
            name: 'Gui',
            joinedAt: DateTime(2024, 5, 18),
          ),
        },
        createdAt: DateTime(2024, 5, 18),
      );

      final result = buildReclaimedCouple(
        halfCouple,
        newUid: 'uid_new',
        fallbackName: 'Ana',
      );

      expect(result.members, equals(['uid_a', 'uid_new']));
      expect(result.partnerProfiles['uid_new']?.name, equals('Ana'));
      expect(result.partnerProfiles['uid_a']?.name, equals('Gui'));
    });

    test('throws PairingException when couple is full and replacingOldUid is invalid', () {
      expect(
        () => buildReclaimedCouple(
          sampleCouple,
          newUid: 'uid_new',
          replacingOldUid: 'uid_unknown',
        ),
        throwsA(isA<PairingException>()),
      );
    });
  });

  group('SessionRecoveryScreen', () {
    testWidgets('displays partner profiles and invokes reclaim callback on tap', (tester) async {
      String? selectedOldUid;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SessionRecoveryScreen(
              couple: sampleCouple,
              myUid: 'uid_new',
              onReclaimSlot: ({String? replacingOldUid, String? fallbackName}) async {
                selectedOldUid = replacingOldUid;
              },
              onUnpair: () async {},
            ),
          ),
        ),
      );

      expect(find.text('Gui'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);

      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();

      expect(selectedOldUid, equals('uid_b'));
    });
  });
}
