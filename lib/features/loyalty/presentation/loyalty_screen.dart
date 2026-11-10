import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/loyalty/data/loyalty_repository.dart';
import 'package:couple_app/features/loyalty/domain/loyalty_coupon_model.dart';

class LoyaltyScreen extends ConsumerStatefulWidget {
  final String coupleId;

  const LoyaltyScreen({
    super.key,
    required this.coupleId,
  });

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedCategory = 'Todos';

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

  String _currentUid() {
    try {
      return ref.read(pairingRepositoryProvider).currentUserUid ?? 'local_user';
    } catch (_) {
      return 'local_user';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final couponsAsync = ref.watch(loyaltyCouponsStreamProvider(widget.coupleId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.hubLoyaltyTitle),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppTheme.primaryRose,
          tabs: const [
            Tab(
              icon: Icon(Icons.confirmation_number_rounded, size: 20),
              text: 'Cupons de Amor',
            ),
            Tab(
              icon: Icon(Icons.card_membership_rounded, size: 20),
              text: 'Cartões & Vales',
            ),
          ],
        ),
      ),
      body: couponsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRose),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Erro ao carregar cupons: $err',
              style: TextStyle(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (allItems) {
          final loveCoupons =
              allItems.where((c) => !c.isLoyaltyCard).toList();
          final loyaltyCards =
              allItems.where((c) => c.isLoyaltyCard).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLoveCouponsTab(context, loveCoupons),
              _buildLoyaltyCardsTab(context, loyaltyCards),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          if (_tabController.index == 0) {
            _showAddCouponSheet(context, isLoyaltyCard: false);
          } else {
            _showAddCouponSheet(context, isLoyaltyCard: true);
          }
        },
        backgroundColor: AppTheme.primaryRose,
        foregroundColor: Colors.white,
        icon: Icon(
          _tabController.index == 0
              ? Icons.add_reaction_rounded
              : Icons.add_card_rounded,
        ),
        label: Text(
          _tabController.index == 0 ? 'Novo Cupom 💕' : 'Novo Cartão 💳',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildLoveCouponsTab(
    BuildContext context,
    List<LoyaltyCouponModel> coupons,
  ) {
    final categories = ['Todos', ...LoyaltyCouponModel.couponCategories];
    final filtered = _selectedCategory == 'Todos'
        ? coupons
        : coupons.where((c) => c.category == _selectedCategory).toList();

    final availableCount = coupons.where((c) => c.canRedeem).length;
    final totalRedeemed =
        coupons.fold<int>(0, (sum, item) => sum + item.usedCount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Hero Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: context.isDarkMode
                  ? [const Color(0xFF3A1525), const Color(0xFF23121E)]
                  : [const Color(0xFFFFE5EC), const Color(0xFFF3E8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.primaryRose.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRose.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: const Text('🎟️', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mimos & Vales do Casal',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$availableCount cupons disponíveis • $totalRedeemed resgates realizados 💕',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Category Filter Chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              final selected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: AppTheme.primaryRose,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : context.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Text(
              'Nenhum cupom nesta categoria ainda.',
              style: TextStyle(color: context.textSecondary),
            ),
          )
        else
          ...filtered.map((coupon) => _buildCouponTicketCard(context, coupon)),
      ],
    );
  }

  Widget _buildCouponTicketCard(
    BuildContext context,
    LoyaltyCouponModel coupon,
  ) {
    final isExhausted = coupon.isExhausted;
    final dateFmt = DateFormat("d 'de' MMM, HH:mm", 'pt_BR');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isExhausted
              ? context.outlineColor
              : AppTheme.primaryRose.withValues(alpha: 0.35),
          width: isExhausted ? 1.0 : 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isExhausted
                        ? context.surfaceVariant
                        : AppTheme.primaryRose.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    coupon.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryPlum
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              coupon.category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.secondaryPlum,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isExhausted
                                  ? context.surfaceVariant
                                  : const Color(0xFF10B981)
                                      .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isExhausted
                                  ? 'Esgotado'
                                  : 'Restam ${coupon.remainingUses}/${coupon.maxUses}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isExhausted
                                    ? context.textSecondary
                                    : const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        coupon.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isExhausted
                                  ? context.textSecondary
                                  : context.textPrimary,
                              decoration: isExhausted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        coupon.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.textSecondary,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: context.outlineColor, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (coupon.lastRedeemedAt != null)
                  Expanded(
                    child: Text(
                      'Último resgate: ${dateFmt.format(coupon.lastRedeemedAt!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      'Pronto para usar com seu amor 💕',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (isExhausted)
                  TextButton.icon(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await ref
                          .read(loyaltyRepositoryProvider)
                          .refillCoupon(widget.coupleId, coupon.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cupom "${coupon.title}" recarregado! 🎟️✨',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Recarregar'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await ref.read(loyaltyRepositoryProvider).redeemCoupon(
                            widget.coupleId,
                            coupon,
                            _currentUid(),
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '🎉 Você resgatou "${coupon.title}"! Avise seu amor 💕',
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryRose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.redeem_rounded, size: 16),
                    label: const Text(
                      'Resgatar Vale',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                IconButton(
                  tooltip: 'Excluir cupom',
                  onPressed: () async {
                    await ref
                        .read(loyaltyRepositoryProvider)
                        .deleteCoupon(widget.coupleId, coupon.id);
                  },
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCardsTab(
    BuildContext context,
    List<LoyaltyCouponModel> cards,
  ) {
    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💳', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 14),
              Text(
                'Carteira de Fidelidade & Vale-Presentes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Guarde cartões fidelidade de restaurantes, cinemas, mercados ou códigos de vale-presente compartilhados pelo casal.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.outlineColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(card.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                        ),
                        if ((card.storeName ?? '').isNotEmpty)
                          Text(
                            card.storeName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await ref
                          .read(loyaltyRepositoryProvider)
                          .deleteCoupon(widget.coupleId, card.id);
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
              if (card.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  card.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                  ),
                ),
              ],
              if ((card.cardCode ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.qr_code_rounded,
                        size: 20,
                        color: AppTheme.primaryRose,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          card.cardCode!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar código',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: card.cardCode!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Código copiado para a área de transferência 📋',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: AppTheme.primaryRose,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAddCouponSheet(
    BuildContext context, {
    required bool isLoyaltyCard,
  }) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final storeCtrl = TextEditingController();
    String selectedCategory = LoyaltyCouponModel.categoryRomance;
    String selectedEmoji = isLoyaltyCard ? '💳' : '🎟️';
    int maxUses = 3;

    final emojis = isLoyaltyCard
        ? ['💳', '🎁', '🍕', '🍿', '🛍️', '✈️', '☕', '🏪']
        : ['🎟️', '💆', '🥐', '🎬', '🍝', '💋', '🍫', '✨', '🌹', '🛁'];

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoyaltyCard
                          ? 'Novo Cartão Fidelidade / Vale 💳'
                          : 'Criar Cupom de Amor 🎟️',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 16),
                    // Emoji selector
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: emojis.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final e = emojis[i];
                          final isSel = e == selectedEmoji;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedEmoji = e),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppTheme.primaryRose
                                        .withValues(alpha: 0.2)
                                    : context.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel
                                      ? AppTheme.primaryRose
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: isLoyaltyCard
                            ? 'Nome do Cartão ou Vale'
                            : 'Título do Cupom (ex: Vale-Massagem)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isLoyaltyCard) ...[
                      TextField(
                        controller: storeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Loja / Restaurante / Programa',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Número / Código / CPF cadastrado',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isLoyaltyCard
                            ? 'Observações (pontos, validade, benefícios)'
                            : 'Regras e detalhes do mimo 💕',
                      ),
                    ),
                    if (!isLoyaltyCard) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            'Quantidade de Usos:',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: maxUses > 1
                                ? () => setModalState(() => maxUses--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$maxUses',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setModalState(() => maxUses++),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;
                          final model = LoyaltyCouponModel(
                            id: '',
                            title: title,
                            description: descCtrl.text.trim(),
                            emoji: selectedEmoji,
                            category: isLoyaltyCard
                                ? LoyaltyCouponModel.categoryStore
                                : selectedCategory,
                            type: isLoyaltyCard
                                ? LoyaltyCouponModel.typeCard
                                : LoyaltyCouponModel.typeCoupon,
                            maxUses: isLoyaltyCard ? 999 : maxUses,
                            createdBy: _currentUid(),
                            createdAt: DateTime.now(),
                            cardCode: isLoyaltyCard
                                ? codeCtrl.text.trim()
                                : null,
                            storeName: isLoyaltyCard
                                ? storeCtrl.text.trim()
                                : null,
                          );
                          Navigator.of(ctx).pop();
                          await ref
                              .read(loyaltyRepositoryProvider)
                              .addCoupon(widget.coupleId, model);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryRose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          isLoyaltyCard
                              ? 'Salvar Cartão'
                              : 'Criar Cupom de Amor 💕',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
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
}
