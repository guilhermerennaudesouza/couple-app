import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_strings.dart';
import '../../auth/data/pairing_repository.dart';
import '../../auth/domain/couple_model.dart';
import '../../date_ideas/data/date_ideas_repository.dart';
import '../../date_ideas/domain/date_idea_model.dart';
import '../data/decide_repository.dart';
import '../domain/decide_model.dart';

/// Screen offering collaborative decision maker ballots ("This or That")
/// and shared bucket list date ideas.
class DecideScreen extends ConsumerStatefulWidget {
  final CoupleModel? initialCouple;
  final String? coupleId;
  final String? currentUid;

  const DecideScreen({
    super.key,
    this.initialCouple,
    this.coupleId,
    this.currentUid,
  });

  @override
  ConsumerState<DecideScreen> createState() => _DecideScreenState();
}

class _DecideScreenState extends ConsumerState<DecideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategoryFilter = 'All';
  bool _hasSeededDateIdeas = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getEffectiveUid() {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'user_uid';
  }

  void _checkAndSeedDateIdeas(String coupleId) {
    if (_hasSeededDateIdeas || coupleId.isEmpty) return;
    _hasSeededDateIdeas = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(dateIdeasRepositoryProvider).seedDefaultIdeasIfEmpty(
            coupleId,
            createdBy: _getEffectiveUid(),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentCoupleAsync = ref.watch(currentCoupleIdProvider);
    final effectiveCoupleId = widget.coupleId ??
        currentCoupleAsync.valueOrNull ??
        widget.initialCouple?.id ??
        '';

    if (effectiveCoupleId.isNotEmpty) {
      _checkAndSeedDateIdeas(effectiveCoupleId);
    }

    final coupleAsync = effectiveCoupleId.isNotEmpty
        ? ref.watch(coupleStreamProvider(effectiveCoupleId))
        : const AsyncValue<CoupleModel?>.data(null);
    final couple = coupleAsync.valueOrNull ?? widget.initialCouple;

    final myUid = _getEffectiveUid();
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.decideTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryRose,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: context.textSecondary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.how_to_vote_rounded),
              text: strings.tabDecideTogether,
            ),
            Tab(
              icon: const Icon(Icons.favorite_rounded),
              text: strings.tabDateIdeas,
            ),
          ],
        ),
      ),
      body: effectiveCoupleId.isEmpty
          ? _buildNoCoupleState()
          : TabBarView(
              controller: _tabController,
              children: [
                _DecideTab(
                  coupleId: effectiveCoupleId,
                  myUid: myUid,
                  couple: couple,
                ),
                _DateIdeasTab(
                  coupleId: effectiveCoupleId,
                  myUid: myUid,
                  couple: couple,
                  selectedCategory: _selectedCategoryFilter,
                  onCategorySelected: (cat) {
                    setState(() => _selectedCategoryFilter = cat);
                  },
                ),
              ],
            ),
      floatingActionButton: effectiveCoupleId.isEmpty
          ? null
          : _tabController.index == 0
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateBallotSheet(context, effectiveCoupleId, myUid),
                  backgroundColor: AppTheme.primaryRose,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(strings.newBallotBtn),
                )
              : FloatingActionButton.extended(
                  onPressed: () => _showAddDateIdeaSheet(context, effectiveCoupleId, myUid),
                  backgroundColor: AppTheme.primaryRose,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(strings.isPortuguese ? 'Nova Ideia' : 'Add Date Idea'),
                ),
    );
  }

  Widget _buildNoCoupleState() {
    final strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline_rounded,
              size: 64,
              color: AppTheme.primaryRose.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              strings.isPortuguese ? 'Nenhum Casal Conectado' : 'No Couple Connected',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              strings.isPortuguese
                  ? 'Conecte-se com seu amor para criar votações e planejar encontros juntos.'
                  : 'Pair with your partner first to create ballots and plan date ideas together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateBallotSheet(BuildContext context, String coupleId, String myUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateBallotBottomSheet(
        coupleId: coupleId,
        myUid: myUid,
      ),
    );
  }

  void _showAddDateIdeaSheet(BuildContext context, String coupleId, String myUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDateIdeaBottomSheet(
        coupleId: coupleId,
        myUid: myUid,
      ),
    );
  }
}

// =============================================================================
// TAB 1: DECIDE TOGETHER (THIS OR THAT)
// =============================================================================

class _DecideTab extends ConsumerWidget {
  final String coupleId;
  final String myUid;
  final CoupleModel? couple;

  const _DecideTab({
    required this.coupleId,
    required this.myUid,
    this.couple,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(decideSessionsStreamProvider(coupleId));

    return sessionsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error loading ballots: $err'),
        ),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: sessions.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildIntroBanner(context);
            }
            final session = sessions[index - 1];
            return _BallotCard(
              session: session,
              coupleId: coupleId,
              myUid: myUid,
              couple: couple,
            );
          },
        );
      },
    );
  }

  Widget _buildIntroBanner(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? AppTheme.primaryRose.withOpacity(0.15)
            : AppTheme.pastelPeach.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode
              ? AppTheme.primaryRose.withOpacity(0.4)
              : AppTheme.secondaryBlush.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          const Text('🤫', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.isPortuguese ? 'Votação Secreta do Casal' : 'Secret Partner Voting',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.isPortuguese
                      ? 'Seu voto permanece em sigilo até que ambos tenham votado!'
                      : 'Your vote remains completely secret until both of you choose!',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_vote_outlined,
              size: 64,
              color: AppTheme.primaryRose.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              strings.noBallotsYet,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.noBallotsDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BallotCard extends ConsumerWidget {
  final DecideSessionModel session;
  final String coupleId;
  final String myUid;
  final CoupleModel? couple;

  const _BallotCard({
    required this.session,
    required this.coupleId,
    required this.myUid,
    this.couple,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final hasVoted = session.hasUserVoted(myUid);
    final myVote = session.getUserVote(myUid);
    final isResolved = session.isResolved;
    final isMatch = session.isMatch;
    final isSplit = session.isSplit;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isMatch
              ? AppTheme.primaryRose.withOpacity(0.5)
              : isSplit
                  ? AppTheme.goldAccent.withOpacity(0.5)
                  : context.outlineColor,
          width: isMatch || isSplit ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                _buildStatusPill(context, session),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'delete') {
                      _confirmDelete(context, ref);
                    } else if (val == 'revote') {
                      ref
                          .read(decideRepositoryProvider)
                          .resetSessionForRevote(coupleId, session.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (isResolved)
                      PopupMenuItem(
                        value: 'revote',
                        child: Row(
                          children: [
                            const Icon(Icons.refresh_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(strings.isPortuguese ? 'Votar Novamente' : 'Re-vote'),
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
            const SizedBox(height: 8),

            // Date & Creator info
            Text(
              strings.isPortuguese
                  ? 'Criado em ${DateFormat.MMMd('pt_BR').format(session.createdAt)}'
                  : 'Created ${DateFormat.MMMd().format(session.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // MATCH CELEBRATION BANNER
            if (isMatch) _buildMatchBanner(context, session),

            // SPLIT VOTE RESOLUTION CARD
            if (isSplit) _buildSplitBanner(context, ref, session),

            // OPTIONS LIST
            const SizedBox(height: 8),
            ...session.options.map((option) {
              final isMyPick = myVote == option;
              final isWinner = session.winningOption == option;
              final canSeePartner = session.canUserSeePartnerVote(myUid);
              final partnerPick = canSeePartner ? session.getVisiblePartnerVote(myUid) : null;
              final isPartnerPick = partnerPick == option;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isWinner
                      ? AppTheme.primaryRose.withOpacity(0.12)
                      : isMyPick
                          ? AppTheme.pastelPeach.withOpacity(0.5)
                          : isPartnerPick
                              ? AppTheme.pastelLavender.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isWinner
                        ? AppTheme.primaryRose
                        : isMyPick
                            ? AppTheme.primaryRose.withOpacity(0.6)
                            : isPartnerPick
                                ? AppTheme.tertiaryMauve.withOpacity(0.5)
                                : context.outlineColor.withOpacity(0.6),
                    width: isWinner || isMyPick ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  title: Text(
                    option,
                    style: TextStyle(
                      fontWeight:
                          isWinner || isMyPick ? FontWeight.bold : FontWeight.w500,
                      color: isWinner
                          ? AppTheme.primaryRoseDark
                          : context.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: _buildOptionSubtitle(
                    context,
                    isMyPick: isMyPick,
                    isPartnerPick: isPartnerPick,
                    isWinner: isWinner,
                  ),
                  trailing: isResolved
                      ? (isWinner
                          ? const Icon(Icons.emoji_events_rounded,
                              color: AppTheme.goldAccent)
                          : null)
                      : (!hasVoted
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryRose,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                ref.read(decideRepositoryProvider).castVote(
                                      coupleId,
                                      session.id,
                                      myUid,
                                      option,
                                    );
                              },
                              child: Text(strings.isPortuguese ? 'Votar' : 'Vote'),
                            )
                          : (isMyPick
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.primaryRose)
                              : null)),
                ),
              );
            }),

            // Status message for open ballot
            if (!isResolved) ...[
              const SizedBox(height: 6),
              _buildOpenBallotFooter(context, session),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildOptionSubtitle(
    BuildContext context, {
    required bool isMyPick,
    required bool isPartnerPick,
    required bool isWinner,
  }) {
    final strings = AppStrings.of(context);
    final List<String> badges = [];
    if (isWinner) badges.add(strings.isPortuguese ? 'Opção Vencedora 🏆' : 'Winning Pick 🏆');
    if (isMyPick) badges.add(strings.isPortuguese ? 'Seu voto' : 'Your pick');
    if (isPartnerPick) badges.add(strings.isPortuguese ? 'Voto do amor' : "Partner's pick");

    if (badges.isEmpty) return null;
    return Text(
      badges.join(' • '),
      style: const TextStyle(
        fontSize: 11,
        color: AppTheme.primaryRoseDark,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, DecideSessionModel session) {
    final strings = AppStrings.of(context);
    if (session.isMatch) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryRose.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          strings.isPortuguese ? 'Combinação! 🎉' : 'Match! 🎉',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryRose,
          ),
        ),
      );
    }
    if (session.isSplit) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.goldAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          strings.isPortuguese ? 'Empate ⚖️' : 'Split Vote ⚖️',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB57C00),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBlush.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        strings.isPortuguese ? 'Aberta 🗳️' : 'Open 🗳️',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryRoseDark,
        ),
      ),
    );
  }

  Widget _buildMatchBanner(BuildContext context, DecideSessionModel session) {
    final strings = AppStrings.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryRose, AppTheme.secondaryBlush],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRose.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.isPortuguese ? 'Deu Match! ❤️' : "It's a Match! ❤️",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  strings.isPortuguese
                      ? 'Ambos escolheram: "${session.winningOption}"'
                      : 'Both picked: "${session.winningOption}"',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitBanner(
    BuildContext context,
    WidgetRef ref,
    DecideSessionModel session,
  ) {
    final strings = AppStrings.of(context);
    final hasWinner = session.winningOption != null;

    final bannerBg = context.isDarkMode ? const Color(0xFF332A15) : const Color(0xFFFFF8E7);
    final textColor = context.isDarkMode ? AppTheme.goldAccent : const Color(0xFF8A5A00);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldAccent.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚖️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.isPortuguese ? 'Votação Empatada!' : 'Split Decision!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    Text(
                      hasWinner
                          ? (strings.isPortuguese
                              ? 'Cara ou coroa decidiu: "${session.winningOption}" 🏆'
                              : 'Coin toss decided: "${session.winningOption}" 🏆')
                          : (strings.isPortuguese
                              ? 'Vocês escolheram opções diferentes.'
                              : 'You and your partner picked different options.'),
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!hasWinner) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldAccent,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.monetization_on_rounded, size: 16),
                    label: Text(
                      strings.isPortuguese ? 'Tirar Moeda 🪙' : 'Flip Coin 🪙',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _openCoinTossDialog(context, ref, session),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: textColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      strings.isPortuguese ? 'Votar Novamente 🔄' : 'Re-vote 🔄',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      ref
                          .read(decideRepositoryProvider)
                          .resetSessionForRevote(coupleId, session.id);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpenBallotFooter(BuildContext context, DecideSessionModel session) {
    final strings = AppStrings.of(context);
    final hasVoted = session.hasUserVoted(myUid);
    final partnerHasVoted = session.votes.keys.any((uid) => uid != myUid);

    String message;
    IconData icon;
    Color iconColor;

    if (!hasVoted) {
      if (partnerHasVoted) {
        message = strings.isPortuguese
            ? 'Seu parceiro já votou! Dê o seu voto para revelar o resultado 🤫'
            : 'Partner has already voted! Cast your vote to see the result 🤫';
        icon = Icons.lock_clock_rounded;
        iconColor = AppTheme.goldAccent;
      } else {
        message = strings.isPortuguese
            ? 'Nenhum de vocês votou ainda. Dê o seu voto! 🗳️'
            : 'Neither of you has voted yet. Cast your pick! 🗳️';
        icon = Icons.how_to_vote_rounded;
        iconColor = AppTheme.primaryRose;
      }
    } else {
      message = strings.isPortuguese
          ? 'Você já votou! Aguardando o voto do seu parceiro 🔒 (sigilo)'
          : 'You voted! Waiting for your partner to vote 🔒 (secret)';
      icon = Icons.hourglass_top_rounded;
      iconColor = AppTheme.primaryRose;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  void _openCoinTossDialog(
    BuildContext context,
    WidgetRef ref,
    DecideSessionModel session,
  ) {
    final votesList = session.votes.values.toList();
    if (votesList.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => _CoinTossDialog(
        options: votesList,
        onAcceptWinner: (winner) {
          ref.read(decideRepositoryProvider).resolveSession(
                coupleId,
                session.id,
                winningOption: winner,
              );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Excluir Votação?' : 'Delete Ballot?'),
        content: Text(
          strings.isPortuguese
              ? 'Esta votação e todos os votos registrados serão excluídos permanentemente.'
              : 'This ballot and all cast votes will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(decideRepositoryProvider).deleteSession(coupleId, session.id);
            },
            child: Text(strings.delete),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COIN TOSS INTERACTIVE DIALOG
// =============================================================================

class _CoinTossDialog extends StatefulWidget {
  final List<String> options;
  final ValueChanged<String> onAcceptWinner;

  const _CoinTossDialog({
    required this.options,
    required this.onAcceptWinner,
  });

  @override
  State<_CoinTossDialog> createState() => _CoinTossDialogState();
}

class _CoinTossDialogState extends State<_CoinTossDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  String? _selectedWinner;
  bool _isFlipping = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animController.forward(from: 0).then((_) {
      final random = Random();
      final picked = widget.options[random.nextInt(widget.options.length)];
      if (mounted) {
        setState(() {
          _isFlipping = false;
          _selectedWinner = picked;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _flipCoin() {
    setState(() {
      _isFlipping = true;
      _selectedWinner = null;
    });

    _animController.forward(from: 0).then((_) {
      final random = Random();
      final picked = widget.options[random.nextInt(widget.options.length)];
      if (mounted) {
        setState(() {
          _isFlipping = false;
          _selectedWinner = picked;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.isPortuguese ? 'Desempate Cara ou Coroa' : 'Coin Toss Tie-Breaker',
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          RotationTransition(
            turns: _animController,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFDF00), AppTheme.goldAccent, Color(0xFFC48800)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.goldAccent.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text('✨', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isFlipping)
            Text(
              strings.isPortuguese ? 'Girando a moeda...' : 'Flipping the coin...',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: context.textSecondary,
              ),
            )
          else if (_selectedWinner != null) ...[
            Text(
              strings.isPortuguese ? 'A Moeda Escolheu!' : 'The Coin Has Spoken!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryRose.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryRose),
              ),
              child: Text(
                _selectedWinner!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryRoseDark,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isFlipping ? null : _flipCoin,
          child: Text(strings.isPortuguese ? 'Girar de Novo 🪙' : 'Flip Again 🪙'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryRose,
            foregroundColor: Colors.white,
          ),
          onPressed: (_isFlipping || _selectedWinner == null)
              ? null
              : () {
                  widget.onAcceptWinner(_selectedWinner!);
                  Navigator.of(context).pop();
                },
          child: Text(strings.isPortuguese ? 'Confirmar Escolha' : 'Accept & Resolve'),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 2: DATE IDEAS (BUCKET LIST & WEEKLY PICK)
// =============================================================================

class _DateIdeasTab extends ConsumerWidget {
  final String coupleId;
  final String myUid;
  final CoupleModel? couple;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const _DateIdeasTab({
    required this.coupleId,
    required this.myUid,
    this.couple,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideasAsync = ref.watch(dateIdeasStreamProvider(coupleId));

    return ideasAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error loading date ideas: $err'),
        ),
      ),
      data: (ideas) {
        final filteredIdeas = selectedCategory == 'All'
            ? ideas
            : ideas.where((i) => i.category == selectedCategory).toList();

        DateIdeaModel? weeklyPick;
        try {
          weeklyPick = ideas.firstWhere((i) => i.isWeeklyPick);
        } catch (_) {}

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // FEATURED WEEKLY PICK BANNER
            if (weeklyPick != null) ...[
              _WeeklyPickBanner(
                idea: weeklyPick,
                coupleId: coupleId,
              ),
              const SizedBox(height: 16),
            ],

            // CATEGORY FILTER CHIPS
            _buildCategoryFilterRow(context),
            const SizedBox(height: 16),

            // IDEAS LIST
            if (filteredIdeas.isEmpty)
              _buildEmptyCategoryState(context)
            else
              ...filteredIdeas.map((idea) {
                return _DateIdeaCard(
                  idea: idea,
                  coupleId: coupleId,
                );
              }),
          ],
        );
      },
    );
  }

  static String getCategoryLabel(String category, AppStrings strings) {
    if (!strings.isPortuguese) return category;
    switch (category) {
      case 'All':
        return 'Todos';
      case DateIdeaModel.categoryCozy:
        return 'Aconchegante';
      case DateIdeaModel.categoryOutdoor:
        return 'Ao Ar Livre';
      case DateIdeaModel.categoryFoodie:
        return 'Gastronômico';
      case DateIdeaModel.categoryRomance:
        return 'Romântico';
      case DateIdeaModel.categoryAdventurous:
        return 'Aventura';
      case DateIdeaModel.categoryBudget:
        return 'Econômico';
      default:
        return category;
    }
  }

  Widget _buildCategoryFilterRow(BuildContext context) {
    final strings = AppStrings.of(context);
    final categories = ['All', ...DateIdeaModel.allCategories];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(getCategoryLabel(cat, strings)),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: AppTheme.primaryRose.withOpacity(0.18),
              backgroundColor: context.surfaceVariant,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryRoseDark : context.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryRose : context.outlineColor,
              ),
              onSelected: (_) => onCategorySelected(cat),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyCategoryState(BuildContext context) {
    final strings = AppStrings.of(context);
    final displayCategory = getCategoryLabel(selectedCategory, strings);

    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 48,
            color: AppTheme.primaryRose.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            strings.isPortuguese
                ? 'Nenhuma ideia em "$displayCategory"'
                : 'No date ideas in "$selectedCategory"',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.isPortuguese
                ? 'Toque no botão abaixo para adicionar a primeira ideia para esta categoria!'
                : 'Tap the button below to add your first date idea for this category!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyPickBanner extends ConsumerWidget {
  final DateIdeaModel idea;
  final String coupleId;

  const _WeeklyPickBanner({
    required this.idea,
    required this.coupleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryRose, AppTheme.secondaryBlush],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRose.withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: AppTheme.goldAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      strings.isPortuguese ? 'DESTAQUE DA SEMANA' : 'FEATURED WEEKLY PICK',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildCategoryPill(idea.category, strings, isWhiteBg: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            idea.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          if (idea.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              idea.description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryRoseDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  idea.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                ),
                label: Text(
                  idea.isCompleted
                      ? (strings.isPortuguese ? 'Concluído! ❤️' : 'Completed! ❤️')
                      : (strings.isPortuguese ? 'Marcar como Feito' : 'Mark Completed'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  ref
                      .read(dateIdeasRepositoryProvider)
                      .toggleIdeaCompleted(coupleId, idea.id, !idea.isCompleted);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String category, AppStrings strings, {bool isWhiteBg = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isWhiteBg ? Colors.white.withOpacity(0.2) : Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _DateIdeasTab.getCategoryLabel(category, strings),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DateIdeaCard extends ConsumerWidget {
  final DateIdeaModel idea;
  final String coupleId;

  const _DateIdeaCard({
    required this.idea,
    required this.coupleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final catColor = _getCategoryColor(idea.category);
    final catIcon = _getCategoryIcon(idea.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: idea.isWeeklyPick
              ? AppTheme.primaryRose.withOpacity(0.6)
              : context.outlineColor,
          width: idea.isWeeklyPick ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          ref
              .read(dateIdeasRepositoryProvider)
              .toggleIdeaCompleted(coupleId, idea.id, !idea.isCompleted);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Checkbox(
                value: idea.isCompleted,
                activeColor: AppTheme.primaryRose,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                onChanged: (val) {
                  ref
                      .read(dateIdeasRepositoryProvider)
                      .toggleIdeaCompleted(coupleId, idea.id, val ?? false);
                },
              ),
              const SizedBox(width: 8),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(catIcon, size: 12, color: catColor),
                              const SizedBox(width: 4),
                              Text(
                                _DateIdeasTab.getCategoryLabel(idea.category, strings),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: catColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (idea.isWeeklyPick) ...[
                          const SizedBox(width: 6),
                          Text(
                            strings.isPortuguese ? '⭐ Destaque da Semana' : '⭐ Weekly Pick',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryRoseDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      idea.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: idea.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: idea.isCompleted
                            ? context.textSecondary
                            : context.textPrimary,
                      ),
                    ),
                    if (idea.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        idea.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                          decoration: idea.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        ),
                      ),
                    ],
                    if (idea.isCompleted && idea.completedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        strings.isPortuguese
                            ? 'Concluído em ${DateFormat.MMMd('pt_BR').format(idea.completedAt!)} ❤️'
                            : 'Completed on ${DateFormat.MMMd().format(idea.completedAt!)} ❤️',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions (Star as weekly pick & Delete)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      idea.isWeeklyPick
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: idea.isWeeklyPick
                          ? AppTheme.goldAccent
                          : context.textSecondary,
                    ),
                    tooltip: idea.isWeeklyPick
                        ? (strings.isPortuguese ? 'Remover dos Destaques' : 'Remove from Weekly Pick')
                        : (strings.isPortuguese ? 'Definir como Destaque da Semana' : 'Set as Weekly Pick'),
                    onPressed: () {
                      if (idea.isWeeklyPick) {
                        ref
                            .read(dateIdeasRepositoryProvider)
                            .unsetWeeklyPick(coupleId, idea.id);
                      } else {
                        ref
                            .read(dateIdeasRepositoryProvider)
                            .setWeeklyPick(coupleId, idea.id);
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (val) {
                      if (val == 'delete') {
                        _confirmDeleteIdea(context, ref);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded,
                                size: 18, color: AppTheme.errorRed),
                            const SizedBox(width: 8),
                            Text(strings.delete,
                                style: const TextStyle(color: AppTheme.errorRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteIdea(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Excluir Ideia de Encontro?' : 'Delete Date Idea?'),
        content: Text(
          strings.isPortuguese
              ? 'Tem certeza de que deseja excluir "${idea.title}"?'
              : 'Are you sure you want to delete "${idea.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(dateIdeasRepositoryProvider).deleteIdea(coupleId, idea.id);
            },
            child: Text(strings.delete),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case DateIdeaModel.categoryCozy:
        return const Color(0xFFD97706);
      case DateIdeaModel.categoryOutdoor:
        return const Color(0xFF059669);
      case DateIdeaModel.categoryFoodie:
        return const Color(0xFFDC2626);
      case DateIdeaModel.categoryRomance:
        return AppTheme.primaryRose;
      case DateIdeaModel.categoryAdventurous:
        return const Color(0xFF2563EB);
      case DateIdeaModel.categoryBudget:
        return const Color(0xFF7C3AED);
      default:
        return AppTheme.tertiaryMauve;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case DateIdeaModel.categoryCozy:
        return Icons.weekend_rounded;
      case DateIdeaModel.categoryOutdoor:
        return Icons.park_rounded;
      case DateIdeaModel.categoryFoodie:
        return Icons.restaurant_rounded;
      case DateIdeaModel.categoryRomance:
        return Icons.favorite_rounded;
      case DateIdeaModel.categoryAdventurous:
        return Icons.explore_rounded;
      case DateIdeaModel.categoryBudget:
        return Icons.savings_rounded;
      default:
        return Icons.lightbulb_rounded;
    }
  }
}

// =============================================================================
// CREATE BALLOT BOTTOM SHEET
// =============================================================================

class _CreateBallotBottomSheet extends ConsumerStatefulWidget {
  final String coupleId;
  final String myUid;

  const _CreateBallotBottomSheet({
    required this.coupleId,
    required this.myUid,
  });

  @override
  ConsumerState<_CreateBallotBottomSheet> createState() =>
      _CreateBallotBottomSheetState();
}

class _CreateBallotBottomSheetState
    extends ConsumerState<_CreateBallotBottomSheet> {
  final _titleController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyTemplate(String title, List<String> options) {
    setState(() {
      _titleController.text = title;
      while (_optionControllers.length < options.length) {
        _optionControllers.add(TextEditingController());
      }
      while (_optionControllers.length > options.length) {
        _optionControllers.removeLast().dispose();
      }
      for (int i = 0; i < options.length; i++) {
        _optionControllers[i].text = options[i];
      }
    });
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    final strings = AppStrings.of(context);
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isPortuguese
                ? 'Por favor, digite a pergunta ou título da votação'
                : 'Please enter a ballot question or title',
          ),
        ),
      );
      return;
    }

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isPortuguese
                ? 'Por favor, informe pelo menos 2 opções válidas'
                : 'Please provide at least 2 valid options',
          ),
        ),
      );
      return;
    }

    final session = DecideSessionModel(
      id: '',
      title: title,
      options: options,
      createdBy: widget.myUid,
    );

    try {
      await ref.read(decideRepositoryProvider).createSession(widget.coupleId, session);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.isPortuguese ? 'Erro ao criar votação: $e' : 'Failed to create ballot: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.outlineColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.isPortuguese ? 'Criar Votação 🗳️' : 'Create Decision Ballot 🗳️',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              strings.isPortuguese
                  ? 'Os votos permanecem em sigilo até que ambos escolham.'
                  : 'Votes remain secret until both of you make your selection.',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 16),

            // Templates
            Text(
              strings.isPortuguese ? 'Modelos Rápidos:' : 'Quick Templates:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: strings.isPortuguese
                    ? [
                        _buildTemplateChip(
                          'Jantar Hoje? 🍕',
                          'O que jantar hoje?',
                          ['Sushi 🍣', 'Pizza 🍕', 'Hambúrguer 🍔'],
                        ),
                        _buildTemplateChip(
                          'Filme da Noite 🍿',
                          'Qual filme assistir hoje?',
                          ['Comédia 😂', 'Terror 👻', 'Romance 💕'],
                        ),
                        _buildTemplateChip(
                          'Fim de Semana 🌲',
                          'Plano para o fim de semana?',
                          ['Ficar em Casa 🛋️', 'Praia 🏖️', 'Passeio na Cidade 🏙️'],
                        ),
                      ]
                    : [
                        _buildTemplateChip(
                          'Dinner Tonight? 🍕',
                          'Dinner Tonight?',
                          ['Sushi 🍣', 'Pizza 🍕', 'Burgers 🍔'],
                        ),
                        _buildTemplateChip(
                          'Movie Genre 🍿',
                          'What Movie Tonight?',
                          ['Comedy 😂', 'Horror 👻', 'Romance 💕'],
                        ),
                        _buildTemplateChip(
                          'Weekend Plan 🌲',
                          'Weekend Adventure?',
                          ['Stay In Cozy 🛋️', 'Beach Day 🏖️', 'Explore City 🏙️'],
                        ),
                      ],
              ),
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: strings.isPortuguese
                    ? 'Pergunta ou Título da Decisão'
                    : 'Question or Decision Title',
                hintText: strings.isPortuguese
                    ? 'ex: Qual filme devemos assistir?'
                    : 'e.g. Which movie should we watch?',
                filled: true,
                fillColor: context.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Options
            Text(
              strings.isPortuguese ? 'Opções (no mínimo 2):' : 'Options (At least 2):',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(_optionControllers.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[i],
                        decoration: InputDecoration(
                          labelText: strings.isPortuguese ? 'Opção ${i + 1}' : 'Option ${i + 1}',
                          filled: true,
                          fillColor: context.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppTheme.errorRed),
                        onPressed: () => _removeOption(i),
                      ),
                  ],
                ),
              );
            }),

            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add_rounded, color: AppTheme.primaryRose),
              label: Text(
                strings.isPortuguese ? 'Adicionar Outra Opção' : 'Add Another Option',
                style: const TextStyle(color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 16),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  strings.isPortuguese ? 'Criar Votação' : 'Create Ballot',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateChip(
    String label,
    String title,
    List<String> options,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: AppTheme.pastelPeach.withOpacity(0.5),
        side: BorderSide(color: AppTheme.secondaryBlush.withOpacity(0.6)),
        onPressed: () => _applyTemplate(title, options),
      ),
    );
  }
}

// =============================================================================
// ADD DATE IDEA BOTTOM SHEET
// =============================================================================

class _AddDateIdeaBottomSheet extends ConsumerStatefulWidget {
  final String coupleId;
  final String myUid;

  const _AddDateIdeaBottomSheet({
    required this.coupleId,
    required this.myUid,
  });

  @override
  ConsumerState<_AddDateIdeaBottomSheet> createState() =>
      _AddDateIdeaBottomSheetState();
}

class _AddDateIdeaBottomSheetState
    extends ConsumerState<_AddDateIdeaBottomSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = DateIdeaModel.categoryCozy;
  bool _isWeeklyPick = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final strings = AppStrings.of(context);
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isPortuguese ? 'Por favor, digite o título da ideia' : 'Please enter an idea title',
          ),
        ),
      );
      return;
    }

    final idea = DateIdeaModel(
      id: '',
      title: title,
      description: _descController.text.trim(),
      category: _selectedCategory,
      isWeeklyPick: _isWeeklyPick,
      createdBy: widget.myUid,
    );

    try {
      await ref.read(dateIdeasRepositoryProvider).addIdea(widget.coupleId, idea);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.isPortuguese ? 'Erro ao adicionar ideia: $e' : 'Failed to add date idea: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.outlineColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.isPortuguese
                  ? 'Adicionar Ideia de Encontro 💡'
                  : 'Add Date Idea to Bucket List 💡',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Título do Encontro' : 'Date Title',
                hintText: strings.isPortuguese
                    ? 'ex: Fazer massa artesanal juntos'
                    : 'e.g. Cooking Pasta from Scratch',
                filled: true,
                fillColor: context.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Descrição (Opcional)' : 'Description (Optional)',
                hintText: strings.isPortuguese
                    ? 'Comprar um bom vinho, colocar jazz...'
                    : 'Bring wine, turn on jazz music...',
                filled: true,
                fillColor: context.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            Text(
              strings.isPortuguese ? 'Categoria:' : 'Category:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: DateIdeaModel.allCategories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(_DateIdeasTab.getCategoryLabel(cat, strings)),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryRose.withOpacity(0.2),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Weekly pick toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                strings.isPortuguese ? 'Definir como Destaque da Semana ⭐' : 'Set as This Week\'s Pick ⭐',
              ),
              subtitle: Text(
                strings.isPortuguese
                    ? 'Exibir esta ideia em destaque no topo'
                    : 'Feature this idea prominently at the top',
              ),
              activeColor: AppTheme.primaryRose,
              value: _isWeeklyPick,
              onChanged: (val) => setState(() => _isWeeklyPick = val),
            ),
            const SizedBox(height: 20),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  strings.isPortuguese ? 'Salvar Ideia de Encontro' : 'Save Date Idea',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
}
