import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'couple_date_utils.dart';

/// Tracks the current local calendar date (`YYYY-MM-DD`) and automatically
/// refreshes across midnight and on app resume so date-keyed streams never
/// remain stuck on yesterday's date.
class CurrentDateKeyNotifier extends StateNotifier<String>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  CurrentDateKeyNotifier() : super(CoupleDateUtils.formatDateKey(DateTime.now())) {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
    _scheduleMidnightRollover();
  }

  void _refreshIfNeeded() {
    final latest = CoupleDateUtils.formatDateKey(DateTime.now());
    if (latest != state) {
      state = latest;
    }
    _scheduleMidnightRollover();
  }

  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 2);
    final delay = nextMidnight.difference(now);
    _midnightTimer = Timer(delay.isNegative ? const Duration(seconds: 5) : delay, () {
      if (mounted) {
        _refreshIfNeeded();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfNeeded();
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    super.dispose();
  }
}

final currentDateKeyProvider =
    StateNotifierProvider<CurrentDateKeyNotifier, String>((ref) {
  return CurrentDateKeyNotifier();
});
