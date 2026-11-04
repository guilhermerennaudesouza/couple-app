import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../notes/domain/note_model.dart';

/// Service orchestrating bidirectional synchronization between Krivo's
/// internal data models and Android Home Screen Widgets via Kotlin Jetpack Glance.
class WidgetSyncService {
  static const String androidWidgetName = 'NoteGlanceWidget';
  static const String appGroupId = 'group.com.personal.couple_app';

  /// Initializes widget configuration and app group settings if applicable.
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('WidgetSyncService: Error setting app group id: $e');
    }
  }

  /// Updates the home screen Glance sticky note widget with the latest pinned note.
  static Future<void> updateGlanceNote(NoteModel note) async {
    try {
      await HomeWidget.saveWidgetData<String>('note_id', note.id);
      await HomeWidget.saveWidgetData<String>('note_title', note.title);
      await HomeWidget.saveWidgetData<String>('note_content', note.content);
      await HomeWidget.saveWidgetData<String>('note_author', note.authorName);
      await HomeWidget.saveWidgetData<String>('note_color', note.colorHex);
      await HomeWidget.saveWidgetData<String>(
        'note_updated_at',
        note.updatedAt.toIso8601String(),
      );

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
    } catch (e) {
      // Gracefully log on unsupported platforms or unit test harnesses
      debugPrint('WidgetSyncService.updateGlanceNote error: $e');
    }
  }

  /// Clears active pinned sticky note data from home widget storage.
  static Future<void> clearGlanceNote() async {
    try {
      await HomeWidget.saveWidgetData<String>('note_id', '');
      await HomeWidget.saveWidgetData<String>('note_title', '');
      await HomeWidget.saveWidgetData<String>('note_content', '');
      await HomeWidget.saveWidgetData<String>('note_author', '');
      await HomeWidget.saveWidgetData<String>('note_color', '');

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetSyncService.clearGlanceNote error: $e');
    }
  }

  /// Formats couple milestone metrics into structured widget payload data.
  static Map<String, dynamic> formatCoupleStats({
    required DateTime anniversary,
    DateTime? today,
    required String partnerName,
  }) {
    final current = today ?? DateTime.now();
    // Normalize to date boundaries (midnight) to prevent timezone drift
    final d1 = DateTime(anniversary.year, anniversary.month, anniversary.day);
    final d2 = DateTime(current.year, current.month, current.day);
    final daysTogether = d2.difference(d1).inDays;

    return {
      'daysTogether': daysTogether,
      'partnerName': partnerName,
      'formattedDays': '$daysTogether days',
      'anniversary': anniversary.toIso8601String(),
    };
  }

  /// Pushes couple anniversary and milestone counter data to widget storage.
  static Future<void> syncCoupleStats({
    required DateTime anniversary,
    required String partnerName,
    DateTime? today,
  }) async {
    try {
      final stats = formatCoupleStats(
        anniversary: anniversary,
        today: today,
        partnerName: partnerName,
      );

      await HomeWidget.saveWidgetData<int>(
        'days_together',
        stats['daysTogether'] as int,
      );
      await HomeWidget.saveWidgetData<String>('partner_name', partnerName);

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetSyncService.syncCoupleStats error: $e');
    }
  }
}
