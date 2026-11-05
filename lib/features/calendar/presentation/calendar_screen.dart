import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_strings.dart';
import '../../auth/domain/couple_model.dart';
import '../../auth/data/pairing_repository.dart';
import '../domain/calendar_event_model.dart';
import '../data/calendar_repository.dart';
import '../../../core/notifications/local_notification_service.dart';

/// Display mode for the shared calendar screen.
enum CalendarViewMode { upcoming, month }

/// Screen displaying the couple's shared calendar, annual anniversary countdown,
/// and scheduled date night reminders.
class CalendarScreen extends ConsumerStatefulWidget {
  final CoupleModel? initialCouple;
  final String? coupleId;
  final String? currentUid;

  const CalendarScreen({
    super.key,
    this.initialCouple,
    this.coupleId,
    this.currentUid,
  });

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.upcoming;
  String _selectedCategoryFilter = 'All';
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _hasSeededAnniversary = false;

  String _getEffectiveUid() {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'guest_uid';
  }

  void _checkAndSeedAnniversary(String coupleId, CoupleModel? couple) {
    if (_hasSeededAnniversary || couple == null) return;
    _hasSeededAnniversary = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(calendarRepositoryProvider)
          .seedAnniversaryEventIfMissing(coupleId, couple);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final effectiveCoupleId = widget.coupleId ??
        widget.initialCouple?.id ??
        'default_couple_id';
    final activeCouple = widget.initialCouple ??
        ref.watch(coupleStreamProvider(effectiveCoupleId)).valueOrNull;

    _checkAndSeedAnniversary(effectiveCoupleId, activeCouple);

    final eventsAsync =
        ref.watch(calendarEventsStreamProvider(effectiveCoupleId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.calendarTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == CalendarViewMode.upcoming
                  ? Icons.calendar_month_rounded
                  : Icons.view_agenda_rounded,
              color: AppTheme.primaryRose,
            ),
            tooltip: _viewMode == CalendarViewMode.upcoming
                ? (strings.isPortuguese ? 'Alternar para grade mensal' : 'Switch to Month Grid')
                : (strings.isPortuguese ? 'Alternar para lista de próximos' : 'Switch to Upcoming List'),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == CalendarViewMode.upcoming
                    ? CalendarViewMode.month
                    : CalendarViewMode.upcoming;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: strings.isPortuguese ? 'Configurar lembrete da Pergunta do Dia' : 'Schedule Daily Question Reminder',
            onPressed: () => _promptDailyReminderConfig(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryRose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          strings.addMoment,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () => _showEventEditor(
          context: context,
          coupleId: effectiveCoupleId,
        ),
      ),
      body: eventsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRose),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppTheme.errorRed),
                const SizedBox(height: 12),
                Text(
                  strings.isPortuguese
                      ? 'Não foi possível carregar os eventos: $err'
                      : 'Could not load shared events: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.refresh(
                    calendarEventsStreamProvider(effectiveCoupleId),
                  ),
                  child: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
        data: (events) {
          final anniversaryEvent = _findAnniversaryEvent(events, activeCouple);

          return CustomScrollView(
            slivers: [
              // Top Prominent Anniversary Countdown Banner
              SliverToBoxAdapter(
                child: _buildAnniversaryBanner(
                  context,
                  anniversaryEvent: anniversaryEvent,
                  couple: activeCouple,
                  coupleId: effectiveCoupleId,
                ),
              ),

              // Category Pills & View Selector
              SliverToBoxAdapter(
                child: _buildCategoryPills(events),
              ),

              // Calendar Body: Upcoming List or Month Grid
              if (_viewMode == CalendarViewMode.upcoming)
                _buildUpcomingListSliver(
                  context,
                  events: events,
                  coupleId: effectiveCoupleId,
                )
              else
                _buildMonthGridSliver(
                  context,
                  events: events,
                  coupleId: effectiveCoupleId,
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 90),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Finds the primary anniversary event from the event list or creates a virtual one.
  CalendarEventModel? _findAnniversaryEvent(
    List<CalendarEventModel> events,
    CoupleModel? couple,
  ) {
    for (final event in events) {
      if (event.category == CalendarEventModel.categoryAnniversary) {
        return event;
      }
    }
    if (couple != null) {
      return CalendarEventModel(
        id: 'anniversary_virtual',
        title: 'Our Anniversary',
        date: couple.anniversaryDate,
        isAnnual: true,
        category: CalendarEventModel.categoryAnniversary,
        reminderDaysBefore: 7,
      );
    }
    return null;
  }

  String _categoryLabel(String cat, AppStrings strings) {
    if (!strings.isPortuguese) return cat;
    switch (cat) {
      case 'All':
        return 'Todas';
      case CalendarEventModel.categoryAnniversary:
        return 'Aniversários';
      case CalendarEventModel.categoryDateNight:
        return 'Encontros';
      case CalendarEventModel.categoryBirthday:
        return 'Aniversário';
      case CalendarEventModel.categoryTravel:
        return 'Viagens';
      default:
        return cat;
    }
  }

  /// Builds the prominent romantic anniversary countdown banner.
  Widget _buildAnniversaryBanner(
    BuildContext context, {
    required CalendarEventModel? anniversaryEvent,
    required CoupleModel? couple,
    required String coupleId,
  }) {
    final strings = AppStrings.of(context);
    final now = DateTime.now();
    final daysUntil = anniversaryEvent?.daysUntilNext(from: now) ?? 0;
    final annivDate = anniversaryEvent?.date ?? couple?.anniversaryDate;

    // Calculate milestone years
    int yearsTogether = 0;
    int daysTogether = 0;
    if (annivDate != null) {
      final start = DateTime(annivDate.year, annivDate.month, annivDate.day);
      final current = DateTime(now.year, now.month, now.day);
      daysTogether = current.difference(start).inDays;
      yearsTogether = now.year - annivDate.year;
      if (now.month < annivDate.month ||
          (now.month == annivDate.month && now.day < annivDate.day)) {
        yearsTogether--;
      }
      if (yearsTogether < 0) yearsTogether = 0;
    }

    final isToday = daysUntil == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        gradient: const LinearGradient(
          colors: [
            AppTheme.primaryRoseDark,
            AppTheme.primaryRose,
            AppTheme.secondaryBlush,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRose.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.favorite_rounded,
              size: 130,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.anniversaryCountdown,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (annivDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          DateFormat(strings.isPortuguese ? 'd \'de\' MMM' : 'MMM d', strings.isPortuguese ? 'pt_BR' : 'en_US').format(annivDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isToday) ...[
                  Row(
                    children: [
                      Text(
                        strings.happyAnniversaryToday,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.happyAnniversaryDesc,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$daysUntil',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        daysUntil == 1
                            ? (strings.isPortuguese ? 'dia para o' : 'day until')
                            : (strings.isPortuguese ? 'dias para o' : 'days until'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.isPortuguese ? 'nosso aniversário ✨' : 'our anniversary ✨',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (annivDate != null)
                    Text(
                      daysTogether > 0
                          ? strings.daysTogetherMilestone(daysTogether, yearsTogether + 1)
                          : (strings.isPortuguese ? 'Nossa história de amor continua sendo escrita 💕' : 'Our love story continues to unfold 💕'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds horizontally scrollable category filter pills.
  Widget _buildCategoryPills(List<CalendarEventModel> events) {
    final strings = AppStrings.of(context);
    final categories = ['All', ...CalendarEventModel.categories];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategoryFilter == cat;
            final count = cat == 'All'
                ? events.length
                : events.where((e) => e.category == cat).length;
            final label = _categoryLabel(cat, strings);

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  count > 0 ? '$label ($count)' : label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : context.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                selectedColor: AppTheme.primaryRose,
                backgroundColor: context.surfaceVariant,
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryRose : context.outlineColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedCategoryFilter = cat;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Builds the upcoming list view of events.
  Widget _buildUpcomingListSliver(
    BuildContext context, {
    required List<CalendarEventModel> events,
    required String coupleId,
  }) {
    final filtered = events.where((e) {
      if (_selectedCategoryFilter == 'All') return true;
      return e.category == _selectedCategoryFilter;
    }).toList();

    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(context, coupleId: coupleId),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final event = filtered[index];
          return _buildEventCard(context, event: event, coupleId: coupleId);
        },
        childCount: filtered.length,
      ),
    );
  }

  /// Builds the monthly calendar view sliver.
  Widget _buildMonthGridSliver(
    BuildContext context, {
    required List<CalendarEventModel> events,
    required String coupleId,
  }) {
    final strings = AppStrings.of(context);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // Sun=0

    // Filter events for the selected day in this month
    final eventsForSelectedDay = events.where((e) {
      final occ = e.nextOccurrenceDate(
        from: DateTime(_focusedMonth.year, _focusedMonth.month, 1),
      );
      return occ.year == _selectedDay.year &&
          occ.month == _selectedDay.month &&
          occ.day == _selectedDay.day;
    }).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Month navigation header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () {
                    setState(() {
                      final newMonth = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month - 1,
                        1,
                      );
                      _focusedMonth = newMonth;
                      _selectedDay = DateTime(newMonth.year, newMonth.month, 1);
                    });
                  },
                ),
                Text(
                  DateFormat(
                    strings.isPortuguese ? 'MMMM \'de\' yyyy' : 'MMMM yyyy',
                    strings.isPortuguese ? 'pt_BR' : 'en_US',
                  ).format(_focusedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () {
                    setState(() {
                      final newMonth = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month + 1,
                        1,
                      );
                      _focusedMonth = newMonth;
                      _selectedDay = DateTime(newMonth.year, newMonth.month, 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Weekday symbols
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: (strings.isPortuguese
                      ? const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                      : const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  .map((w) => _WeekdayLabel(w))
                  .toList(),
            ),
            const SizedBox(height: 8),

            // Days Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday) {
                  return const SizedBox.shrink();
                }

                final dayNum = index - firstWeekday + 1;
                final thisDate = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month,
                  dayNum,
                );
                final isToday = _isSameDay(thisDate, DateTime.now());
                final isSelected = _isSameDay(thisDate, _selectedDay);

                // Check if any events fall on this day
                final hasEvents = events.any((e) {
                  final occ = e.nextOccurrenceDate(
                    from: DateTime(_focusedMonth.year, _focusedMonth.month, 1),
                  );
                  return occ.year == thisDate.year &&
                      occ.month == thisDate.month &&
                      occ.day == thisDate.day;
                });

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDay = thisDate;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryRose
                          : isToday
                              ? AppTheme.pastelPeach
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(color: AppTheme.primaryRose, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppTheme.primaryRoseDark
                                    : context.textPrimary,
                            fontWeight: isSelected || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        if (hasEvents) ...[
                          const SizedBox(height: 2),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.primaryRose,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Events for the selected day
            Row(
              children: [
                const Icon(Icons.event_available_rounded,
                    size: 20, color: AppTheme.primaryRose),
                const SizedBox(width: 8),
                Text(
                  strings.isPortuguese
                      ? 'Eventos para ${DateFormat('EEE, d \'de\' MMM', 'pt_BR').format(_selectedDay)}'
                      : 'Events for ${DateFormat('EEE, MMM d').format(_selectedDay)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (eventsForSelectedDay.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  strings.isPortuguese
                      ? 'Nenhum evento agendado para este dia.'
                      : 'No events scheduled on this day.',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 14,
                  ),
                ),
              )
            else
              ...eventsForSelectedDay.map(
                (e) => _buildEventCard(context, event: e, coupleId: coupleId),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Builds a romantic event card.
  Widget _buildEventCard(
    BuildContext context, {
    required CalendarEventModel event,
    required String coupleId,
  }) {
    final strings = AppStrings.of(context);
    final daysUntil = event.daysUntilNext();
    final isPast = event.isPast();
    final isToday = daysUntil == 0;
    final catColor = _categoryColor(event.category);
    final catIcon = _categoryIcon(event.category);

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        side: BorderSide(color: context.outlineColor, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(catIcon, color: catColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isPast
                                ? context.textSecondary
                                : context.textPrimary,
                            decoration:
                                isPast ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      // Countdown Badge
                      _buildCountdownPill(daysUntil, isPast, isToday),
                    ],
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Event date and reminder metadata
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 14, color: context.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              strings.isPortuguese ? 'EEE, d \'de\' MMM, yyyy' : 'EEE, MMM d, yyyy',
                              strings.isPortuguese ? 'pt_BR' : 'en_US',
                            ).format(event.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (event.isAnnual)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelLavender,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.repeat_rounded,
                                  size: 12, color: AppTheme.tertiaryMauve),
                              const SizedBox(width: 3),
                              Text(
                                strings.annualEvent,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.tertiaryMauve,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (event.reminderDaysBefore > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_active_outlined,
                                size: 14, color: AppTheme.primaryRose),
                            const SizedBox(width: 4),
                            Text(
                              strings.notifyDaysBefore(event.reminderDaysBefore),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryRose,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Overflow Actions Menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: context.textSecondary, size: 20),
              onSelected: (val) {
                if (val == 'edit') {
                  _showEventEditor(
                    context: context,
                    coupleId: coupleId,
                    existingEvent: event,
                  );
                } else if (val == 'delete') {
                  _confirmDelete(context, coupleId: coupleId, event: event);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(strings.isPortuguese ? 'Editar Evento' : 'Edit Event'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppTheme.errorRed),
                      const SizedBox(width: 8),
                      Text(strings.delete, style: const TextStyle(color: AppTheme.errorRed)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a colored pill indicating the countdown status.
  Widget _buildCountdownPill(int daysUntil, bool isPast, bool isToday) {
    final strings = AppStrings.of(context);
    if (isToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primaryRose,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          strings.todayTag,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (isPast) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          strings.isPortuguese ? 'Passado' : 'Past',
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (daysUntil == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.goldAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          strings.isPortuguese ? 'Amanhã ⏳' : 'Tomorrow ⏳',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.pastelPeach,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        strings.inDays(daysUntil),
        style: const TextStyle(
          color: AppTheme.primaryRoseDark,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Builds an inviting empty state when no calendar events exist.
  Widget _buildEmptyState(BuildContext context, {required String coupleId}) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 54,
              color: AppTheme.primaryRose,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.isPortuguese ? 'Nenhum Momento Agendado' : 'No Upcoming Moments Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.isPortuguese
                ? 'Planejem seu próximo encontro romântico, acompanhem aniversários ou agendem uma viagem especial a dois.'
                : 'Plan your next romantic date night, track anniversaries, or schedule a weekend getaway together.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 48),
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(strings.isPortuguese ? 'Agendar Encontro' : 'Schedule Date Night'),
            onPressed: () => _showEventEditor(
              context: context,
              coupleId: coupleId,
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the Bottom Sheet editor for creating or editing calendar events.
  void _showEventEditor({
    required BuildContext context,
    required String coupleId,
    CalendarEventModel? existingEvent,
  }) {
    final titleController =
        TextEditingController(text: existingEvent?.title ?? '');
    final descController =
        TextEditingController(text: existingEvent?.description ?? '');
    DateTime selectedDate = existingEvent?.date ?? DateTime.now();
    bool isAnnual = existingEvent?.isAnnual ?? false;
    String selectedCategory =
        existingEvent?.category ?? CalendarEventModel.categoryDateNight;
    int reminderDays = existingEvent?.reminderDaysBefore ?? 1;

    final strings = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existingEvent == null
                              ? (strings.isPortuguese ? 'Agendar Momento a Dois' : 'Schedule a Couple Moment')
                              : (strings.isPortuguese ? 'Editar Momento' : 'Edit Moment'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: strings.isPortuguese ? 'Título do Evento' : 'Event Title',
                        hintText: strings.isPortuguese ? 'ex: Jantar à luz de velas, Viagem à praia' : 'e.g. Candlelight Dinner, Coast Trip',
                        prefixIcon: const Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: strings.isPortuguese ? 'Notas & Descrição (Opcional)' : 'Notes & Description (Optional)',
                        hintText: strings.isPortuguese ? 'Endereço do restaurante, detalhes da reserva...' : 'Restaurant address, reservation details...',
                        prefixIcon: const Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date Picker Tile
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: context.outlineColor),
                      ),
                      leading: const Icon(Icons.calendar_today_rounded,
                          color: AppTheme.primaryRose),
                      title: Text(strings.isPortuguese ? 'Data do Evento' : 'Event Date'),
                      subtitle: Text(
                        DateFormat(
                          strings.isPortuguese ? 'EEEE, d \'de\' MMMM \'de\' yyyy' : 'EEEE, MMMM d, yyyy',
                          strings.isPortuguese ? 'pt_BR' : 'en_US',
                        ).format(selectedDate),
                        style: const TextStyle(
                          color: AppTheme.primaryRose,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category Selector
                    Text(
                      strings.isPortuguese ? 'Categoria' : 'Category',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: CalendarEventModel.categories.map((cat) {
                        final isSelected = selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(_categoryLabel(cat, strings)),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryRose,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : context.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() {
                                selectedCategory = cat;
                                if (cat ==
                                    CalendarEventModel.categoryAnniversary) {
                                  isAnnual = true;
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Annual Recurrence Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.repeat_rounded,
                          color: AppTheme.tertiaryMauve),
                      title: Text(strings.isPortuguese ? 'Repete Anualmente' : 'Repeats Annually'),
                      subtitle: Text(
                        strings.isPortuguese
                            ? 'Faz contagem regressiva todo ano (Aniversário de Namoro, Aniversário)'
                            : 'Automatically counts down every year (Anniversary, Birthday)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: isAnnual,
                      activeColor: AppTheme.primaryRose,
                      onChanged: (val) {
                        setSheetState(() {
                          isAnnual = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Reminder Dropdown
                    DropdownButtonFormField<int>(
                      value: reminderDays,
                      decoration: InputDecoration(
                        labelText: strings.isPortuguese ? 'Lembrete de Notificação' : 'Notification Reminder',
                        prefixIcon: const Icon(Icons.alarm_rounded),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(strings.isPortuguese ? 'No dia do evento (10:00)' : 'On the day of the event (10:00 AM)'),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(strings.isPortuguese ? '1 dia antes (10:00)' : '1 day before (10:00 AM)'),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(strings.isPortuguese ? '3 dias antes (10:00)' : '3 days before (10:00 AM)'),
                        ),
                        DropdownMenuItem(
                          value: 7,
                          child: Text(strings.isPortuguese ? '1 semana antes (10:00)' : '1 week before (10:00 AM)'),
                        ),
                        DropdownMenuItem(
                          value: 14,
                          child: Text(strings.isPortuguese ? '2 semanas antes (10:00)' : '2 weeks before (10:00 AM)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            reminderDays = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Save / Submit Button
                    ElevatedButton(
                      child: Text(
                        existingEvent == null
                            ? (strings.isPortuguese ? 'Salvar Momento' : 'Save Moment')
                            : (strings.isPortuguese ? 'Atualizar Momento' : 'Update Moment'),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(strings.isPortuguese ? 'Por favor, insira o título do evento' : 'Please enter an event title'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                          return;
                        }

                        final event = CalendarEventModel(
                          id: existingEvent?.id ?? '',
                          title: title,
                          description: descController.text.trim(),
                          date: selectedDate,
                          isAnnual: isAnnual,
                          category: selectedCategory,
                          reminderDaysBefore: reminderDays,
                          createdBy: (existingEvent?.createdBy != null &&
                                  existingEvent!.createdBy.isNotEmpty)
                              ? existingEvent.createdBy
                              : _getEffectiveUid(),
                          createdAt: existingEvent?.createdAt,
                        );

                        await ref
                            .read(calendarRepositoryProvider)
                            .addEvent(coupleId, event);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(strings.isPortuguese ? '"${event.title}" salvo com sucesso!' : 'Saved "${event.title}"!'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Prompts dialog to test / configure 20:00 Daily Question recurring reminder.
  void _promptDailyReminderConfig(BuildContext context) {
    final strings = AppStrings.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: AppTheme.primaryRose),
            const SizedBox(width: 8),
            Text(strings.isPortuguese ? 'Lembrete da Pergunta do Dia' : 'Daily Question Alarm'),
          ],
        ),
        content: Text(
          strings.isPortuguese
              ? 'As notificações da Pergunta do Dia estão agendadas para as 20:00 todas as noites neste celular:\n\n"Hora da sua Pergunta do Dia! Respondam juntos hoje à noite ✨"\n\nDeseja reativar e testar esse lembrete agora?'
              : 'Daily Question notifications are scheduled for 20:00 (8:00 PM) every evening on this device:\n\n"Time for your Daily Question! Answer together tonight ✨"\n\nWould you like to re-schedule and verify this alarm now?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              await LocalNotificationService.scheduleDailyPrompt(
                hour: 20,
                minute: 0,
              );
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(strings.isPortuguese ? 'Lembrete das 20:00 ativado com sucesso! ✨' : 'Daily Question 20:00 alarm activated! ✨'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            child: Text(strings.isPortuguese ? 'Ativar Lembrete' : 'Activate Alarm'),
          ),
        ],
      ),
    );
  }

  /// Confirms deletion of a calendar event.
  void _confirmDelete(
    BuildContext context, {
    required String coupleId,
    required CalendarEventModel event,
  }) {
    final strings = AppStrings.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Excluir Evento?' : 'Delete Event?'),
        content: Text(strings.isPortuguese ? 'Tem certeza de que deseja remover "${event.title}"?' : 'Are you sure you want to remove "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              await ref
                  .read(calendarRepositoryProvider)
                  .deleteEvent(coupleId, event.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(strings.isPortuguese ? '"${event.title}" removido' : 'Removed "${event.title}"'),
                  ),
                );
              }
            },
            child: Text(strings.delete),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case CalendarEventModel.categoryAnniversary:
        return AppTheme.primaryRose;
      case CalendarEventModel.categoryBirthday:
        return AppTheme.goldAccent;
      case CalendarEventModel.categoryDateNight:
        return AppTheme.tertiaryMauve;
      case CalendarEventModel.categoryTravel:
        return const Color(0xFF1E88E5);
      default:
        return AppTheme.primaryRoseLight;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case CalendarEventModel.categoryAnniversary:
        return Icons.favorite_rounded;
      case CalendarEventModel.categoryBirthday:
        return Icons.cake_rounded;
      case CalendarEventModel.categoryDateNight:
        return Icons.wine_bar_rounded;
      case CalendarEventModel.categoryTravel:
        return Icons.flight_takeoff_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
