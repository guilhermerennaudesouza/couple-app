import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/partner_avatar_widget.dart';
import '../../auth/data/pairing_repository.dart';
import '../../auth/domain/couple_model.dart';
import '../../home/data/activity_state_repository.dart';
import '../../home/domain/activity_state_model.dart';
import '../../notes/presentation/notes_screen.dart';
import '../data/daily_question_repository.dart';
import '../domain/daily_question_model.dart';

/// Screen presenting Krivo's flagship daily intimacy feature:
/// A daily prompt presented to both partners where both answers stay concealed
/// until both submit.
class DailyQuestionScreen extends ConsumerStatefulWidget {
  final CoupleModel? initialCouple;
  final String? coupleId;
  final String? currentUid;

  const DailyQuestionScreen({
    super.key,
    this.initialCouple,
    this.coupleId,
    this.currentUid,
  });

  @override
  ConsumerState<DailyQuestionScreen> createState() =>
      _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends ConsumerState<DailyQuestionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isSendingComment = false;
  bool _isNudging = false;
  String _searchQuery = '';
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    _answerController.dispose();
    _commentController.dispose();
    _searchController.dispose();
    _answerFocusNode.dispose();
    super.dispose();
  }

  String _formatCountdownUntilTomorrow(bool isPt) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return isPt
        ? 'Próxima pergunta em ${h}h ${m.toString().padLeft(2, '0')}min'
        : 'Next prompt in ${h}h ${m.toString().padLeft(2, '0')}m';
  }

  Future<void> _showProposeCustomQuestionDialog(
    String coupleId,
    String myUid,
  ) async {
    final strings = AppStrings.of(context);
    final submitted = await showDialog<String?>(
      context: context,
      builder: (_) => const _ProposeCustomQuestionDialog(),
    );

    if (submitted == null || submitted.isEmpty || !mounted) return;
    try {
      final assignedDate = await ref
          .read(dailyQuestionRepositoryProvider)
          .proposeCustomQuestion(
            coupleId,
            prompt: submitted,
            proposedByUid: myUid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isPortuguese
                ? 'Pergunta surpresa agendada para $assignedDate! ✨'
                : 'Surprise prompt scheduled for $assignedDate! ✨',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  String _getEffectiveUid() {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    final providerUid = ref.read(currentUserUidProvider).valueOrNull;
    if (providerUid != null && providerUid.isNotEmpty) {
      return providerUid;
    }
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    // Resolve coupleId
    final activeCoupleId = widget.coupleId ??
        widget.initialCouple?.id ??
        ref.watch(currentCoupleIdProvider).valueOrNull ??
        '';

    if (activeCoupleId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(strings.dailyConnectionTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 64,
                  color: AppTheme.primaryRose.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.noSpaceConnected,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.noSpaceConnectedDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Watch live couple data if possible for partner profile details
    final coupleAsync = ref.watch(coupleStreamProvider(activeCoupleId));
    final couple = coupleAsync.valueOrNull ?? widget.initialCouple;
    final streak = ref.watch(dailyStreakProvider(activeCoupleId));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: AppTheme.primaryRose,
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                strings.dailyConnectionTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (streak > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '🔥 $streak',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppTheme.primaryRose,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(
              icon: const Icon(Icons.wb_sunny_outlined, size: 20),
              text: strings.tabTodayPrompt,
            ),
            Tab(
              icon: const Icon(Icons.history_edu_rounded, size: 20),
              text: strings.tabPastMemories,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_rounded, color: AppTheme.primaryRose),
            tooltip: strings.proposeCustomQuestionBtn,
            onPressed: () => _showProposeCustomQuestionDialog(
              activeCoupleId,
              _getEffectiveUid(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sticky_note_2_rounded, color: AppTheme.primaryRose),
            tooltip: strings.loveNotesTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NotesScreen(
                    coupleId: activeCoupleId,
                    currentUid: _getEffectiveUid(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: strings.howItWorksTooltip,
            onPressed: () => _showHowItWorksDialog(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(context, activeCoupleId, couple),
          _buildPastTab(context, activeCoupleId, couple),
        ],
      ),
    );
  }

  Widget _buildTodayTab(
    BuildContext context,
    String coupleId,
    CoupleModel? couple,
  ) {
    final strings = AppStrings.of(context);
    final todayAsync = ref.watch(todayDailyQuestionProvider(coupleId));

    return todayAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppTheme.errorRed, size: 48),
              const SizedBox(height: 12),
              Text(
                '${strings.couldNotLoadQuestion} $err',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.refresh(todayDailyQuestionProvider(coupleId)),
                child: Text(strings.retry),
              ),
            ],
          ),
        ),
      ),
      data: (dq) {
        final myUid = _getEffectiveUid();
        final hasAnswered = dq.hasUserAnswered(myUid);
        final isRevealed = dq.isRevealed;

        return RefreshIndicator(
          color: AppTheme.primaryRose,
          onRefresh: () async {
            ref.invalidate(todayDailyQuestionProvider(coupleId));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDateHeader(dq.date),
                const SizedBox(height: 12),
                _buildPromptCard(DailyQuestionRepository.translatePrompt(dq.prompt, languageCode: ref.watch(localeProvider).languageCode)),
                const SizedBox(height: 20),
                if (!hasAnswered) ...[
                  // State 1: Prompt displayed, user has not answered
                  _buildState1Input(context, coupleId, dq, myUid),
                ] else if (hasAnswered && !isRevealed) ...[
                  // State 2: User answered, partner hasn't
                  _buildState2Waiting(context, coupleId, dq, myUid, couple),
                ] else ...[
                  // State 3: Both answered -> Dual reveal
                  _buildState3Revealed(context, coupleId, dq, myUid, couple),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateHeader(String dateString) {
    final strings = AppStrings.of(context);
    DateTime dt = DateTime.tryParse(dateString) ?? DateTime.now();
    final loc = Localizations.localeOf(context).toString();
    String formatted;
    try {
      if (loc.startsWith('pt')) {
        formatted = DateFormat('EEEE, d \'de\' MMMM', 'pt_BR').format(dt);
      } else {
        formatted = DateFormat('EEEE, MMMM d', 'en_US').format(dt);
      }
      if (formatted.isNotEmpty) {
        formatted = formatted[0].toUpperCase() + formatted.substring(1);
      }
    } catch (_) {
      formatted = DateFormat('EEEE, MMMM d').format(dt);
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.secondaryBlush.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: AppTheme.primaryRoseDark,
              ),
              const SizedBox(width: 6),
              Text(
                formatted,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryRoseDark,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryRose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_rounded, size: 13, color: AppTheme.primaryRose),
              const SizedBox(width: 5),
              Text(
                strings.dualBlindRevealBadge,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryRose,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildPromptCard(String prompt) {
    final strings = AppStrings.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.cardColor,
            context.surfaceVariant.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: AppTheme.primaryRose.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRose.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRose.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.format_quote_rounded,
                  color: AppTheme.primaryRose,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                strings.todayQuestionTag,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppTheme.tertiaryMauve,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            prompt,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  // -------------------------------------------------------------
  // STATE 1: Unanswered
  // -------------------------------------------------------------
  Widget _buildState1Input(
    BuildContext context,
    String coupleId,
    DailyQuestionModel dq,
    String myUid,
  ) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.secondaryBlush.withValues(alpha: 0.15)
                : AppTheme.pastelPeach.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.secondaryBlush.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryRoseDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.sealedNotice,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _answerController,
          focusNode: _answerFocusNode,
          maxLines: 4,
          minLines: 3,
          maxLength: 600,
          style: const TextStyle(fontSize: 15, height: 1.4),
          decoration: InputDecoration(
            hintText: strings.answerPlaceholder,
            hintStyle: TextStyle(
              color: context.textSecondary.withValues(alpha: 0.7),
            ),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
              borderSide: BorderSide(color: context.outlineColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
              borderSide: const BorderSide(color: AppTheme.primaryRose, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _submitAnswer(coupleId, dq.id, myUid),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryRose,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
            ),
            elevation: 2,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Colors.white, size: 20)
                        .animate(
                          onPlay: (controller) => controller.repeat(reverse: true),
                        )
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.2, 1.2),
                          duration: 700.ms,
                        ),
                    const SizedBox(width: 10),
                    Text(
                      strings.sendAnswerBtn,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.08, end: 0);
  }

  Future<void> _submitAnswer(
    String coupleId,
    String questionId,
    String myUid,
  ) async {
    final strings = AppStrings.of(context);
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.emptyAnswerError),
          backgroundColor: AppTheme.primaryRoseDark,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(dailyQuestionRepositoryProvider);
      await repo.submitAnswer(coupleId, questionId, myUid, text);
      final couple = ref.read(coupleStreamProvider(coupleId)).valueOrNull ??
          widget.initialCouple;
      final myName = couple?.getMyProfile(myUid)?.displayName ?? 'Seu amor';
      ref.read(activityStateRepositoryProvider).recordActivity(
            coupleId,
            eventType: ActivityStateModel.typeDailyAnswer,
            actorUid: myUid,
            actorName: myName,
            title: 'Pergunta do Dia ✨',
            body: '$myName respondeu a Pergunta do Dia! 💕',
            route: 'daily_question',
          );
      _answerController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.answerSealedSuccess),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${strings.isPortuguese ? 'Erro ao enviar resposta:' : 'Failed to submit answer:'} $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // -------------------------------------------------------------
  // STATE 2: Waiting for partner
  // -------------------------------------------------------------
  Widget _buildState2Waiting(
    BuildContext context,
    String coupleId,
    DailyQuestionModel dq,
    String myUid,
    CoupleModel? couple,
  ) {
    final strings = AppStrings.of(context);
    final partnerProfile = couple?.getPartnerProfile(myUid);
    final partnerName = partnerProfile?.name.isNotEmpty == true
        ? partnerProfile!.name
        : (strings.isPortuguese ? 'seu amor' : 'your partner');

    final myAnswer = dq.getAnswer(myUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Waiting banner card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            border: Border.all(color: AppTheme.secondaryBlush.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondaryBlush.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryBlush,
                      AppTheme.primaryRoseLight,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.08, 1.08),
                    duration: 1200.ms,
                  ),
              const SizedBox(height: 18),
              Text(
                strings.waitingForPartnerTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.waitingForPartnerDesc(partnerName),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.pastelLavender.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: AppTheme.tertiaryMauve,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      strings.isPortuguese
                          ? 'Ambas as respostas são reveladas juntas'
                          : 'Both answers unlock automatically',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.tertiaryMauve.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

        const SizedBox(height: 20),

        // My submitted answer preview
        if (myAnswer != null) ...[
          Text(
            strings.isPortuguese ? 'SUA RESPOSTA PROTEGIDA' : 'YOUR SEALED ANSWER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.outlineColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  myAnswer.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.isPortuguese
                      ? 'Respondido às ${DateFormat('HH:mm').format(myAnswer.answeredAt)}'
                      : 'Answered at ${DateFormat('h:mm a').format(myAnswer.answeredAt)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          icon: const Icon(Icons.notifications_active_rounded, size: 18),
          label: Text(strings.nudgePartnerBtn),
          onPressed: _isNudging
              ? null
              : () async {
                  final activityState =
                      ref.read(activityStateStreamProvider(coupleId)).valueOrNull ??
                          const ActivityStateModel();
                  final myName =
                      couple?.getMyProfile(myUid)?.displayName ?? 'Seu amor';
                  final partnerName =
                      couple?.getPartnerProfile(myUid)?.displayName ?? 'Seu amor';
                  if (!activityState.canNudgePartner(myUid)) {
                    final mins = activityState
                        .remainingNudgeCooldown(myUid)
                        .inMinutes
                        .clamp(1, 60);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.nudgeCooldownMessage(mins))),
                    );
                    return;
                  }
                  setState(() => _isNudging = true);
                  try {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(activityStateRepositoryProvider)
                        .sendDailyQuestionNudge(
                          coupleId,
                          senderUid: myUid,
                          senderName: myName,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(strings.nudgeSentSuccess(partnerName)),
                        backgroundColor: AppTheme.primaryRose,
                      ),
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$e'),
                          backgroundColor: AppTheme.errorRed,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isNudging = false);
                  }
                },
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // STATE 3: Both answered (Revealed!)
  // -------------------------------------------------------------
  Widget _buildState3Revealed(
    BuildContext context,
    String coupleId,
    DailyQuestionModel dq,
    String myUid,
    CoupleModel? couple,
  ) {
    final strings = AppStrings.of(context);
    final myProfile = couple?.getMyProfile(myUid);
    final partnerProfile = couple?.getPartnerProfile(myUid);

    final myName = myProfile?.name.isNotEmpty == true
        ? myProfile!.name
        : (strings.isPortuguese ? 'Você' : 'You');
    final partnerName = partnerProfile?.name.isNotEmpty == true
        ? partnerProfile!.name
        : (strings.isPortuguese ? 'Seu Amor' : 'Partner');

    final myAnswer = dq.getAnswer(myUid);
    final partnerAnswer = dq.getPartnerAnswer(myUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reveal Celebration Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryRose, AppTheme.primaryRoseDark],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryRose.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2),
                    duration: 600.ms,
                  ),
              const SizedBox(width: 8),
              Text(
                strings.bothAnsweredTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

        const SizedBox(height: 20),

        // Side-by-side or stacked conversation cards
        if (myAnswer != null)
          _buildAnswerCard(
            context,
            authorName: myName,
            isMe: true,
            avatarUrl: myProfile?.avatarUrl,
            answer: myAnswer,
          ).animate().fadeIn(duration: 450.ms).slideX(begin: -0.05, end: 0),

        const SizedBox(height: 14),

        if (partnerAnswer != null)
          _buildAnswerCard(
            context,
            authorName: partnerName,
            isMe: false,
            avatarUrl: partnerProfile?.avatarUrl,
            answer: partnerAnswer,
          ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.05, end: 0),

        const SizedBox(height: 18),

        // Quick Emoji Reactions Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.outlineColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    strings.isPortuguese ? 'Reagir às respostas' : 'React to answers',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: context.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (dq.reactions.isNotEmpty)
                    Text(
                      dq.reactions.values.join(' '),
                      style: const TextStyle(fontSize: 16),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: DailyQuestionModel.reactionOptions.map((emoji) {
                  final myReaction = dq.reactions[myUid];
                  final selected = myReaction == emoji;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(emoji, style: const TextStyle(fontSize: 18)),
                    selectedColor: AppTheme.primaryRose.withValues(alpha: 0.18),
                    onSelected: (_) async {
                      HapticFeedback.selectionClick();
                      try {
                        await ref
                            .read(dailyQuestionRepositoryProvider)
                            .toggleReaction(
                              coupleId,
                              dq.id,
                              uid: myUid,
                              emoji: emoji,
                              currentEmoji: myReaction,
                            );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$e'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        }
                      }
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 22),
              Text(
                strings.isPortuguese ? 'Comentários do casal' : 'Couple comments',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (dq.comments.isEmpty)
                Text(
                  strings.isPortuguese
                      ? 'Escreva um comentário carinhoso sobre a resposta de hoje 💬'
                      : 'Leave a sweet note about today\'s answers 💬',
                  style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                )
              else
                ...dq.comments.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: '${c.authorName}: ',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(text: c.text),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLength: 200,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: strings.isPortuguese
                            ? 'Responder com carinho...'
                            : 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryRose,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    onPressed: _isSendingComment
                        ? null
                        : () async {
                            final txt = _commentController.text.trim();
                            if (txt.isEmpty) return;
                            setState(() => _isSendingComment = true);
                            try {
                              await ref
                                  .read(dailyQuestionRepositoryProvider)
                                  .addComment(
                                    coupleId,
                                    dq.id,
                                    DailyQuestionComment(
                                      id: const Uuid().v4().substring(0, 8),
                                      uid: myUid,
                                      authorName: myName,
                                      text: txt,
                                      createdAt: DateTime.now(),
                                    ),
                                  );
                              _commentController.clear();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$e'),
                                    backgroundColor: AppTheme.errorRed,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isSendingComment = false);
                              }
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Countdown until tomorrow's prompt
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.pastelLavender.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.tertiaryMauve.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                color: AppTheme.primaryRose,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatCountdownUntilTomorrow(strings.isPortuguese),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 450.ms),
      ],
    );
  }

  Widget _buildAnswerCard(
    BuildContext context, {
    required String authorName,
    required bool isMe,
    required String? avatarUrl,
    required DailyQuestionAnswer answer,
  }) {
    final strings = AppStrings.of(context);
    final bgColor = isMe
        ? AppTheme.primaryRoseLight.withValues(alpha: 0.12)
        : AppTheme.pastelLavender.withValues(alpha: 0.35);

    final borderColor = isMe
        ? AppTheme.primaryRose.withValues(alpha: 0.3)
        : AppTheme.tertiaryMauve.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 20),
        ),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(avatarUrl, authorName, isMe),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        authorName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isMe
                              ? AppTheme.primaryRoseDark
                              : AppTheme.tertiaryMauve,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRose,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            strings.isPortuguese ? 'VOCÊ' : 'YOU',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(strings.isPortuguese ? 'HH:mm' : 'h:mm a').format(answer.answeredAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            answer.text,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name, bool isMe) {
    return PartnerAvatarWidget(
      name: name,
      avatarUrl: avatarUrl,
      radius: 18,
      accentColor: isMe ? AppTheme.primaryRose : AppTheme.tertiaryMauve,
    );
  }

  // -------------------------------------------------------------
  // TAB 2: Past Memories Archive
  // -------------------------------------------------------------
  Widget _buildPastTab(
    BuildContext context,
    String coupleId,
    CoupleModel? couple,
  ) {
    final strings = AppStrings.of(context);
    final pastAsync = ref.watch(pastDailyQuestionsProvider(coupleId));

    return pastAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, _) => Center(
        child: Text('${strings.errorLoadingArchive} $err'),
      ),
      data: (questions) {
        if (questions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 64,
                    color: AppTheme.tertiaryMauve.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.noPastAnswers,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.isPortuguese
                        ? 'Respondam à primeira pergunta do dia juntos para começar a construir seu acervo de memórias românticas!'
                        : 'Answer your first daily question together today to begin building your romantic memories collection!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        final myUid = _getEffectiveUid();
        final filtered = DailyQuestionRepository.filterPastQuestions(
          questions,
          todayKey: DailyQuestionRepository.todayDateString,
          query: _searchQuery,
          myUid: myUid,
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  hintText: strings.searchPastMemoriesHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        strings.isPortuguese
                            ? 'Nenhuma memória encontrada para "$_searchQuery".'
                            : 'No memories match "$_searchQuery".',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final q = filtered[index];
                        return _buildArchiveQuestionCard(
                          context,
                          coupleId,
                          q,
                          myUid,
                          couple,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArchiveQuestionCard(
    BuildContext context,
    String coupleId,
    DailyQuestionModel q,
    String myUid,
    CoupleModel? couple,
  ) {
    final strings = AppStrings.of(context);
    DateTime dt = DateTime.tryParse(q.date) ?? DateTime.now();
    String formattedDate;
    try {
      if (strings.isPortuguese) {
        formattedDate = DateFormat('d \'de\' MMMM \'de\' yyyy', 'pt_BR').format(dt);
      } else {
        formattedDate = DateFormat('MMMM d, yyyy', 'en_US').format(dt);
      }
    } catch (_) {
      formattedDate = DateFormat('MMMM d, yyyy').format(dt);
    }
    final myProfile = couple?.getMyProfile(myUid);
    final partnerProfile = couple?.getPartnerProfile(myUid);
    final myName = myProfile?.name.isNotEmpty == true ? myProfile!.name : (strings.isPortuguese ? 'Você' : 'You');
    final partnerName = partnerProfile?.name.isNotEmpty == true
        ? partnerProfile!.name
        : (strings.isPortuguese ? 'Seu Amor' : 'Partner');

    final myAnswer = q.getAnswer(myUid);
    final partnerAnswer = q.getPartnerAnswer(myUid);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.outlineColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: q.isRevealed
                  ? AppTheme.primaryRose.withValues(alpha: 0.12)
                  : context.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              q.isRevealed
                  ? Icons.lock_open_rounded
                  : Icons.lock_clock_rounded,
              color: q.isRevealed
                  ? AppTheme.primaryRose
                  : context.textSecondary,
              size: 20,
            ),
          ),
          title: Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.tertiaryMauve,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              DailyQuestionRepository.translatePrompt(q.prompt, languageCode: ref.watch(localeProvider).languageCode),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          children: [
            if (!q.isRevealed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_rounded, size: 16, color: context.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q.hasUserAnswered(myUid)
                                ? (strings.isPortuguese
                                    ? 'Você já respondeu! Aguardando seu amor responder para desbloquear.'
                                    : 'You answered! Waiting for your partner to unlock.')
                                : (strings.isPortuguese
                                    ? 'Seu amor já respondeu! Envie sua resposta para desbloquear.'
                                    : 'Your partner already answered! Submit yours to unlock.'),
                            style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    if (!q.hasUserAnswered(myUid) && myUid.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryRose,
                        ),
                        onPressed: () => _showPastAnswerSheet(
                          context,
                          coupleId: coupleId,
                          question: q,
                          myUid: myUid,
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: Text(
                          strings.isPortuguese
                              ? 'Responder esta pergunta'
                              : 'Answer this question',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              if (myAnswer != null) ...[
                _buildArchiveAnswerRow(
                  author: myName,
                  text: myAnswer.text,
                  isMe: true,
                ),
                const SizedBox(height: 8),
              ],
              if (partnerAnswer != null) ...[
                _buildArchiveAnswerRow(
                  author: partnerName,
                  text: partnerAnswer.text,
                  isMe: false,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveAnswerRow({
    required String author,
    required String text,
    required bool isMe,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? AppTheme.primaryRose.withValues(alpha: 0.08)
            : AppTheme.tertiaryMauve.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            author,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMe ? AppTheme.primaryRoseDark : AppTheme.tertiaryMauve,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: context.textPrimary),
          ),
        ],
      ),
    );
  }

  void _showHowItWorksDialog(BuildContext context) {
    final strings = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.dialogBorderRadius),
        ),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryRose),
            const SizedBox(width: 8),
            Text(strings.howItWorksTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.isPortuguese
                  ? '1. Vocês dois recebem a mesma pergunta especial todas as manhãs.'
                  : '1. Both of you receive the same intimate question every morning.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              strings.isPortuguese
                  ? '2. Nenhum dos dois consegue espiar a resposta do outro antes de responder.'
                  : '2. Neither partner can peek at the other\'s answer until both have answered.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              strings.isPortuguese
                  ? '3. Assim que a segunda resposta for enviada, as duas são reveladas juntas!'
                  : '3. As soon as the second answer is submitted, both unlock together simultaneously!',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              strings.isPortuguese
                  ? '4. Relembrem perguntas e respostas anteriores a qualquer momento nas Memórias Anteriores.'
                  : '4. Revisit past daily questions anytime in your Past Memories archive.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.understood),
          ),
        ],
      ),
    );
  }

  Future<void> _showPastAnswerSheet(
    BuildContext context, {
    required String coupleId,
    required DailyQuestionModel question,
    required String myUid,
  }) async {
    final strings = AppStrings.of(context);
    final controller = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    DailyQuestionRepository.translatePrompt(
                      question.prompt,
                      languageCode: ref.read(localeProvider).languageCode,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: strings.isPortuguese
                          ? 'Escreva sua resposta para desbloquear...'
                          : 'Write your answer to unlock...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryRose,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            setSheetState(() => submitting = true);
                            try {
                              await ref
                                  .read(dailyQuestionRepositoryProvider)
                                  .submitAnswer(coupleId, question.id, myUid, text);
                              final couple = ref
                                      .read(coupleStreamProvider(coupleId))
                                      .valueOrNull ??
                                  widget.initialCouple;
                              final myName =
                                  couple?.getMyProfile(myUid)?.displayName ??
                                      'Seu amor';
                              ref.read(activityStateRepositoryProvider).recordActivity(
                                    coupleId,
                                    eventType: ActivityStateModel.typeDailyAnswer,
                                    actorUid: myUid,
                                    actorName: myName,
                                    title: 'Memória desbloqueada ✨',
                                    body:
                                        '$myName respondeu uma pergunta anterior! 💕',
                                    route: 'daily_question',
                                  );
                              if (sheetCtx.mounted) {
                                Navigator.of(sheetCtx).pop();
                              }
                            } catch (e) {
                              if (sheetCtx.mounted) {
                                setSheetState(() => submitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            strings.isPortuguese
                                ? 'Enviar & Revelar 💕'
                                : 'Submit & Reveal 💕',
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }
}

class _ProposeCustomQuestionDialog extends StatefulWidget {
  const _ProposeCustomQuestionDialog();

  @override
  State<_ProposeCustomQuestionDialog> createState() =>
      _ProposeCustomQuestionDialogState();
}

class _ProposeCustomQuestionDialogState
    extends State<_ProposeCustomQuestionDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        strings.isPortuguese
            ? 'Propor pergunta surpresa ✨'
            : 'Propose surprise prompt ✨',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.isPortuguese
                ? 'Sua pergunta será agendada automaticamente para o próximo dia disponível!'
                : 'Your prompt will be scheduled for the next available day!',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            maxLength: 200,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: strings.isPortuguese
                  ? 'Ex: Qual foi a viagem mais inesquecível que fizemos juntos?'
                  : 'E.g. What was our most unforgettable trip together?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final text = _ctrl.text.trim();
            if (text.isEmpty) return;
            Navigator.of(context).pop(text);
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}
