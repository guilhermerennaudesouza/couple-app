import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/features/adult_games/data/adult_games_repository.dart';
import 'package:couple_app/features/adult_games/domain/adult_game_model.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';

class AdultGamesScreen extends ConsumerStatefulWidget {
  final String coupleId;

  const AdultGamesScreen({
    super.key,
    required this.coupleId,
  });

  @override
  ConsumerState<AdultGamesScreen> createState() => _AdultGamesScreenState();
}

class _AdultGamesScreenState extends ConsumerState<AdultGamesScreen> {
  static const String _kConsentPrefKey = 'adult_games_18_confirmed';

  bool _isAgeVerified = false;
  bool _loadingConsent = true;
  String _selectedLevel = AdultGameCardModel.levelGentle;
  String? _localCardId;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _loadAgeConsent();
  }

  Future<void> _loadAgeConsent() async {
    try {
      const storage = FlutterSecureStorage();
      final val = await storage.read(key: _kConsentPrefKey);
      final verified = val == 'true';
      if (mounted) {
        setState(() {
          _isAgeVerified = verified;
          _loadingConsent = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingConsent = false);
      }
    }
  }

  Future<void> _confirmAgeConsent() async {
    HapticFeedback.mediumImpact();
    setState(() => _isAgeVerified = true);
    try {
      const storage = FlutterSecureStorage();
      await storage.write(key: _kConsentPrefKey, value: 'true');
    } catch (_) {}
  }

  String _currentUid() {
    try {
      return ref.read(pairingRepositoryProvider).currentUserUid ?? 'local_user';
    } catch (_) {
      return 'local_user';
    }
  }

  Color _levelColor(String level) {
    switch (level) {
      case AdultGameCardModel.levelBold:
        return const Color(0xFFF97316); // Flame Orange
      case AdultGameCardModel.levelSpicy:
        return const Color(0xFFE11D48); // Crimson Spicy
      case AdultGameCardModel.levelGentle:
      default:
        return AppTheme.primaryRose;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    if (_loadingConsent) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.hubAdultGamesTitle)),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRose),
        ),
      );
    }

    if (!_isAgeVerified) {
      return _buildAgeVerificationScreen(context, strings);
    }

    final deckAsync = ref.watch(adultGamesDeckStreamProvider(widget.coupleId));
    final sessionAsync =
        ref.watch(adultGameSessionStreamProvider(widget.coupleId));
    final coupleAsync = ref.watch(coupleStreamProvider(widget.coupleId));

    final myUid = _currentUid();
    final myName =
        coupleAsync.valueOrNull?.getMyProfile(myUid)?.name ?? 'Seu Amor';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Jogos de Intimidade 18+ 🔥'),
        actions: [
          IconButton(
            tooltip: 'Criar Carta Personalizada',
            onPressed: () => _showAddCustomCardModal(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: deckAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRose),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Erro ao carregar o baralho íntimo: $err',
              style: TextStyle(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (allCards) {
          final session =
              sessionAsync.valueOrNull ?? const AdultGameSessionState();
          final levelCards =
              allCards.where((c) => c.level == _selectedLevel).toList();
          final completedInLevel =
              levelCards.where((c) => c.isCompleted).length;

          AdultGameCardModel? activeCard;
          final effectiveId = _localCardId ?? session.activeCardId;
          if (effectiveId != null) {
            for (final c in levelCards) {
              if (c.id == effectiveId) {
                activeCard = c;
                break;
              }
            }
          }
          activeCard ??= levelCards.isNotEmpty ? levelCards.first : null;

          final accent = _levelColor(_selectedLevel);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
            children: [
              // Partner Nudge Banner ("Convite Picante")
              if ((session.nudgeMessage ?? '').isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.2),
                        AppTheme.secondaryPlum.withValues(alpha: 0.16),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          session.nudgeMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 3 Intensity Level Selector Pills
              Row(
                children: [
                  _buildLevelTab(
                    context,
                    level: AdultGameCardModel.levelGentle,
                    label: 'Suave 💕',
                    subtitle: 'Carinho & Romântico',
                  ),
                  const SizedBox(width: 8),
                  _buildLevelTab(
                    context,
                    level: AdultGameCardModel.levelBold,
                    label: 'Ousado 🔥',
                    subtitle: 'Provocação & Desejo',
                  ),
                  const SizedBox(width: 8),
                  _buildLevelTab(
                    context,
                    level: AdultGameCardModel.levelSpicy,
                    label: 'Picante 🌶️',
                    subtitle: 'Intenso 18+',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Active Drawn Card Hero
              if (activeCard != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Container(
                    key: ValueKey(activeCard.id),
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: context.isDarkMode
                            ? [
                                accent.withValues(alpha: 0.28),
                                const Color(0xFF1A151B),
                              ]
                            : [
                                accent.withValues(alpha: 0.15),
                                Colors.white,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.5),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.14),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                activeCard.levelLabelPt.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: context.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                activeCard.cardTypeLabelPt,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          activeCard.title,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: context.textPrimary,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '“${activeCard.prompt}”',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: context.textPrimary,
                                fontSize: 17,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _drawRandomCard(levelCards),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accent,
                                  side: BorderSide(color: accent),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.casino_rounded, size: 20),
                                label: const Text(
                                  'Sortear Outra 🎲',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  await ref
                                      .read(adultGamesRepositoryProvider)
                                      .toggleCardCompleted(
                                        widget.coupleId,
                                        activeCard!,
                                      );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: activeCard.isCompleted
                                      ? const Color(0xFF10B981)
                                      : accent,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: Icon(
                                  activeCard.isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.favorite_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  activeCard.isCompleted
                                      ? 'Cumprido! ✅'
                                      : 'Concluir Desafio',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Send Spicy Nudge to Partner button
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    HapticFeedback.heavyImpact();
                    final msg =
                        '$myName está chamando você para jogar no nível ${_selectedLevel == AdultGameCardModel.levelSpicy ? 'Picante 🌶️' : _selectedLevel == AdultGameCardModel.levelBold ? 'Ousado 🔥' : 'Suave 💕'} hoje à noite!';
                    await ref
                        .read(adultGamesRepositoryProvider)
                        .sendSpicyNudge(
                          widget.coupleId,
                          senderUid: myUid,
                          senderName: myName,
                          message: msg,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '🔥 Convite enviado para o painel do seu amor!',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.local_fire_department_rounded),
                  label: const Text(
                    'Chamar Meu Amor para Jogar Hoje 🔥',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Deck Progress & All Cards in Current Level
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CARTAS DESTE NÍVEL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: context.textSecondary,
                    ),
                  ),
                  Text(
                    '$completedInLevel/${levelCards.length} concluídas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...levelCards.map(
                (card) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: card.id == activeCard?.id
                          ? accent
                          : context.outlineColor,
                    ),
                  ),
                  child: ListTile(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _localCardId = card.id);
                      ref.read(adultGamesRepositoryProvider).setActiveCard(
                            widget.coupleId,
                            cardId: card.id,
                            level: _selectedLevel,
                          );
                    },
                    leading: CircleAvatar(
                      backgroundColor: card.isCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.16)
                          : accent.withValues(alpha: 0.14),
                      child: Text(
                        card.isCompleted ? '✅' : '🔥',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    title: Text(
                      card.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      card.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLevelTab(
    BuildContext context, {
    required String level,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _selectedLevel == level;
    final color = _levelColor(level);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedLevel = level;
            _localCardId = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? color : context.outlineColor,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _drawRandomCard(List<AdultGameCardModel> cards) {
    if (cards.isEmpty) return;
    HapticFeedback.mediumImpact();
    final pool = cards.where((c) => !c.isCompleted).toList();
    final candidates = pool.isNotEmpty ? pool : cards;
    final chosen = candidates[_rng.nextInt(candidates.length)];
    setState(() => _localCardId = chosen.id);
    ref.read(adultGamesRepositoryProvider).setActiveCard(
          widget.coupleId,
          cardId: chosen.id,
          level: _selectedLevel,
        );
  }

  Widget _buildAgeVerificationScreen(BuildContext context, AppStrings strings) {
    return Scaffold(
      appBar: AppBar(title: Text(strings.hubAdultGamesTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.outlineColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌶️🔥', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'Conteúdo para Casais Adultos (18+)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Este módulo contém cartas de intimidade, perguntas ousadas e desafios sensuais em 3 níveis (Suave, Ousado e Picante) criados para fortalecer a conexão e a paixão do casal com respeito e consentimento mútuo.',
                  style: TextStyle(
                    color: context.textSecondary,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _confirmAgeConsent,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryRose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    icon: const Icon(Icons.verified_user_rounded),
                    label: const Text(
                      'Confirmar 18+ e Entrar nos Jogos 🔥',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCustomCardModal(BuildContext context) {
    final titleCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    String level = _selectedLevel;
    String cardType = AdultGameCardModel.typeDare;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 22,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nova Carta Personalizada 🔥',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Suave 💕'),
                        selected: level == AdultGameCardModel.levelGentle,
                        onSelected: (_) => setModalState(
                          () => level = AdultGameCardModel.levelGentle,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Ousado 🔥'),
                        selected: level == AdultGameCardModel.levelBold,
                        onSelected: (_) => setModalState(
                          () => level = AdultGameCardModel.levelBold,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Picante 🌶️'),
                        selected: level == AdultGameCardModel.levelSpicy,
                        onSelected: (_) => setModalState(
                          () => level = AdultGameCardModel.levelSpicy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Desafio a Dois 🔥'),
                        selected: cardType == AdultGameCardModel.typeDare,
                        onSelected: (_) => setModalState(
                          () => cardType = AdultGameCardModel.typeDare,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Confissão / Pergunta 💬'),
                        selected: cardType == AdultGameCardModel.typeQuestion,
                        onSelected: (_) => setModalState(
                          () => cardType = AdultGameCardModel.typeQuestion,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título da Carta',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição do Desafio ou Pergunta Íntima',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final prompt = promptCtrl.text.trim();
                        if (title.isEmpty || prompt.isEmpty) return;
                        Navigator.of(ctx).pop();
                        await ref
                            .read(adultGamesRepositoryProvider)
                            .addCustomCard(
                              widget.coupleId,
                              AdultGameCardModel(
                                id: '',
                                title: title,
                                prompt: prompt,
                                level: level,
                                cardType: cardType,
                                createdBy: _currentUid(),
                              ),
                            );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryRose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Adicionar ao Baralho 🔥',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
