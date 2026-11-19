/// Unified date utilities preventing timezone/DST ±1-day drift and
/// midnight-cutoff false-positives across screens, stats, and Glance widgets.
class CoupleDateUtils {
  /// Returns whole calendar days between [anniversary] and [now] (UTC-normalized
  /// on date-only components), clamped to >= 0 so future dates never show negative days.
  static int daysTogether(DateTime anniversary, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final d1 = DateTime.utc(anniversary.year, anniversary.month, anniversary.day);
    final d2 = DateTime.utc(current.year, current.month, current.day);
    final diff = d2.difference(d1).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// True only if [dueDate]'s calendar day is strictly before today's calendar day.
  /// Tasks due today (00:00:00 from showDatePicker) are NOT overdue.
  static bool isDateOverdue(DateTime dueDate, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayDay = DateTime(current.year, current.month, current.day);
    return dueDay.isBefore(todayDay);
  }

  /// True if [date] falls on the same calendar year/month/day as [now].
  static bool isDateToday(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return date.year == current.year &&
        date.month == current.month &&
        date.day == current.day;
  }

  /// Formats [date] as a zero-padded `YYYY-MM-DD` key.
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
