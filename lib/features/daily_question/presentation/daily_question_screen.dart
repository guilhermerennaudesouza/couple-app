import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../auth/data/pairing_repository.dart';
import '../../auth/domain/couple_model.dart';
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
  final FocusNode _answerFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _answerController.dispose();
    _answerFocusNode.dispose();
    super.dispose();
  }

  String _getEffectiveUid() {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'guest_uid';
  }

  @override
  Widget build(BuildContext context) {
    // Resolve coupleId
    final activeCoupleId = widget.coupleId ??
        widget.initialCouple?.id ??
        ref.watch(currentCoupleIdProvider).valueOrNull ??
        '';

    if (activeCoupleId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Daily Question'),
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
                  color: AppTheme.primaryRose.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Couple Space Connected',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please pair with your partner before accessing your daily intimate questions.',
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_rounded,
              color: AppTheme.primaryRose,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text('Daily Connection'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppTheme.primaryRose,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.wb_sunny_outlined, size: 20),
              text: "Today's Prompt",
            ),
            Tab(
              icon: Icon(Icons.history_edu_rounded, size: 20),
              text: 'Past Memories',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sticky_note_2_rounded, color: AppTheme.primaryRose),
            tooltip: 'Love Notes & Sticky Wall',
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
            tooltip: 'How Dual Reveal Works',
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
                'Could not load today\'s question: $err',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.refresh(todayDailyQuestionProvider(coupleId)),
                child: const Text('Try Again'),
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
                  _buildState2Waiting(context, dq, myUid, couple),
                ] else ...[
                  // State 3: Both answered -> Dual reveal
                  _buildState3Revealed(context, dq, myUid, couple),
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
    DateTime dt = DateTime.tryParse(dateString) ?? DateTime.now();
    final formatted = DateFormat('EEEE, MMMM d').format(dt);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.secondaryBlush.withOpacity(0.3),
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
            color: AppTheme.primaryRose.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock_rounded, size: 13, color: AppTheme.primaryRose),
              SizedBox(width: 5),
              Text(
                'Dual-Blind Reveal',
                style: TextStyle(
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
                'TODAY\'S QUESTION',
                style: TextStyle(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.pastelPeach.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.secondaryBlush.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryRoseDark),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your answer stays sealed until both of you reply. No peeking!',
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
          style: TextStyle(fontSize: 15, height: 1.4),
          decoration: InputDecoration(
            hintText: 'Share your loving thought, memory, or feeling...',
            hintStyle: TextStyle(
              color: context.textSecondary.withOpacity(0.7),
            ),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
              borderSide: const BorderSide(color: AppTheme.outlineLight),
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
                    const Text(
                      'Send My Answer',
                      style: TextStyle(
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
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write an answer before sending!'),
          backgroundColor: AppTheme.primaryRoseDark,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(dailyQuestionRepositoryProvider);
      await repo.submitAnswer(coupleId, questionId, myUid, text);
      _answerController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your answer is sealed! Waiting for partner...'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit answer: $e'),
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
    DailyQuestionModel dq,
    String myUid,
    CoupleModel? couple,
  ) {
    final partnerProfile = couple?.getPartnerProfile(myUid);
    final partnerName = partnerProfile?.name.isNotEmpty == true
        ? partnerProfile!.name
        : 'your partner';

    final myAnswer = dq.getAnswer(myUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Waiting banner card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            border: Border.all(color: AppTheme.secondaryBlush.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondaryBlush.withOpacity(0.12),
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryBlush,
                      AppTheme.primaryRoseLight,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
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
                'Answer Submitted!',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting for $partnerName to answer to reveal both...',
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
                  color: AppTheme.pastelLavender.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: AppTheme.tertiaryMauve,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Both answers unlock automatically',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.tertiaryMauve.withOpacity(0.9),
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
            'YOUR SEALED ANSWER',
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
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineLight),
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
                  'Answered at ${DateFormat('h:mm a').format(myAnswer.answeredAt)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------
  // STATE 3: Both answered (Revealed!)
  // -------------------------------------------------------------
  Widget _buildState3Revealed(
    BuildContext context,
    DailyQuestionModel dq,
    String myUid,
    CoupleModel? couple,
  ) {
    final myProfile = couple?.getMyProfile(myUid);
    final partnerProfile = couple?.getPartnerProfile(myUid);

    final myName = myProfile?.name.isNotEmpty == true ? myProfile!.name : 'You';
    final partnerName = partnerProfile?.name.isNotEmpty == true
        ? partnerProfile!.name
        : 'Partner';

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
                color: AppTheme.primaryRose.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2),
                    duration: 600.ms,
                  ),
              const SizedBox(width: 8),
              Text(
                'Answers Revealed!',
                style: TextStyle(
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

        const SizedBox(height: 24),

        // Sweet romance reminder footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.pastelLavender.withOpacity(0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.tertiaryMauve.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppTheme.tertiaryMauve,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Talk about your answers tonight! Small conversations build lasting intimacy.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textPrimary.withOpacity(0.85),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 550.ms),
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
    final bgColor = isMe
        ? AppTheme.primaryRoseLight.withOpacity(0.12)
        : AppTheme.pastelLavender.withOpacity(0.35);

    final borderColor = isMe
        ? AppTheme.primaryRose.withOpacity(0.3)
        : AppTheme.tertiaryMauve.withOpacity(0.3);

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
            color: Colors.black.withOpacity(0.02),
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
                            'YOU',
                            style: TextStyle(
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
                    DateFormat('h:mm a').format(answer.answeredAt),
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
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '♥';
    return CircleAvatar(
      radius: 18,
      backgroundColor: isMe ? AppTheme.primaryRose : AppTheme.tertiaryMauve,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
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
    final pastAsync = ref.watch(pastDailyQuestionsProvider(coupleId));

    return pastAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, _) => Center(
        child: Text('Error loading archive: $err'),
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
                    color: AppTheme.tertiaryMauve.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Past Answers Yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Answer your first daily question together today to begin building your romantic memories collection!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        final myUid = _getEffectiveUid();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final q = questions[index];
            return _buildArchiveQuestionCard(context, q, myUid, couple);
          },
        );
      },
    );
  }

  Widget _buildArchiveQuestionCard(
    BuildContext context,
    DailyQuestionModel q,
    String myUid,
    CoupleModel? couple,
  ) {
    DateTime dt = DateTime.tryParse(q.date) ?? DateTime.now();
    final formattedDate = DateFormat('MMMM d, yyyy').format(dt);
    final myProfile = couple?.getMyProfile(myUid);
    final partnerProfile = couple?.getPartnerProfile(myUid);
    final myName = myProfile?.name.isNotEmpty == true ? myProfile!.name : 'You';
    final partnerName = partnerProfile?.name.isNotEmpty == true
        ? partnerProfile!.name
        : 'Partner';

    final myAnswer = q.getAnswer(myUid);
    final partnerAnswer = q.getPartnerAnswer(myUid);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.outlineLight),
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
                  ? AppTheme.primaryRose.withOpacity(0.12)
                  : AppTheme.surfaceVariantLight,
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
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.tertiaryMauve,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              q.prompt,
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
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 16, color: context.textSecondary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Answers remain locked until both partners submit.',
                        style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                      ),
                    ),
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
            ? AppTheme.primaryRose.withOpacity(0.08)
            : AppTheme.tertiaryMauve.withOpacity(0.08),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.dialogBorderRadius),
        ),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryRose),
            SizedBox(width: 8),
            Text('Dual-Blind Reveal'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Both of you receive the same intimate question every morning.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 10),
            Text(
              '2. Neither partner can peek at the other\'s answer until both have answered.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 10),
            Text(
              '3. As soon as the second answer is submitted, both unlock together simultaneously!',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 10),
            Text(
              '4. Revisit past daily questions anytime in your Past Memories archive.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
