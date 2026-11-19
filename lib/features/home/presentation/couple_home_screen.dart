import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/l10n/locale_provider.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/core/utils/couple_date_utils.dart';
import 'package:couple_app/core/widgets/partner_avatar_widget.dart';
import 'package:couple_app/features/adult_games/data/adult_games_repository.dart';
import 'package:couple_app/features/adult_games/presentation/adult_games_screen.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';
import 'package:couple_app/features/auth/presentation/edit_couple_profile_sheet.dart';
import 'package:couple_app/features/calendar/data/calendar_repository.dart';
import 'package:couple_app/features/calendar/domain/calendar_event_model.dart';
import 'package:couple_app/features/cycle/data/cycle_repository.dart';
import 'package:couple_app/features/daily_question/data/daily_question_repository.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';
import 'package:couple_app/features/daily_question/presentation/daily_question_screen.dart';
import 'package:couple_app/features/decide/data/decide_repository.dart';
import 'package:couple_app/features/decide/domain/decide_model.dart';
import 'package:couple_app/features/home/data/activity_state_repository.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';
import 'package:couple_app/features/loyalty/data/loyalty_repository.dart';
import 'package:couple_app/features/loyalty/domain/loyalty_coupon_model.dart';
import 'package:couple_app/features/loyalty/presentation/loyalty_screen.dart';
import 'package:couple_app/features/notes/data/note_repository.dart';
import 'package:couple_app/features/notes/domain/note_model.dart';
import 'package:couple_app/features/notes/presentation/notes_screen.dart';
import 'package:couple_app/features/tasks/data/task_repository.dart';
import 'package:couple_app/features/tasks/domain/task_model.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

/// Pure badge helper: counts incomplete tasks for the Tasks tab badge.
int countPendingTasks(List<TaskModel> tasks) {
  return tasks.where((t) => !t.isCompleted).length;
}

/// Pure badge helper: counts open Decide ballots awaiting [myUid]'s vote.
int countOpenBallotsNeedingVote(
  List<DecideSessionModel> sessions,
  String myUid,
) {
  if (myUid.isEmpty) return 0;
  return sessions.where((s) => !s.isResolved && !s.hasUserVoted(myUid)).length;
}

/// Pure live-banner guard: returns `true` ONLY for brand-new partner events
/// arriving after the initial stream snapshot has seeded [lastSeenEventId].
bool shouldShowLivePartnerBanner({
  required ActivityStateModel state,
  required String myUid,
  required bool hasSeeded,
  required String? lastSeenEventId,
}) {
  if (!hasSeeded) return false;
  if (state.lastEventId.isEmpty) return false;
  if (state.lastActorUid.isEmpty || state.lastActorUid == myUid) return false;
  if (state.lastEventId == lastSeenEventId) return false;
  return true;
}

/// Tab 0: Live "Nosso Dia" couple dashboard combining presence, daily streak,
/// active partner attention banners, moods, love pulses, daily question status,
/// and compact live cards for pinned notes, urgent tasks, and upcoming events.
class CoupleHomeScreen extends ConsumerStatefulWidget {
  final String coupleId;
  final ValueChanged<int> onSwitchTab;
  final String? currentUid;

  const CoupleHomeScreen({
    super.key,
    required this.coupleId,
    required this.onSwitchTab,
    this.currentUid,
  });

  @override
  ConsumerState<CoupleHomeScreen> createState() => _CoupleHomeScreenState();
}

class _CoupleHomeScreenState extends ConsumerState<CoupleHomeScreen> {
  bool _sendingPulse = false;
  int _pulseBurstCounter = 0;
  bool _showRecentPulses = false;

  String _effectiveUid() {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    return ref.watch(currentUserUidProvider).valueOrNull ??
        ref.read(pairingRepositoryProvider).currentUserUid ??
        '';
  }

  Future<void> _sendLovePulse(String myUid, String myName) async {
    if (_sendingPulse || myUid.isEmpty) return;
    final strings = AppStrings.of(context);
    setState(() {
      _sendingPulse = true;
      _pulseBurstCounter++;
    });
    HapticFeedback.mediumImpact();
    try {
      await ref.read(activityStateRepositoryProvider).sendThinkingOfYouPulse(
            widget.coupleId,
            senderUid: myUid,
            senderName: myName,
            message: strings.isPortuguese
                ? 'Tô pensando em você agora 💓'
                : 'Thinking of you right now 💓',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.lovePulseSentToast),
          backgroundColor: AppTheme.primaryRose,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingPulse = false);
      }
    }
  }

  Future<void> _selectMood(
    MoodPreset preset, {
    required String myUid,
    required String myName,
    String? existingNote,
  }) async {
    if (myUid.isEmpty) return;
    final strings = AppStrings.of(context);
    final label = preset.label(isPortuguese: strings.isPortuguese);
    final noteController = TextEditingController(text: existingNote ?? '');

    final submittedNote = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: noteController,
          maxLength: PartnerMood.maxNoteLength,
          autofocus: true,
          decoration: InputDecoration(
            labelText: strings.addMoodNoteTitle,
            hintText: strings.addMoodNoteHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
            onPressed: () =>
                Navigator.of(dialogCtx).pop(noteController.text.trim()),
            child: Text(strings.save),
          ),
        ],
      ),
    );
    noteController.dispose();

    if (submittedNote == null || !mounted) return;
    HapticFeedback.lightImpact();
    await ref.read(activityStateRepositoryProvider).setMood(
          widget.coupleId,
          uid: myUid,
          actorName: myName,
          emoji: preset.emoji,
          label: label,
          note: submittedNote,
        );
  }

  Future<void> _handleNudgePartner({
    required ActivityStateModel activityState,
    required String myUid,
    required String myName,
    required String partnerName,
  }) async {
    final strings = AppStrings.of(context);
    if (!activityState.canNudgePartner(myUid)) {
      final remainingMin =
          activityState.remainingNudgeCooldown(myUid).inMinutes.clamp(1, 60);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.nudgeCooldownMessage(remainingMin))),
      );
      return;
    }

    HapticFeedback.lightImpact();
    await ref.read(activityStateRepositoryProvider).sendDailyQuestionNudge(
          widget.coupleId,
          senderUid: myUid,
          senderName: myName,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.nudgeSentSuccess(partnerName)),
        backgroundColor: AppTheme.primaryRose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleId = widget.coupleId;
    final myUid = _effectiveUid();
    final strings = AppStrings.of(context);
    final locale = ref.watch(localeProvider);
    final isPt = locale.languageCode == 'pt';

    final couple = ref.watch(coupleStreamProvider(coupleId)).valueOrNull;
    final activityState =
        ref.watch(activityStateStreamProvider(coupleId)).valueOrNull ??
            const ActivityStateModel();
    final dailyStreak = ref.watch(dailyStreakProvider(coupleId));
    final todayQuestion =
        ref.watch(todayDailyQuestionProvider(coupleId)).valueOrNull;
    final cycleData = ref.watch(cycleDataStreamProvider(coupleId)).valueOrNull;
    final adultSession =
        ref.watch(adultGameSessionStreamProvider(coupleId)).valueOrNull;
    final decideSessions =
        ref.watch(decideSessionsStreamProvider(coupleId)).valueOrNull ??
            const [];
    final coupons =
        ref.watch(loyaltyCouponsStreamProvider(coupleId)).valueOrNull ??
            const [];
    final notes =
        ref.watch(notesStreamProvider(coupleId)).valueOrNull ?? const [];
    final tasks =
        ref.watch(tasksStreamProvider(coupleId)).valueOrNull ?? const [];
    final events =
        ref.watch(calendarEventsStreamProvider(coupleId)).valueOrNull ??
            const [];

    final myProfile = couple?.getMyProfile(myUid);
    final partnerProfile = couple?.getPartnerProfile(myUid);
    final myName = myProfile?.displayName.trim().isNotEmpty == true
        ? myProfile!.displayName.trim()
        : (isPt ? 'Você' : 'You');
    final partnerName = partnerProfile?.displayName.trim().isNotEmpty == true
        ? partnerProfile!.displayName.trim()
        : (isPt ? 'Seu Amor' : 'Partner');

    final daysTogether = couple != null
        ? CoupleDateUtils.daysTogether(couple.anniversaryDate)
        : 0;

    final openBallotsNeedingVote =
        countOpenBallotsNeedingVote(decideSessions, myUid);

    final recentPartnerCoupon = _findRecentPartnerCoupon(coupons, myUid);
    final pinnedNote = notes.where((n) => n.isPinnedToWidget).firstOrNull;
    final topTasks = _pickTopPendingTasks(tasks);
    final nextEvent = _pickNextUpcomingEvent(events);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
          children: [
            // 1. COUPLE HERO HEADER
            _buildCoupleHeader(
              context,
              couple: couple,
              myUid: myUid,
              myName: myName,
              myAvatarUrl: myProfile?.avatarUrl,
              partnerName: partnerName,
              partnerAvatarUrl: partnerProfile?.avatarUrl,
              daysTogether: daysTogether,
              dailyStreak: dailyStreak,
              strings: strings,
            ),
            const SizedBox(height: 16),

            // 2. CONDITIONAL ACTIVE ATTENTION BANNERS
            if (cycleData?.activeCareRequest != null &&
                cycleData!.activeCareRequest!.trim().isNotEmpty) ...[
              _buildSosBanner(
                context,
                requestText: cycleData.activeCareRequest!,
                senderName: cycleData.careRequestedByName ?? partnerName,
                strings: strings,
              ),
              const SizedBox(height: 12),
            ],
            if (adultSession != null &&
                adultSession.nudgeMessage != null &&
                adultSession.nudgeMessage!.trim().isNotEmpty &&
                adultSession.nudgeSenderUid != myUid) ...[
              _buildSpicyNudgeBanner(
                context,
                message: adultSession.nudgeMessage!,
                strings: strings,
              ),
              const SizedBox(height: 12),
            ],
            if (openBallotsNeedingVote > 0) ...[
              _buildDecideBanner(
                context,
                count: openBallotsNeedingVote,
                strings: strings,
              ),
              const SizedBox(height: 12),
            ],
            if (recentPartnerCoupon != null) ...[
              _buildCouponBanner(
                context,
                coupon: recentPartnerCoupon,
                partnerName: partnerName,
                strings: strings,
              ),
              const SizedBox(height: 12),
            ],

            // 3. "COMO ESTAMOS HOJE" PRESENCE & PULSE CARD
            _buildPresenceCard(
              context,
              activityState: activityState,
              myUid: myUid,
              myName: myName,
              partnerUid: partnerProfile?.uid ?? '',
              partnerName: partnerName,
              strings: strings,
            ),
            const SizedBox(height: 16),

            // 4. DAILY QUESTION HIGHLIGHT CARD
            _buildDailyQuestionCard(
              context,
              question: todayQuestion,
              activityState: activityState,
              myUid: myUid,
              myName: myName,
              partnerName: partnerName,
              isPt: isPt,
              strings: strings,
            ),
            const SizedBox(height: 16),

            // 5. LIVE COMPACT SUMMARY CARDS (Pinned Note, Urgent Tasks, Next Event)
            _buildPinnedNoteCard(
              context,
              pinnedNote: pinnedNote,
              myUid: myUid,
              isPt: isPt,
              strings: strings,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildUpcomingTasksMiniCard(
                    context,
                    topTasks: topTasks,
                    totalPending: countPendingTasks(tasks),
                    strings: strings,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNextEventMiniCard(
                    context,
                    nextEvent: nextEvent,
                    localeStr: locale.toString(),
                    strings: strings,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LoyaltyCouponModel? _findRecentPartnerCoupon(
    List<LoyaltyCouponModel> coupons,
    String myUid,
  ) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    LoyaltyCouponModel? latest;
    for (final c in coupons) {
      if (c.lastRedeemedAt != null &&
          c.lastRedeemedAt!.isAfter(cutoff) &&
          c.lastRedeemedBy != null &&
          c.lastRedeemedBy!.isNotEmpty &&
          c.lastRedeemedBy != myUid) {
        if (latest == null ||
            c.lastRedeemedAt!.isAfter(latest.lastRedeemedAt!)) {
          latest = c;
        }
      }
    }
    return latest;
  }

  List<TaskModel> _pickTopPendingTasks(List<TaskModel> tasks) {
    final pending = tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) {
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        if (a.dueDate != null) return -1;
        if (b.dueDate != null) return 1;
        return a.title.compareTo(b.title);
      });
    return pending.take(2).toList();
  }

  CalendarEventModel? _pickNextUpcomingEvent(List<CalendarEventModel> events) {
    final now = DateTime.now();
    final upcoming = events.where((e) => !e.isPast(from: now)).toList()
      ..sort((a, b) => a
          .nextOccurrenceDate(from: now)
          .compareTo(b.nextOccurrenceDate(from: now)));
    return upcoming.firstOrNull;
  }

  Widget _buildCoupleHeader(
    BuildContext context, {
    required CoupleModel? couple,
    required String myUid,
    required String myName,
    required String? myAvatarUrl,
    required String partnerName,
    required String? partnerAvatarUrl,
    required int daysTogether,
    required int dailyStreak,
    required AppStrings strings,
  }) {
    final headerNames = couple != null && couple.partnerProfiles.length >= 2
        ? '$myName & $partnerName'
        : myName;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDarkMode
              ? [const Color(0xFF3A1829), const Color(0xFF23162D)]
              : [const Color(0xFFFFE5EE), const Color(0xFFF6EBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppTheme.primaryRose.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 50,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: PartnerAvatarWidget(
                    name: myName,
                    avatarUrl: myAvatarUrl,
                    radius: 23,
                    accentColor: AppTheme.primaryRose,
                    showBorder: true,
                  ),
                ),
                Positioned(
                  left: 28,
                  child: PartnerAvatarWidget(
                    name: partnerName,
                    avatarUrl: partnerAvatarUrl,
                    radius: 23,
                    accentColor: AppTheme.tertiaryMauve,
                    showBorder: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerNames,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      strings.daysTogetherCount(daysTogether),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                    if (dailyStreak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          strings.streakDaysBadge(dailyStreak),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD84315),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (couple != null && myUid.isNotEmpty)
            IconButton(
              tooltip: strings.editProfileTooltip,
              icon: const Icon(
                Icons.edit_rounded,
                color: AppTheme.primaryRose,
                size: 21,
              ),
              onPressed: () => showEditCoupleProfileSheet(
                context,
                coupleId: widget.coupleId,
                couple: couple,
                myUid: myUid,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSosBanner(
    BuildContext context, {
    required String requestText,
    required String senderName,
    required AppStrings strings,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryRose.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🆘', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SOS Carinho • $senderName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF9F1239),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            requestText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4C0519),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await ref
                  .read(cycleRepositoryProvider)
                  .clearCareRequest(widget.coupleId);
            },
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: Text(strings.sosBannerAction),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildSpicyNudgeBanner(
    BuildContext context, {
    required String message,
    required AppStrings strings,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? const Color(0xFF3A1228)
            : const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD81B60).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AdultGamesScreen(coupleId: widget.coupleId),
                    ),
                  );
                },
                child: Text(strings.spicyBannerOpen),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(adultGamesRepositoryProvider)
                      .clearNudge(widget.coupleId);
                },
                child: Text(strings.dismissLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecideBanner(
    BuildContext context, {
    required int count,
    required AppStrings strings,
  }) {
    return Material(
      color: AppTheme.secondaryPlum.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => widget.onSwitchTab(3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text('🗳️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.openBallotsBanner(count),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Text(
                strings.voteNowBtn,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: AppTheme.primaryRose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponBanner(
    BuildContext context, {
    required LoyaltyCouponModel coupon,
    required String partnerName,
    required AppStrings strings,
  }) {
    return Material(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LoyaltyScreen(coupleId: widget.coupleId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(coupon.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.couponRedeemedBannerTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    Text(
                      '$partnerName: ${coupon.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: Color(0xFF451A03),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB45309)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresenceCard(
    BuildContext context, {
    required ActivityStateModel activityState,
    required String myUid,
    required String myName,
    required String partnerUid,
    required String partnerName,
    required AppStrings strings,
  }) {
    final myMood = activityState.activeMoodFor(myUid);
    final partnerMood = activityState.activeMoodFor(partnerUid);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                strings.howAreWeTodayTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              if (activityState.totalPulsesCount > 0)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () =>
                      setState(() => _showRecentPulses = !_showRecentPulses),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '💓 ${activityState.totalPulsesCount}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryRose,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Both partners' current mood pills
          Row(
            children: [
              Expanded(
                child: _buildMoodStatusBox(
                  context,
                  name: myName,
                  mood: myMood,
                  emptyHint: strings.tapToSetMoodHint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMoodStatusBox(
                  context,
                  name: partnerName,
                  mood: partnerMood,
                  emptyHint: strings.isPortuguese ? 'Ainda não marcou' : 'Not set yet',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mood selector chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PartnerMood.presets.map((preset) {
              final label = preset.label(isPortuguese: strings.isPortuguese);
              final isSelected = myMood?.emoji == preset.emoji;
              return ChoiceChip(
                selected: isSelected,
                label: Text('${preset.emoji} $label'),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppTheme.primaryRose : context.textPrimary,
                ),
                selectedColor: AppTheme.primaryRose.withValues(alpha: 0.16),
                onSelected: (_) => _selectMood(
                  preset,
                  myUid: myUid,
                  myName: myName,
                  existingNote: isSelected ? myMood?.note : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // "Enviar Carinho / Tô com Saudade 💓" CTA with burst animation
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryRose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _sendingPulse
                      ? null
                      : () => _sendLovePulse(myUid, myName),
                  icon: const Icon(Icons.favorite_rounded, size: 20),
                  label: Text(
                    strings.sendLovePulseBtn,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (_pulseBurstCounter > 0)
                IgnorePointer(
                  child: Text(
                    '💓  💕  💖',
                    key: ValueKey(_pulseBurstCounter),
                    style: const TextStyle(fontSize: 22),
                  )
                      .animate()
                      .fadeIn(duration: 120.ms)
                      .slideY(begin: 0, end: -1.4, duration: 700.ms)
                      .fadeOut(delay: 350.ms, duration: 350.ms),
                ),
            ],
          ),

          if (_showRecentPulses && activityState.recentPulses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${strings.recentPulsesTitle} (${strings.totalPulsesLabel(activityState.totalPulsesCount)})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...activityState.recentPulses.take(4).map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${p.senderName}: ${p.message} (${DateFormat.Hm().format(p.sentAt)})',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodStatusBox(
    BuildContext context, {
    required String name,
    required PartnerMood? mood,
    required String emptyHint,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.surfaceVariant.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          if (mood != null) ...[
            Text(
              '${mood.emoji} ${mood.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            if (mood.note != null && mood.note!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '"${mood.note}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: context.textSecondary,
                ),
              ),
            ],
          ] else
            Text(
              emptyHint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyQuestionCard(
    BuildContext context, {
    required DailyQuestionModel? question,
    required ActivityStateModel activityState,
    required String myUid,
    required String myName,
    required String partnerName,
    required bool isPt,
    required AppStrings strings,
  }) {
    final promptText = question != null
        ? DailyQuestionRepository.translatePrompt(
            question.prompt,
            languageCode: isPt ? 'pt' : 'en',
          )
        : (isPt ? 'Carregando pergunta de hoje...' : 'Loading today\'s question...');

    final isRevealed = question?.isRevealed ?? false;
    final iAnswered = question != null && myUid.isNotEmpty
        ? question.hasUserAnswered(myUid)
        : false;

    final String statusLabel;
    final Color statusColor;
    if (isRevealed) {
      statusLabel = isPt
          ? 'Revelado! Toque para ler 💕'
          : 'Revealed! Tap to read 💕';
      statusColor = AppTheme.successGreen;
    } else if (iAnswered) {
      statusLabel = isPt
          ? 'Aguardando $partnerName 🔒'
          : 'Waiting for $partnerName 🔒';
      statusColor = const Color(0xFFE65100);
    } else {
      statusLabel = isPt ? 'Responda hoje ✍️' : 'Answer today ✍️';
      statusColor = AppTheme.primaryRose;
    }

    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DailyQuestionScreen(
                coupleId: widget.coupleId,
                currentUid: myUid,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.primaryRose.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    strings.dailyConnectionTitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryRose,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                promptText,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  height: 1.3,
                ),
              ),
              if (iAnswered && !isRevealed) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleNudgePartner(
                      activityState: activityState,
                      myUid: myUid,
                      myName: myName,
                      partnerName: partnerName,
                    ),
                    icon: const Icon(Icons.notifications_active_rounded, size: 17),
                    label: Text(strings.nudgePartnerBtn),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedNoteCard(
    BuildContext context, {
    required NoteModel? pinnedNote,
    required String myUid,
    required bool isPt,
    required AppStrings strings,
  }) {
    String displayTitle = strings.pinnedNoteCardTitle;
    String displayBody = strings.noPinnedNoteYet;
    if (pinnedNote != null) {
      final isConcealedForMe = pinnedNote.isScratchCard &&
          !pinnedNote.isScratched &&
          pinnedNote.authorUid != myUid;
      if (isConcealedForMe) {
        final masked = WidgetSyncService.formatNoteForWidget(
          pinnedNote,
          isPortuguese: isPt,
        );
        displayTitle = masked['note_title']!;
        displayBody = masked['note_content']!;
      } else if (pinnedNote.isScratchCard && !pinnedNote.isScratched) {
        displayTitle = pinnedNote.title.isNotEmpty
            ? pinnedNote.title
            : strings.pinnedNoteCardTitle;
        displayBody = isPt
            ? 'Aguardando seu amor raspar 🎁'
            : 'Waiting for your partner to scratch 🎁';
      } else {
        displayTitle = pinnedNote.title.isNotEmpty
            ? pinnedNote.title
            : strings.pinnedNoteCardTitle;
        displayBody = pinnedNote.content;
      }
    }

    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NotesScreen(
                coupleId: widget.coupleId,
                currentUid: myUid,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.outlineColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.sticky_note_2_rounded,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingTasksMiniCard(
    BuildContext context, {
    required List<TaskModel> topTasks,
    required int totalPending,
    required AppStrings strings,
  }) {
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onSwitchTab(1),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.outlineColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: AppTheme.primaryRose,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.upcomingTasksCardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (topTasks.isEmpty)
                Text(
                  strings.allTasksDoneToday,
                  style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                )
              else
                ...topTasks.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${t.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ),
              if (totalPending > topTasks.length)
                Text(
                  '+${totalPending - topTasks.length}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryRose,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextEventMiniCard(
    BuildContext context, {
    required CalendarEventModel? nextEvent,
    required String localeStr,
    required AppStrings strings,
  }) {
    final daysUntil = nextEvent != null
        ? nextEvent
            .nextOccurrenceDate()
            .difference(
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              ),
            )
            .inDays
        : null;

    final nextOcc = nextEvent?.nextOccurrenceDate();
    String formattedShortDate = '';
    if (nextOcc != null) {
      try {
        formattedShortDate = DateFormat.MMMd(localeStr).format(nextOcc);
      } catch (_) {
        formattedShortDate =
            '${nextOcc.day.toString().padLeft(2, '0')}/${nextOcc.month.toString().padLeft(2, '0')}';
      }
    }

    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onSwitchTab(2),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.outlineColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: AppTheme.secondaryPlum,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.nextEventCardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (nextEvent == null)
                Text(
                  strings.noUpcomingEventsYet,
                  style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                )
              else ...[
                Text(
                  nextEvent.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  daysUntil == 0
                      ? (strings.isPortuguese ? 'Hoje! 🎉' : 'Today! 🎉')
                      : daysUntil == 1
                          ? (strings.isPortuguese ? 'Amanhã 💕' : 'Tomorrow 💕')
                          : (strings.isPortuguese
                              ? 'Em $daysUntil dias ($formattedShortDate)'
                              : 'In $daysUntil days ($formattedShortDate)'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryRose,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
