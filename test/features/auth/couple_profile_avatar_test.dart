import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/widgets/partner_avatar_widget.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';

void main() {
  // Valid 1x1 transparent PNG
  const validPngBase64 =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

  group('PairingRepository.isValidAvatarDataUri', () {
    test('accepts small valid image data URI', () {
      expect(PairingRepository.isValidAvatarDataUri(validPngBase64), isTrue);
    });

    test('rejects non-image strings and oversized payloads above 80 KB', () {
      expect(PairingRepository.isValidAvatarDataUri('not-a-data-uri'), isFalse);
      final huge = 'data:image/jpeg;base64,${'A' * (PairingRepository.maxAvatarDataUriBytes + 1024)}';
      expect(PairingRepository.isValidAvatarDataUri(huge), isFalse);
    });
  });

  group('PartnerAvatarWidget', () {
    testWidgets('renders stylized initials when avatarUrl is null or empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PartnerAvatarWidget(name: 'Ana Clara'),
          ),
        ),
      );
      expect(find.text('AC'), findsOneWidget);
    });

    testWidgets('renders MemoryImage avatar for valid Base64 Data URI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PartnerAvatarWidget(
              name: 'Gui',
              avatarUrl: validPngBase64,
            ),
          ),
        ),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<MemoryImage>());
    });

    testWidgets('falls back to initials cleanly for malformed Base64 data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PartnerAvatarWidget(
              name: 'Gui',
              avatarUrl: 'data:image/jpeg;base64,@@@invalid@@@',
            ),
          ),
        ),
      );

      expect(find.text('G'), findsOneWidget);
    });
  });
}
