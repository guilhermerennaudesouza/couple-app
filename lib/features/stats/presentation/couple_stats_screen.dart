import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/core/utils/couple_date_utils.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/daily_question/data/daily_question_repository.dart';
import 'package:couple_app/features/date_ideas/data/date_ideas_repository.dart';
import 'package:couple_app/features/finance/data/finance_repository.dart';
import 'package:couple_app/features/home/data/activity_state_repository.dart';
import 'package:couple_app/features/loyalty/data/loyalty_repository.dart';
import 'package:couple_app/features/memories/data/memories_repository.dart';
import 'package:couple_app/features/notes/data/note_repository.dart';
import 'package:couple_app/features/tasks/data/task_repository.dart';
import 'package:couple_app/features/time_capsule/data/time_capsule_repository.dart';

/// Computes the Couple XP and relationship level from real-time milestones.
class CoupleStatsSummary {
  final int daysTogether;
  final int questionsAnswered;
  final int tasksCompleted;
  final int datesCompleted;
  final int memoriesCount;
  final int capsulesCount;
  final int wishesFulfilled;
  final int notesCount;
  final int couponsRedeemed;
  final double totalSavedInPiggyBank;
  final int dailyStreak;
  final int totalPulsesCount;

  const CoupleStatsSummary({
    required this.daysTogether,
    required this.questionsAnswered,
    required this.tasksCompleted,
    required this.datesCompleted,
    required this.memoriesCount,
    required this.capsulesCount,
    required this.wishesFulfilled,
    required this.notesCount,
    required this.couponsRedeemed,
    required this.totalSavedInPiggyBank,
    this.dailyStreak = 0,
    this.totalPulsesCount = 0,
  });

  int get totalXp {
    return (daysTogether * 5) +
        (questionsAnswered * 40) +
        (tasksCompleted * 25) +
        (datesCompleted * 80) +
        (memoriesCount * 60) +
        (capsulesCount * 50) +
        (wishesFulfilled * 70) +
        (notesCount * 20) +
        (couponsRedeemed * 35) +
        (dailyStreak * 15) +
        (totalPulsesCount * 5);
  }

  int get level => (totalXp ~/ 500) + 1;

  double get currentLevelProgress => (totalXp % 500) / 500.0;

  int get xpToNextLevel => 500 - (totalXp % 500);

  String get rankTitlePt => rankTitle(isPortuguese: true);

  String rankTitle({required bool isPortuguese}) {
    if (isPortuguese) {
      if (level >= 15) return 'Almas Gêmeas Lendárias 👑';
      if (level >= 10) return 'Guardiões do Amor Eterno 💎';
      if (level >= 6) return 'Parceiros Inseparáveis 🔥';
      if (level >= 3) return 'Corações em Sintonia 💕';
      return 'Apaixonados em Jornada 🌱';
    } else {
      if (level >= 15) return 'Legendary Soulmates 👑';
      if (level >= 10) return 'Guardians of Eternal Love 💎';
      if (level >= 6) return 'Inseparable Partners 🔥';
      if (level >= 3) return 'Hearts in Sync 💕';
      return 'Lovers on a Journey 🌱';
    }
  }
}

class CoupleStatsScreen extends ConsumerWidget {
  final String coupleId;

  const CoupleStatsScreen({
    super.key,
    required this.coupleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final couple = ref.watch(coupleStreamProvider(coupleId)).valueOrNull;
    final todayQuestion =
        ref.watch(todayDailyQuestionProvider(coupleId)).valueOrNull;
    final questions =
        ref.watch(pastDailyQuestionsProvider(coupleId)).valueOrNull ??
            const [];
    final tasks =
        ref.watch(tasksStreamProvider(coupleId)).valueOrNull ?? const [];
    final dateIdeas =
        ref.watch(dateIdeasStreamProvider(coupleId)).valueOrNull ?? const [];
    final memories =
        ref.watch(memoriesStreamProvider(coupleId)).valueOrNull ?? const [];
    final capsules =
        ref.watch(timeCapsulesStreamProvider(coupleId)).valueOrNull ?? const [];
    final wishes =
        ref.watch(wishlistStreamProvider(coupleId)).valueOrNull ?? const [];
    final notes =
        ref.watch(notesStreamProvider(coupleId)).valueOrNull ?? const [];
    final coupons =
        ref.watch(loyaltyCouponsStreamProvider(coupleId)).valueOrNull ??
            const [];
    final goals =
        ref.watch(savingsGoalsStreamProvider(coupleId)).valueOrNull ?? const [];
    final dailyStreak = ref.watch(dailyStreakProvider(coupleId));
    final activityState =
        ref.watch(activityStateStreamProvider(coupleId)).valueOrNull;

    final daysTogether = couple != null
        ? CoupleDateUtils.daysTogether(couple.anniversaryDate)
        : 0;

    final revealedTodayCount =
        (todayQuestion != null && todayQuestion.isRevealed) ? 1 : 0;

    final summary = CoupleStatsSummary(
      daysTogether: daysTogether,
      questionsAnswered:
          questions.where((q) => q.isRevealed).length + revealedTodayCount,
      tasksCompleted: tasks.where((t) => t.isCompleted).length,
      datesCompleted: dateIdeas.where((d) => d.isCompleted).length,
      memoriesCount: memories.length,
      capsulesCount: capsules.length,
      wishesFulfilled: wishes.where((w) => w.isPurchased).length,
      notesCount: notes.length,
      couponsRedeemed:
          coupons.fold<int>(0, (sum, c) => sum + c.usedCount),
      totalSavedInPiggyBank:
          goals.fold<double>(0.0, (sum, g) => sum + g.currentAmount),
      dailyStreak: dailyStreak,
      totalPulsesCount: activityState?.totalPulsesCount ?? 0,
    );

    final profiles = couple?.partnerProfiles.values.toList() ?? const [];
    final namesHeader = profiles.length >= 2
        ? '${profiles[0].name} & ${profiles[1].name}'
        : profiles.length == 1
            ? profiles.first.name
            : 'Nosso Casal 💕';

    final isPt = strings.isPortuguese;
    final currencyFmt = NumberFormat.currency(
      locale: isPt ? 'pt_BR' : 'en_US',
      symbol: isPt ? 'R\$' : '\$',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.hubStatsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
        children: [
          // Hero Couple XP & Level Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.isDarkMode
                    ? [const Color(0xFF3A1528), const Color(0xFF1F1429)]
                    : [const Color(0xFFFFE4EC), const Color(0xFFF3E8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.primaryRose.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRose,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isPt
                        ? 'NÍVEL ${summary.level} • ${summary.totalXp} XP'
                        : 'LEVEL ${summary.level} • ${summary.totalXp} XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  namesHeader,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  summary.rankTitle(isPortuguese: isPt),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryRose,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: summary.currentLevelProgress,
                    minHeight: 11,
                    backgroundColor: context.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryRose,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPt
                      ? 'Faltam ${summary.xpToNextLevel} XP para o Nível ${summary.level + 1}'
                      : '${summary.xpToNextLevel} XP to Level ${summary.level + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            isPt ? 'NOSSA RETROSPECTIVA EM NÚMEROS ✨' : 'OUR RETROSPECTIVE IN NUMBERS ✨',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.32,
            children: [
              _buildStatTile(
                context,
                emoji: '❤️',
                value: '${summary.daysTogether}',
                label: isPt ? 'Dias de Amor Juntos' : 'Days in Love Together',
                accent: AppTheme.primaryRose,
              ),
              _buildStatTile(
                context,
                emoji: '💬',
                value: '${summary.questionsAnswered}',
                label: isPt ? 'Perguntas Reveladas' : 'Revealed Questions',
                accent: AppTheme.secondaryPlum,
              ),
              _buildStatTile(
                context,
                emoji: '✨',
                value: '${summary.datesCompleted}',
                label: isPt ? 'Encontros Realizados' : 'Dates Completed',
                accent: const Color(0xFFF59E0B),
              ),
              _buildStatTile(
                context,
                emoji: '📸',
                value: '${summary.memoriesCount}',
                label: isPt ? 'Memórias Guardadas' : 'Saved Memories',
                accent: const Color(0xFFEC4899),
              ),
              _buildStatTile(
                context,
                emoji: '🎟️',
                value: '${summary.couponsRedeemed}',
                label: isPt ? 'Cupons de Amor Usados' : 'Love Coupons Used',
                accent: const Color(0xFF8B5CF6),
              ),
              _buildStatTile(
                context,
                emoji: '☑️',
                value: '${summary.tasksCompleted}',
                label: isPt ? 'Tarefas Concluídas' : 'Tasks Completed',
                accent: const Color(0xFF10B981),
              ),
              _buildStatTile(
                context,
                emoji: '⏳',
                value: '${summary.capsulesCount}',
                label: isPt ? 'Cápsulas do Tempo' : 'Time Capsules',
                accent: const Color(0xFF06B6D4),
              ),
              _buildStatTile(
                context,
                emoji: '🎁',
                value: '${summary.wishesFulfilled}',
                label: isPt ? 'Desejos Realizados' : 'Wishes Fulfilled',
                accent: const Color(0xFFE11D48),
              ),
              _buildStatTile(
                context,
                emoji: '🔥',
                value: '${summary.dailyStreak}',
                label: isPt ? 'Ofensiva Diária (Dias)' : 'Daily Streak (Days)',
                accent: const Color(0xFFEA580C),
              ),
              _buildStatTile(
                context,
                emoji: '💓',
                value: '${summary.totalPulsesCount}',
                label: isPt ? 'Carinhos Enviados' : 'Love Pulses Sent',
                accent: AppTheme.primaryRose,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Piggy bank summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.outlineColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🐷', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cofrinho dos Sonhos do Casal',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total economizado juntos: ${currencyFmt.format(summary.totalSavedInPiggyBank)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required String emoji,
    required String value,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
