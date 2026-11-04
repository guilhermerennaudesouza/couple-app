import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/tasks/domain/task_model.dart';
import 'package:couple_app/features/tasks/domain/checklist_model.dart';
import 'package:couple_app/features/tasks/data/task_repository.dart';

void main() {
  group('TaskModel tests', () {
    test('TaskModel correctly toggles completion and records timestamp', () {
      final task = TaskModel(id: 't1', title: 'Buy groceries', isCompleted: false);
      final completed = task.toggle();
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      final reopened = completed.toggle();
      expect(reopened.isCompleted, isFalse);
      expect(reopened.completedAt, isNull);
    });

    test('TaskModel serialization round-trip maintains all fields and resilient date parsing', () {
      final dueDate = DateTime(2026, 11, 10, 18, 30);
      final completedAt = DateTime(2026, 11, 4, 15, 0);
      final task = TaskModel(
        id: 't2',
        title: 'Plan anniversary dinner',
        description: 'Book table at Italian bistro',
        assignedTo: 'partner_uid_1',
        dueDate: dueDate,
        isCompleted: true,
        completedAt: completedAt,
        createdBy: 'partner_uid_2',
        category: 'Romance',
      );

      final map = task.toMap();
      final restored = TaskModel.fromMap('t2', map);

      expect(restored.id, equals('t2'));
      expect(restored.title, equals('Plan anniversary dinner'));
      expect(restored.description, equals('Book table at Italian bistro'));
      expect(restored.assignedTo, equals('partner_uid_1'));
      expect(restored.dueDate?.isAtSameMomentAs(dueDate), isTrue);
      expect(restored.isCompleted, isTrue);
      expect(restored.completedAt?.isAtSameMomentAs(completedAt), isTrue);
      expect(restored.createdBy, equals('partner_uid_2'));
      expect(restored.category, equals('Romance'));
    });

    test('TaskModel copyWith and value equality', () {
      final task1 = TaskModel(
        id: 't1',
        title: 'Clean kitchen',
        category: 'Home',
        isCompleted: false,
      );
      final task2 = TaskModel(
        id: 't1',
        title: 'Clean kitchen',
        category: 'Home',
        isCompleted: false,
      );

      expect(task1, equals(task2));
      expect(task1.hashCode, equals(task2.hashCode));

      final updated = task1.copyWith(isCompleted: true);
      expect(updated.isCompleted, isTrue);
      expect(updated.id, equals('t1'));
      expect(updated.title, equals('Clean kitchen'));
    });

    test('TaskModel resilient date parsing handles epoch int and toDate objects', () {
      final fakeTimestamp = _FakeTimestamp(DateTime(2026, 11, 4, 14, 0));
      final map = {
        'title': 'Test Task',
        'dueDate': 1730728800000,
        'completedAt': fakeTimestamp,
        'isCompleted': true,
      };

      final task = TaskModel.fromMap('t3', map);
      expect(task.dueDate, isNotNull);
      expect(task.dueDate!.millisecondsSinceEpoch, equals(1730728800000));
      expect(task.completedAt, isNotNull);
      expect(task.completedAt!.year, equals(2026));
      expect(task.completedAt!.month, equals(11));
    });
  });

  group('ChecklistModel and ChecklistItem tests', () {
    test('ChecklistModel correctly toggles individual item status', () {
      final list = ChecklistModel(
        id: 'l1',
        title: 'Groceries',
        category: 'Shopping',
        items: [
          ChecklistItem(id: 'i1', text: 'Almond milk', isDone: false, addedBy: 'uid_1'),
          ChecklistItem(id: 'i2', text: 'Strawberries', isDone: false, addedBy: 'uid_2'),
        ],
        updatedAt: DateTime.now(),
      );
      expect(list.completedCount, equals(0));
      expect(list.totalCount, equals(2));
      expect(list.progressPercentage, equals(0.0));

      final updated = list.toggleItem('i1', true);
      expect(updated.completedCount, equals(1));
      expect(updated.progressPercentage, equals(0.5));
      expect(updated.items.firstWhere((i) => i.id == 'i1').isDone, isTrue);
      expect(updated.items.firstWhere((i) => i.id == 'i2').isDone, isFalse);

      final allDone = updated.toggleItem('i2', true);
      expect(allDone.completedCount, equals(2));
      expect(allDone.progressPercentage, equals(1.0));
      expect(allDone.isFullyCompleted, isTrue);
    });

    test('ChecklistModel addItem and removeItem', () {
      final list = ChecklistModel(
        id: 'l2',
        title: 'Packing',
        category: 'Travel',
        items: [
          ChecklistItem(id: 'i1', text: 'Passport', isDone: true, addedBy: 'uid_1'),
        ],
        updatedAt: DateTime.now(),
      );

      expect(list.totalCount, equals(1));

      final withNewItem = list.addItem('Sunglasses', 'uid_2');
      expect(withNewItem.totalCount, equals(2));
      expect(withNewItem.items.last.text, equals('Sunglasses'));
      expect(withNewItem.items.last.addedBy, equals('uid_2'));
      expect(withNewItem.items.last.isDone, isFalse);

      final removed = withNewItem.removeItem('i1');
      expect(removed.totalCount, equals(1));
      expect(removed.items.any((i) => i.id == 'i1'), isFalse);
      expect(removed.items.first.text, equals('Sunglasses'));
    });

    test('ChecklistModel serialization round-trip', () {
      final now = DateTime(2026, 11, 4, 12, 0);
      final list = ChecklistModel(
        id: 'l3',
        title: 'Date Night Prep',
        category: 'Romance',
        items: [
          ChecklistItem(id: 'i1', text: 'Book table', isDone: true, addedBy: 'uid_1'),
          ChecklistItem(id: 'i2', text: 'Pick playlist', isDone: false, addedBy: 'uid_2'),
        ],
        updatedAt: now,
      );

      final map = list.toMap();
      final restored = ChecklistModel.fromMap('l3', map);

      expect(restored.id, equals('l3'));
      expect(restored.title, equals('Date Night Prep'));
      expect(restored.category, equals('Romance'));
      expect(restored.items.length, equals(2));
      expect(restored.items[0].text, equals('Book table'));
      expect(restored.items[0].isDone, isTrue);
      expect(restored.items[1].text, equals('Pick playlist'));
      expect(restored.items[1].isDone, isFalse);
      expect(restored.updatedAt.isAtSameMomentAs(now), isTrue);
    });
  });

  group('TaskRepository defaults and templates tests', () {
    test('Default checklist templates are configured properly', () {
      final templates = TaskRepository.defaultChecklistTemplates;
      expect(templates.length, greaterThanOrEqualTo(3));

      final titles = templates.map((t) => t.title).toList();
      expect(titles.contains('Weekly Groceries'), isTrue);
      expect(titles.contains('Weekend Getaway Packing'), isTrue);
      expect(titles.contains('Date Night Prep'), isTrue);

      for (final template in templates) {
        expect(template.items.isNotEmpty, isTrue);
        expect(template.category.isNotEmpty, isTrue);
        for (final item in template.items) {
          expect(item.text.isNotEmpty, isTrue);
          expect(item.isDone, isFalse);
        }
      }
    });

    test('Standard task categories list is populated', () {
      final categories = TaskRepository.standardCategories;
      expect(categories, contains('Home'));
      expect(categories, contains('Shopping'));
      expect(categories, contains('Errands'));
      expect(categories, contains('Romance'));
    });

    test('ChecklistItem copyWith and value equality', () {
      const item1 = ChecklistItem(id: 'i1', text: 'Apples', isDone: false, addedBy: 'u1');
      const item2 = ChecklistItem(id: 'i1', text: 'Apples', isDone: false, addedBy: 'u1');
      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));

      final toggled = item1.toggle();
      expect(toggled.isDone, isTrue);

      final forced = toggled.toggle(false);
      expect(forced.isDone, isFalse);
    });

    test('ChecklistModel empty list edge cases', () {
      final emptyList = ChecklistModel(id: 'empty', title: 'Empty List');
      expect(emptyList.totalCount, equals(0));
      expect(emptyList.completedCount, equals(0));
      expect(emptyList.progressPercentage, equals(0.0));
      expect(emptyList.isFullyCompleted, isFalse);
    });
  });
}

class _FakeTimestamp {
  final DateTime _dt;
  _FakeTimestamp(this._dt);
  DateTime toDate() => _dt;
}
