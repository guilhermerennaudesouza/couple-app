import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/notes/domain/note_model.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

void main() {
  group('NoteModel tests', () {
    test('NoteModel marks pinned state for widget display', () {
      final note = NoteModel(
        id: 'n1',
        title: 'Love Note',
        content: 'Have an amazing day my love!',
        colorHex: '#FFE082',
        isPinnedToWidget: true,
        authorUid: 'uid_1',
        authorName: 'Sweetheart',
        updatedAt: DateTime.now(),
      );
      expect(note.isPinnedToWidget, isTrue);
      final map = note.toMap();
      expect(map['isPinnedToWidget'], isTrue);

      final restored = NoteModel.fromMap('n1', map);
      expect(restored.title, equals('Love Note'));
      expect(restored.isPinnedToWidget, isTrue);
    });

    test('NoteModel serialization round-trip maintains all fields', () {
      final updatedAt = DateTime(2026, 11, 4, 16, 20);
      final note = NoteModel(
        id: 'n2',
        title: 'Morning Surprise',
        content: 'I made pancakes and left fresh orange juice in the fridge!',
        colorHex: '#FFCDD2',
        isPinnedToWidget: false,
        authorUid: 'uid_alex',
        authorName: 'Alex',
        updatedAt: updatedAt,
      );

      final map = note.toMap();
      final restored = NoteModel.fromMap('n2', map);

      expect(restored.id, equals('n2'));
      expect(restored.title, equals('Morning Surprise'));
      expect(restored.content, equals('I made pancakes and left fresh orange juice in the fridge!'));
      expect(restored.colorHex, equals('#FFCDD2'));
      expect(restored.isPinnedToWidget, isFalse);
      expect(restored.authorUid, equals('uid_alex'));
      expect(restored.authorName, equals('Alex'));
      expect(restored.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
    });

    test('NoteModel copyWith and value equality', () {
      final note1 = NoteModel(
        id: 'n3',
        title: 'Dinner Date',
        content: 'Table booked at 8 PM',
        colorHex: '#E1BEE7',
        isPinnedToWidget: false,
        authorUid: 'uid_1',
        authorName: 'Sweetheart',
      );
      final note2 = NoteModel(
        id: 'n3',
        title: 'Dinner Date',
        content: 'Table booked at 8 PM',
        colorHex: '#E1BEE7',
        isPinnedToWidget: false,
        authorUid: 'uid_1',
        authorName: 'Sweetheart',
        updatedAt: note1.updatedAt,
      );

      expect(note1, equals(note2));
      expect(note1.hashCode, equals(note2.hashCode));

      final pinned = note1.copyWith(isPinnedToWidget: true);
      expect(pinned.isPinnedToWidget, isTrue);
      expect(pinned.id, equals('n3'));
      expect(pinned.title, equals('Dinner Date'));
    });

    test('NoteModel resilient date parsing handles epoch int and toDate objects', () {
      final fakeTimestamp = _FakeTimestamp(DateTime(2026, 11, 4, 18, 0));
      final map = {
        'title': 'Test Timestamp Parsing',
        'content': 'Validating Firestore compatibility',
        'colorHex': '#C8E6C9',
        'isPinnedToWidget': true,
        'authorUid': 'uid_1',
        'authorName': 'Sweetheart',
        'updatedAt': fakeTimestamp,
      };

      final note = NoteModel.fromMap('n4', map);
      expect(note.updatedAt.year, equals(2026));
      expect(note.updatedAt.month, equals(11));
      expect(note.updatedAt.day, equals(4));

      final epochMap = {
        'title': 'Epoch Test',
        'content': 'Validating epoch int',
        'colorHex': '#FFE0B2',
        'authorUid': 'uid_1',
        'authorName': 'Sweetheart',
        'updatedAt': 1730728800000,
      };

      final epochNote = NoteModel.fromMap('n5', epochMap);
      expect(epochNote.updatedAt.millisecondsSinceEpoch, equals(1730728800000));
    });

    test('NoteModel preset palette includes standard pastel colors', () {
      expect(NoteModel.presetColors, contains('#FFE082')); // Warm Vanilla
      expect(NoteModel.presetColors, contains('#FFCDD2')); // Blush Pink
      expect(NoteModel.presetColors, contains('#C8E6C9')); // Mint Green
      expect(NoteModel.presetColors, contains('#E1BEE7')); // Lavender Mist
      expect(NoteModel.presetColors, contains('#BBDEFB')); // Sky Blue
      expect(NoteModel.presetColors, contains('#FFE0B2')); // Peach Glow
      expect(NoteModel.presetColors.length, equals(6));
    });
  });

  group('WidgetSyncService tests', () {
    test('WidgetSyncService formats couple stats correctly', () {
      final stats = WidgetSyncService.formatCoupleStats(
        anniversary: DateTime(2024, 5, 18),
        today: DateTime(2026, 11, 4),
        partnerName: 'Sweetheart',
      );
      expect(stats['daysTogether'], equals(900));
      expect(stats['partnerName'], equals('Sweetheart'));
      expect(stats['formattedDays'], contains('900'));
    });
  });
}

class _FakeTimestamp {
  final DateTime _dt;
  _FakeTimestamp(this._dt);
  DateTime toDate() => _dt;
}
