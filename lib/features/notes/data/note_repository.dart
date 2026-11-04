import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/note_model.dart';
import '../../widgets/widget_sync_service.dart';

/// Repository managing shared sticky notes with real-time Firestore synchronization
/// and Android Glance widget pinning.
///
/// Persisted under:
/// `/couples/{coupleId}/notes/{noteId}`
class NoteRepository {
  final FirebaseFirestore _firestore;

  NoteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notesCollection(String coupleId) {
    return _firestore.collection('couples').doc(coupleId).collection('notes');
  }

  /// Watches all shared sticky notes in real time.
  ///
  /// Sorted by [isPinnedToWidget] descending (pinned note at the top)
  /// and [updatedAt] descending (newest edits first).
  Stream<List<NoteModel>> watchNotes(String coupleId) {
    return _notesCollection(coupleId).snapshots().map((snapshot) {
      final notes = snapshot.docs
          .map((doc) => NoteModel.fromMap(doc.id, doc.data()))
          .toList();

      notes.sort((a, b) {
        if (a.isPinnedToWidget != b.isPinnedToWidget) {
          return a.isPinnedToWidget ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

      return notes;
    });
  }

  /// Saves or updates a sticky note with offline persistence.
  ///
  /// If [note.isPinnedToWidget] is true, unpins other notes in the couple space
  /// and synchronizes the note to the Android Glance home widget.
  Future<void> saveNote(String coupleId, NoteModel note) async {
    final col = _notesCollection(coupleId);
    final docRef = note.id.isEmpty ? col.doc() : col.doc(note.id);
    final noteToSave = note.id.isEmpty ? note.copyWith(id: docRef.id) : note;

    if (noteToSave.isPinnedToWidget) {
      try {
        final pinnedSnap =
            await col.where('isPinnedToWidget', isEqualTo: true).get();
        final batch = _firestore.batch();
        for (final doc in pinnedSnap.docs) {
          if (doc.id != noteToSave.id) {
            batch.update(doc.reference, {'isPinnedToWidget': false});
          }
        }
        batch.set(docRef, noteToSave.toMap(), SetOptions(merge: true));
        await batch.commit();
      } catch (e) {
        // Offline fallback
        debugPrint('NoteRepository.saveNote offline fallback: $e');
        await docRef.set(noteToSave.toMap(), SetOptions(merge: true));
      }
      await WidgetSyncService.updateGlanceNote(noteToSave);
    } else {
      bool wasPinned = false;
      if (note.id.isNotEmpty) {
        try {
          final snap = await docRef.get();
          wasPinned = snap.data()?['isPinnedToWidget'] == true;
        } catch (_) {}
      }
      await docRef.set(noteToSave.toMap(), SetOptions(merge: true));
      if (wasPinned) {
        await WidgetSyncService.clearGlanceNote();
      }
    }
  }

  /// Pins a specific sticky note to the Android Glance home widget.
  ///
  /// Ensures mutual exclusivity by unpinning all other notes in the couple's collection,
  /// then updates the Glance home screen widget.
  Future<void> pinNoteToWidget(String coupleId, String noteId) async {
    final col = _notesCollection(coupleId);
    NoteModel? pinnedNote;

    try {
      final pinnedSnap =
          await col.where('isPinnedToWidget', isEqualTo: true).get();
      final batch = _firestore.batch();
      for (final doc in pinnedSnap.docs) {
        if (doc.id != noteId) {
          batch.update(doc.reference, {'isPinnedToWidget': false});
        }
      }
      final targetRef = col.doc(noteId);
      final now = DateTime.now();
      batch.update(targetRef, {
        'isPinnedToWidget': true,
        'updatedAt': now.toIso8601String(),
      });
      await batch.commit();
    } catch (e) {
      debugPrint('NoteRepository.pinNoteToWidget batch fallback: $e');
      final targetRef = col.doc(noteId);
      await targetRef.set({
        'isPinnedToWidget': true,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    }

    try {
      final snap = await col.doc(noteId).get();
      if (snap.exists && snap.data() != null) {
        pinnedNote = NoteModel.fromMap(snap.id, snap.data()!);
      }
    } catch (_) {
      try {
        final cacheSnap =
            await col.doc(noteId).get(const GetOptions(source: Source.cache));
        if (cacheSnap.exists && cacheSnap.data() != null) {
          pinnedNote = NoteModel.fromMap(cacheSnap.id, cacheSnap.data()!);
        }
      } catch (_) {}
    }

    if (pinnedNote != null) {
      await WidgetSyncService.updateGlanceNote(pinnedNote);
    }
  }

  /// Unpins a specific sticky note from the Android Glance home widget.
  Future<void> unpinNoteFromWidget(String coupleId, String noteId) async {
    final docRef = _notesCollection(coupleId).doc(noteId);
    await docRef.set({
      'isPinnedToWidget': false,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    await WidgetSyncService.clearGlanceNote();
  }

  /// Deletes a sticky note.
  ///
  /// If the deleted note was pinned to the home widget, clears the widget.
  Future<void> deleteNote(String coupleId, String noteId) async {
    final docRef = _notesCollection(coupleId).doc(noteId);
    try {
      final snap = await docRef.get();
      final wasPinned = snap.data()?['isPinnedToWidget'] == true;
      await docRef.delete();
      if (wasPinned) {
        await WidgetSyncService.clearGlanceNote();
      }
    } catch (_) {
      await docRef.delete();
    }
  }
}

/// Riverpod provider for [NoteRepository].
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository();
});

/// Stream provider for all shared sticky notes belonging to a couple.
final notesStreamProvider =
    StreamProvider.family<List<NoteModel>, String>((ref, coupleId) {
  final repository = ref.watch(noteRepositoryProvider);
  return repository.watchNotes(coupleId);
});
