import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/calendar/data/calendar_repository.dart';
import 'package:couple_app/features/calendar/domain/calendar_event_model.dart';
import 'package:couple_app/features/date_ideas/data/date_ideas_repository.dart';
import 'package:couple_app/features/date_ideas/domain/date_idea_model.dart';
import 'package:couple_app/features/home/data/activity_state_repository.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';

/// Interactive "Tinder de Encontros" swipe discovery view for couple date ideas.
class DateIdeasSwipeView extends ConsumerStatefulWidget {
  final String coupleId;
  final String myUid;
  final List<DateIdeaModel> coupleIdeas;
  final String selectedCategory;

  const DateIdeasSwipeView({
    super.key,
    required this.coupleId,
    required this.myUid,
    required this.coupleIdeas,
    required this.selectedCategory,
  });

  @override
  ConsumerState<DateIdeasSwipeView> createState() => _DateIdeasSwipeViewState();
}

class _DateIdeasSwipeViewState extends ConsumerState<DateIdeasSwipeView> {
  double _dragDx = 0;
  bool _isVoting = false;

  Future<void> _vote(DateIdeaModel idea, String vote) async {
    if (_isVoting || widget.myUid.isEmpty) return;
    setState(() {
      _isVoting = true;
      _dragDx = 0;
    });
    HapticFeedback.lightImpact();

    try {
      final isMatch = await ref
          .read(dateIdeasRepositoryProvider)
          .recordSwipeVote(
            widget.coupleId,
            idea,
            uid: widget.myUid,
            vote: vote,
          );
      if (isMatch && mounted) {
        HapticFeedback.heavyImpact();
        final couple =
            ref.read(coupleStreamProvider(widget.coupleId)).valueOrNull;
        final myName =
            couple?.getMyProfile(widget.myUid)?.displayName ?? 'Seu amor';
        ref.read(activityStateRepositoryProvider).recordActivity(
              widget.coupleId,
              eventType: ActivityStateModel.typeDecide,
              actorUid: widget.myUid,
              actorName: myName,
              title: 'Deu Match de Encontro! 💕',
              body: 'Vocês dois curtiram: "${idea.title}" ✨',
              route: 'decide',
            );
        await showMatchCelebrationDialog(
          context,
          ref: ref,
          coupleId: widget.coupleId,
          myUid: widget.myUid,
          idea: idea,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _resetSkipped() async {
    final strings = AppStrings.of(context);
    try {
      final count = await ref
          .read(dateIdeasRepositoryProvider)
          .resetPassedVotes(widget.coupleId, widget.myUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? (strings.isPortuguese
                    ? '$count ideias puladas voltaram ao baralho! ✨'
                    : '$count skipped ideas restored to the deck! ✨')
                : (strings.isPortuguese
                    ? 'Nenhuma ideia pulada para restaurar.'
                    : 'No skipped ideas to restore.'),
          ),
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

  String _categoryEmoji(String category) {
    switch (category) {
      case DateIdeaModel.categoryRomance:
        return '💕';
      case DateIdeaModel.categoryFoodie:
        return '🍝';
      case DateIdeaModel.categoryOutdoor:
        return '🌅';
      case DateIdeaModel.categoryAdventurous:
        return '🚀';
      case DateIdeaModel.categoryBudget:
        return '✨';
      default:
        return '🛋️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final deck = DateIdeasRepository.buildSwipeDeck(
      coupleIdeas: widget.coupleIdeas,
      myUid: widget.myUid,
      categoryFilter: widget.selectedCategory,
    );
    final skippedCount = widget.coupleIdeas
        .where((i) => i.userVote(widget.myUid) == DateIdeaModel.votePass)
        .length;
    final matchedCount =
        widget.coupleIdeas.where((i) => !i.isCompleted && i.isMatched).length;

    if (deck.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                strings.isPortuguese
                    ? 'Você viu todas as ideias desta categoria!'
                    : 'You\'ve seen every idea in this category!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              if (skippedCount > 0)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryRose,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _resetSkipped,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('${strings.reviewSkippedBtn} ($skippedCount)'),
                ),
            ],
          ),
        ),
      );
    }

    final topCard = deck.first;
    final isLikeTilt = _dragDx > 24;
    final isPassTilt = _dragDx < -24;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '💕 $matchedCount ${strings.isPortuguese ? 'matches' : 'matches'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryRose,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${deck.length} ${strings.isPortuguese ? 'restantes' : 'left'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Draggable Swipe Card
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() => _dragDx += details.delta.dx);
            },
            onHorizontalDragEnd: (_) {
              if (_dragDx > 90) {
                _vote(topCard, DateIdeaModel.voteLike);
              } else if (_dragDx < -90) {
                _vote(topCard, DateIdeaModel.votePass);
              } else {
                setState(() => _dragDx = 0);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              transform: Matrix4.identity()
                ..translateByDouble(_dragDx * 0.6, 0.0, 0.0, 1.0)
                ..rotateZ(_dragDx * 0.0008),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 310),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: context.isDarkMode
                        ? [const Color(0xFF351A2B), const Color(0xFF21172B)]
                        : [const Color(0xFFFFF0F5), const Color(0xFFF6EEFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isLikeTilt
                        ? AppTheme.successGreen
                        : isPassTilt
                            ? AppTheme.errorRed
                            : AppTheme.primaryRose.withValues(alpha: 0.35),
                    width: (isLikeTilt || isPassTilt) ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLikeTilt || isPassTilt)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isLikeTilt
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isLikeTilt
                              ? (strings.isPortuguese ? 'QUERO! 💕' : 'WANT! 💕')
                              : (strings.isPortuguese ? 'AGORA NÃO' : 'NOT NOW'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Text(
                      _categoryEmoji(topCard.category),
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRose.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        topCard.category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryRose,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      topCard.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      topCard.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Swipe action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: const CircleBorder(),
                    side: const BorderSide(color: AppTheme.errorRed, width: 2),
                    foregroundColor: AppTheme.errorRed,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed:
                      _isVoting ? null : () => _vote(topCard, DateIdeaModel.votePass),
                  child: const Icon(Icons.close_rounded, size: 30),
                ),
              ),
              const SizedBox(width: 28),
              SizedBox(
                width: 72,
                height: 72,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: AppTheme.primaryRose,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed:
                      _isVoting ? null : () => _vote(topCard, DateIdeaModel.voteLike),
                  child: const Icon(Icons.favorite_rounded, size: 34),
                ),
              ),
            ],
          ),
          if (skippedCount > 0) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _resetSkipped,
              icon: const Icon(Icons.replay_rounded, size: 17),
              label: Text('${strings.reviewSkippedBtn} ($skippedCount)'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Celebratory "Deu Match! 💕" (or Random Pick 🎲) modal with 1-tap scheduling into Calendar.
Future<void> showMatchCelebrationDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String coupleId,
  required String myUid,
  required DateIdeaModel idea,
  bool isRandomPick = false,
}) async {
  final strings = AppStrings.of(context);
  final dialogTitle = isRandomPick
      ? (strings.isPortuguese ? 'Encontro Sorteado! 🎲' : 'Random Date Pick! 🎲')
      : strings.matchDialogTitle;
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Column(
        children: [
          Text(isRandomPick ? '🎲✨' : '🎉💕🎉', style: const TextStyle(fontSize: 38))
              .animate()
              .scale(duration: 350.ms),
          const SizedBox(height: 8),
          Text(
            dialogTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryRose,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            idea.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (idea.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              idea.description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: dialogCtx.textSecondary),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: Text(strings.isPortuguese ? 'Fechar' : 'Close'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryRose,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(strings.scheduleInCalendarBtn),
          onPressed: () async {
            final pickedDate = await showDatePicker(
              context: dialogCtx,
              initialDate: DateTime.now().add(const Duration(days: 2)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (pickedDate == null) return;
            await ref.read(calendarRepositoryProvider).addEvent(
                  coupleId,
                  CalendarEventModel(
                    id: '',
                    title: idea.title,
                    description: idea.description,
                    date: pickedDate,
                    category: CalendarEventModel.categoryDateNight,
                    reminderDaysBefore: 1,
                    createdBy: myUid,
                  ),
                );
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    strings.isPortuguese
                        ? 'Encontro agendado no Calendário! 📅💕'
                        : 'Date scheduled in Calendar! 📅💕',
                  ),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            }
          },
        ),
      ],
    ),
  );
}
