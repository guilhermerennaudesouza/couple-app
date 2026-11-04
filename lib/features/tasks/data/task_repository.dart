import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/task_model.dart';
import '../domain/checklist_model.dart';

/// Repository managing shared tasks, chores, and interactive checklists.
///
/// Persisted under:
/// - `/couples/{coupleId}/tasks/{taskId}`
/// - `/couples/{coupleId}/lists/{listId}`
class TaskRepository {
  final FirebaseFirestore _firestore;

  TaskRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Standard predefined categories for tasks and lists.
  static const List<String> standardCategories = [
    'Home',
    'Shopping',
    'Errands',
    'Romance',
    'Travel',
    'Health',
    'Finance',
    'General',
  ];

  /// Default curated checklist templates for couples.
  static List<ChecklistModel> get defaultChecklistTemplates => [
        ChecklistModel(
          id: 'template_groceries',
          title: 'Weekly Groceries',
          category: 'Shopping',
          items: const [
            ChecklistItem(id: 'g1', text: 'Almond milk', isDone: false),
            ChecklistItem(id: 'g2', text: 'Fresh avocados', isDone: false),
            ChecklistItem(id: 'g3', text: 'Sourdough bread', isDone: false),
            ChecklistItem(id: 'g4', text: 'Organic eggs', isDone: false),
            ChecklistItem(id: 'g5', text: 'Greek yogurt', isDone: false),
            ChecklistItem(id: 'g6', text: 'Coffee beans', isDone: false),
            ChecklistItem(id: 'g7', text: 'Dark chocolate', isDone: false),
          ],
          updatedAt: DateTime.now(),
        ),
        ChecklistModel(
          id: 'template_packing',
          title: 'Weekend Getaway Packing',
          category: 'Travel',
          items: const [
            ChecklistItem(id: 'p1', text: 'Passports & IDs', isDone: false),
            ChecklistItem(id: 'p2', text: 'Phone chargers & power bank', isDone: false),
            ChecklistItem(id: 'p3', text: 'Comfortable walking shoes', isDone: false),
            ChecklistItem(id: 'p4', text: 'Toiletries & sunscreen', isDone: false),
            ChecklistItem(id: 'p5', text: 'Warm jackets & layers', isDone: false),
            ChecklistItem(id: 'p6', text: 'Camera / tripod', isDone: false),
          ],
          updatedAt: DateTime.now(),
        ),
        ChecklistModel(
          id: 'template_date_night',
          title: 'Date Night Prep',
          category: 'Romance',
          items: const [
            ChecklistItem(id: 'd1', text: 'Pick date outfits', isDone: false),
            ChecklistItem(id: 'd2', text: 'Make dinner reservation', isDone: false),
            ChecklistItem(id: 'd3', text: 'Curate cozy music playlist', isDone: false),
            ChecklistItem(id: 'd4', text: 'Buy flowers or favorite sweets', isDone: false),
          ],
          updatedAt: DateTime.now(),
        ),
      ];

  // ==========================================
  // Tasks & Chores Operations
  // ==========================================

  CollectionReference<Map<String, dynamic>> _tasksCollection(String coupleId) {
    return _firestore.collection('couples').doc(coupleId).collection('tasks');
  }

  /// Watches all shared tasks for a couple with real-time updates.
  /// Tasks are sorted with uncompleted items first, then by due date.
  Stream<List<TaskModel>> watchTasks(String coupleId) {
    return _tasksCollection(coupleId).snapshots().map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
          .toList();

      // Stable sorting: incomplete tasks first, then by due date, then title
      tasks.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (a.dueDate != null && b.dueDate != null) {
          final comp = a.dueDate!.compareTo(b.dueDate!);
          if (comp != 0) return comp;
        } else if (a.dueDate != null) {
          return -1;
        } else if (b.dueDate != null) {
          return 1;
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      return tasks;
    });
  }

  /// Adds a new task to the couple's task list.
  Future<void> addTask(String coupleId, TaskModel task) async {
    final col = _tasksCollection(coupleId);
    final docRef = task.id.isEmpty ? col.doc() : col.doc(task.id);
    final payload = task.id.isEmpty
        ? task.copyWith(id: docRef.id).toMap()
        : task.toMap();

    await docRef.set(payload, SetOptions(merge: true));
  }

  /// Updates an existing task.
  Future<void> updateTask(String coupleId, TaskModel task) async {
    final docRef = _tasksCollection(coupleId).doc(task.id);
    await docRef.set(task.toMap(), SetOptions(merge: true));
  }

  /// Toggles completion status of a task and records timestamp.
  Future<void> toggleTask(
    String coupleId,
    String taskId,
    bool isCompleted,
  ) async {
    final docRef = _tasksCollection(coupleId).doc(taskId);
    final now = DateTime.now();

    await docRef.set({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? now.toIso8601String() : null,
    }, SetOptions(merge: true));
  }

  /// Deletes a task from Firestore.
  Future<void> deleteTask(String coupleId, String taskId) async {
    final docRef = _tasksCollection(coupleId).doc(taskId);
    await docRef.delete();
  }

  // ==========================================
  // Checklists Operations
  // ==========================================

  CollectionReference<Map<String, dynamic>> _listsCollection(String coupleId) {
    return _firestore.collection('couples').doc(coupleId).collection('lists');
  }

  /// Watches all shared checklists in real time.
  Stream<List<ChecklistModel>> watchLists(String coupleId) {
    return _listsCollection(coupleId).snapshots().map((snapshot) {
      final lists = snapshot.docs
          .map((doc) => ChecklistModel.fromMap(doc.id, doc.data()))
          .toList();

      lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return lists;
    });
  }

  /// Adds a new checklist.
  Future<void> addList(String coupleId, ChecklistModel list) async {
    final col = _listsCollection(coupleId);
    final docRef = list.id.isEmpty ? col.doc() : col.doc(list.id);
    final payload = list.id.isEmpty
        ? list.copyWith(id: docRef.id).toMap()
        : list.toMap();

    await docRef.set(payload, SetOptions(merge: true));
  }

  /// Updates a checklist.
  Future<void> updateList(String coupleId, ChecklistModel list) async {
    final docRef = _listsCollection(coupleId).doc(list.id);
    await docRef.set(list.toMap(), SetOptions(merge: true));
  }

  /// Deletes a checklist.
  Future<void> deleteList(String coupleId, String listId) async {
    final docRef = _listsCollection(coupleId).doc(listId);
    await docRef.delete();
  }

  /// Toggles an item inside a checklist with offline-resilient handling.
  Future<void> toggleChecklistItem(
    String coupleId,
    String listId,
    String itemId,
    bool isDone,
  ) async {
    final docRef = _listsCollection(coupleId).doc(listId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) return;

        final currentList = ChecklistModel.fromMap(snapshot.id, snapshot.data()!);
        final updatedList = currentList.toggleItem(itemId, isDone);
        transaction.set(docRef, updatedList.toMap(), SetOptions(merge: true));
      });
    } catch (_) {
      // Offline fallback: load from local cache and persist directly
      try {
        final snapshot = await docRef.get(const GetOptions(source: Source.cache));
        if (snapshot.exists && snapshot.data() != null) {
          final currentList = ChecklistModel.fromMap(snapshot.id, snapshot.data()!);
          final updatedList = currentList.toggleItem(itemId, isDone);
          await docRef.set(updatedList.toMap(), SetOptions(merge: true));
          return;
        }
      } catch (_) {}

      // Fallback: fetch default or current
      final snapshot = await docRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        final currentList = ChecklistModel.fromMap(snapshot.id, snapshot.data()!);
        final updatedList = currentList.toggleItem(itemId, isDone);
        await docRef.set(updatedList.toMap(), SetOptions(merge: true));
      }
    }
  }

  /// Appends an item to an existing checklist with offline-resilient handling.
  Future<void> addChecklistItem(
    String coupleId,
    String listId,
    String text,
    String addedBy,
  ) async {
    final docRef = _listsCollection(coupleId).doc(listId);
    try {
      final snapshot = await docRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        final currentList = ChecklistModel.fromMap(snapshot.id, snapshot.data()!);
        final updatedList = currentList.addItem(text, addedBy);
        await docRef.set(updatedList.toMap(), SetOptions(merge: true));
      }
    } catch (_) {
      try {
        final snapshot = await docRef.get(const GetOptions(source: Source.cache));
        if (snapshot.exists && snapshot.data() != null) {
          final currentList = ChecklistModel.fromMap(snapshot.id, snapshot.data()!);
          final updatedList = currentList.addItem(text, addedBy);
          await docRef.set(updatedList.toMap(), SetOptions(merge: true));
        }
      } catch (_) {}
    }
  }

  /// Removes an item from an existing checklist with offline-resilient handling.
  Future<void> removeChecklistItem(
    String coupleId,
    String listId,
    String itemId,
  ) async {
    final docRef = _listsCollection(coupleId).doc(listId);
    try {
      final snapshot = await docRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        final currentList = ChecklistModel.fromMap(snapshot.id, snapshot.data()!);
        final updatedList = currentList.removeItem(itemId);
        await docRef.set(updatedList.toMap(), SetOptions(merge: true));
      }
    } catch (_) {
      try {
        final snapshot = await docRef.get(const GetOptions(source: Source.cache));
        if (snapshot.exists && snapshot.data() != null) {
          final currentList = ChecklistModel.fromMap(snapshot.id, snapshot.data()!);
          final updatedList = currentList.removeItem(itemId);
          await docRef.set(updatedList.toMap(), SetOptions(merge: true));
        }
      } catch (_) {}
    }
  }

  /// Seeds default checklist templates if none exist for this couple.
  Future<void> seedDefaultListsIfEmpty(String coupleId) async {
    try {
      final col = _listsCollection(coupleId);
      final snapshot = await col.limit(1).get();
      if (snapshot.docs.isNotEmpty) return;

      final batch = _firestore.batch();
      for (final template in defaultChecklistTemplates) {
        final docRef = col.doc(template.id);
        batch.set(docRef, template.toMap());
      }
      await batch.commit();
    } catch (_) {
      // Offline fallback or concurrency guard
    }
  }
}

/// Riverpod provider for [TaskRepository].
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

/// Stream provider for all shared tasks belonging to a couple.
final tasksStreamProvider =
    StreamProvider.family<List<TaskModel>, String>((ref, coupleId) {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.watchTasks(coupleId);
});

/// Stream provider for all shared checklists belonging to a couple.
final listsStreamProvider =
    StreamProvider.family<List<ChecklistModel>, String>((ref, coupleId) {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.watchLists(coupleId);
});
