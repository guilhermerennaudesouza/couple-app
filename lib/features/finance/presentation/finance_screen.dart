import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/pairing_repository.dart';
import '../../auth/domain/couple_model.dart';
import '../data/finance_repository.dart';
import '../domain/finance_model.dart';
import '../domain/savings_model.dart';

/// Screen managing shared couple finances, expense split calculations,
/// net balance settlement, and joint savings goals (Piggy Bank).
class FinanceScreen extends ConsumerStatefulWidget {
  final CoupleModel? initialCouple;
  final String? coupleId;
  final String? currentUid;

  const FinanceScreen({
    super.key,
    this.initialCouple,
    this.coupleId,
    this.currentUid,
  });

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategoryFilter = 'All';

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
    return user?.uid ?? 'guest_uid';
  }

  String _getUserDisplayName(CoupleModel? couple, String uid, {bool isMe = false}) {
    if (couple != null) {
      final profile = couple.partnerProfiles[uid];
      if (profile != null && profile.name.isNotEmpty) {
        return profile.name;
      }
    }
    if (isMe) {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.displayName != null && user!.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      return 'You';
    }
    return 'Partner';
  }

  @override
  Widget build(BuildContext context) {
    final currentCoupleAsync = ref.watch(currentCoupleIdProvider);
    final effectiveCoupleId = widget.coupleId ??
        currentCoupleAsync.valueOrNull ??
        widget.initialCouple?.id ??
        '';

    final coupleAsync = effectiveCoupleId.isNotEmpty
        ? ref.watch(coupleStreamProvider(effectiveCoupleId))
        : const AsyncValue<CoupleModel?>.data(null);
    final couple = coupleAsync.valueOrNull ?? widget.initialCouple;

    final myUid = _getEffectiveUid();
    final partnerUid = couple?.getOtherUid(myUid) ?? 'partner_uid';
    final myName = _getUserDisplayName(couple, myUid, isMe: true);
    final partnerName = _getUserDisplayName(couple, partnerUid, isMe: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shared Finance & Savings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryRose,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: AppTheme.textSecondaryLight,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.receipt_long_rounded),
              text: 'Shared Expenses',
            ),
            Tab(
              icon: Icon(Icons.savings_rounded),
              text: 'Savings Piggy Bank',
            ),
          ],
        ),
      ),
      body: effectiveCoupleId.isEmpty
          ? _buildNoCoupleState()
          : TabBarView(
              controller: _tabController,
              children: [
                _ExpensesTab(
                  coupleId: effectiveCoupleId,
                  myUid: myUid,
                  partnerUid: partnerUid,
                  myName: myName,
                  partnerName: partnerName,
                  selectedCategory: _selectedCategoryFilter,
                  onCategorySelected: (cat) {
                    setState(() => _selectedCategoryFilter = cat);
                  },
                ),
                _SavingsTab(
                  coupleId: effectiveCoupleId,
                  myUid: myUid,
                  myName: myName,
                  partnerName: partnerName,
                ),
              ],
            ),
      floatingActionButton: effectiveCoupleId.isEmpty
          ? null
          : _tabController.index == 0
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddExpenseSheet(
                    context,
                    effectiveCoupleId,
                    myUid,
                    partnerUid,
                    myName,
                    partnerName,
                  ),
                  backgroundColor: AppTheme.primaryRose,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Expense'),
                )
              : FloatingActionButton.extended(
                  onPressed: () => _showCreateSavingsGoalSheet(
                    context,
                    effectiveCoupleId,
                    myUid,
                  ),
                  backgroundColor: AppTheme.primaryRose,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New Goal'),
                ),
    );
  }

  Widget _buildNoCoupleState() {
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
            const Text(
              'No Couple Space Connected',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pair with your partner first to track expenses and save together!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ADD EXPENSE BOTTOM SHEET
  // ==========================================

  void _showAddExpenseSheet(
    BuildContext context,
    String coupleId,
    String myUid,
    String partnerUid,
    String myName,
    String partnerName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddExpenseModal(
        coupleId: coupleId,
        myUid: myUid,
        partnerUid: partnerUid,
        myName: myName,
        partnerName: partnerName,
      ),
    );
  }

  // ==========================================
  // CREATE SAVINGS GOAL BOTTOM SHEET
  // ==========================================

  void _showCreateSavingsGoalSheet(
    BuildContext context,
    String coupleId,
    String myUid,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateSavingsGoalModal(
        coupleId: coupleId,
        myUid: myUid,
      ),
    );
  }
}

// ============================================================================
// TAB 1: SHARED EXPENSES & BALANCE HERO
// ============================================================================

class _ExpensesTab extends ConsumerWidget {
  final String coupleId;
  final String myUid;
  final String partnerUid;
  final String myName;
  final String partnerName;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const _ExpensesTab({
    required this.coupleId,
    required this.myUid,
    required this.partnerUid,
    required this.myName,
    required this.partnerName,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(financeEntriesStreamProvider(coupleId));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading expenses: $err')),
      data: (entries) {
        final balance = calculateNetOwed(entries, user1: myUid, user2: partnerUid);

        final filteredEntries = selectedCategory == 'All'
            ? entries
            : entries.where((e) => e.category == selectedCategory).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(financeEntriesStreamProvider(coupleId));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildNetBalanceHeroCard(context, ref, balance),
              const SizedBox(height: 16),
              _buildCategoryChips(),
              const SizedBox(height: 12),
              if (filteredEntries.isEmpty)
                _buildEmptyExpensesState()
              else
                ...filteredEntries.map(
                  (entry) => _buildExpenseCard(context, ref, entry),
                ),
              const SizedBox(height: 80), // Fab padding
            ],
          ),
        );
      },
    );
  }

  Widget _buildNetBalanceHeroCard(
    BuildContext context,
    WidgetRef ref,
    BalanceSummary balance,
  ) {
    final isSettled = balance.isSettledUp;
    final iAmOwed = balance.netOwedToUser1 > 0.001;
    final iOwe = balance.netOwedToUser2 > 0.001;

    Color cardBg;
    Color borderColor;
    String title;
    String subtitle;
    Widget statusIcon;

    if (isSettled) {
      cardBg = const Color(0xFFF3FAF4);
      borderColor = const Color(0xFFC8E6C9);
      title = 'All settled up! 🎉';
      subtitle = 'No pending balances between you and $partnerName.';
      statusIcon = const Icon(
        Icons.check_circle_rounded,
        color: AppTheme.successGreen,
        size: 32,
      );
    } else if (iAmOwed) {
      cardBg = const Color(0xFFF1F8E9);
      borderColor = const Color(0xFFAED581);
      title = 'You are owed \$${balance.netOwedToUser1.toStringAsFixed(2)} 💚';
      subtitle = '$partnerName owes you for shared expenses.';
      statusIcon = const Icon(
        Icons.arrow_downward_rounded,
        color: AppTheme.successGreen,
        size: 32,
      );
    } else {
      cardBg = const Color(0xFFFFF3E0);
      borderColor = const Color(0xFFFFCC80);
      title = 'You owe \$${balance.netOwedToUser2.toStringAsFixed(2)} 🧡';
      subtitle = 'You owe $partnerName for shared expenses.';
      statusIcon = const Icon(
        Icons.arrow_upward_rounded,
        color: Color(0xFFF57C00),
        size: 32,
      );
    }

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                statusIcon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unsettled Total: \$${balance.totalSpent.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                    Text(
                      '${balance.unsettledCount} open item(s)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                if (!isSettled)
                  FilledButton.tonalIcon(
                    onPressed: () => _confirmSettleUp(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryRose,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.handshake_rounded, size: 18),
                    label: const Text(
                      'Settle Up',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSettleUp(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.dialogBorderRadius),
        ),
        title: const Row(
          children: [
            Icon(Icons.handshake_rounded, color: AppTheme.primaryRose),
            SizedBox(width: 8),
            Text('Settle Up Balance?'),
          ],
        ),
        content: Text(
          'Mark all pending shared expenses as settled? This will reset the net balance between you and $partnerName to \$0.00.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(financeRepositoryProvider)
                    .settleAllBalances(coupleId, settledByUid: myUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All balances settled up! Clean slate 🎉'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to settle balances: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryRose,
            ),
            child: const Text('Settle Up'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['All', ...FinanceEntry.categories];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selectedCategory;
          return FilterChip(
            selected: isSelected,
            label: Text(cat),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppTheme.textPrimaryLight,
            ),
            selectedColor: AppTheme.primaryRose,
            backgroundColor: AppTheme.surfaceVariantLight,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryRose : AppTheme.outlineLight,
              ),
            ),
            onSelected: (_) => onCategorySelected(cat),
          );
        },
      ),
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    WidgetRef ref,
    FinanceEntry entry,
  ) {
    final isPaidByMe = entry.paidBy == myUid;
    final payerDisplayName = isPaidByMe ? 'You' : partnerName;
    final dateStr = DateFormat('MMM d, y').format(entry.date);
    final myShare = entry.shareFor(myUid, partnerUid: partnerUid);
    final partnerShare = entry.shareFor(partnerUid, partnerUid: myUid);

    String splitBadgeText;
    switch (entry.splitRatio) {
      case SplitRatio.half:
        splitBadgeText = '50/50';
        break;
      case SplitRatio.paidByOther:
        splitBadgeText = isPaidByMe ? '100% $partnerName owes' : '100% you owe';
        break;
      case SplitRatio.custom:
        final payerPct = entry.customSplitPercentage ?? 50.0;
        splitBadgeText = isPaidByMe
            ? '${payerPct.round()}% / ${(100 - payerPct).round()}%'
            : '${(100 - payerPct).round()}% / ${payerPct.round()}%';
        break;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: entry.isSettled ? const Color(0xFFFBFBFB) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: entry.isSettled ? const Color(0xFFECECEC) : AppTheme.outlineLight,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(entry.category).withOpacity(0.15),
          child: Icon(
            _getCategoryIcon(entry.category),
            color: _getCategoryColor(entry.category),
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  decoration: entry.isSettled ? TextDecoration.lineThrough : null,
                  color: entry.isSettled
                      ? AppTheme.textSecondaryLight
                      : AppTheme.textPrimaryLight,
                ),
              ),
            ),
            Text(
              '\$${entry.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: entry.isSettled
                    ? AppTheme.textSecondaryLight
                    : AppTheme.textPrimaryLight,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$dateStr • Paid by $payerDisplayName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (entry.isSettled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Settled',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  )
                else
                  Text(
                    isPaidByMe
                        ? '+$partnerName owes \$${partnerShare.toStringAsFixed(2)}'
                        : 'You owe \$${myShare.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPaidByMe
                          ? AppTheme.successGreen
                          : const Color(0xFFF57C00),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Split: $splitBadgeText',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 20),
          onSelected: (action) {
            if (action == 'delete') {
              _confirmDeleteExpense(context, ref, entry);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(
    BuildContext context,
    WidgetRef ref,
    FinanceEntry entry,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to remove "${entry.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(financeRepositoryProvider)
                    .deleteExpense(coupleId, entry.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete expense: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyExpensesState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppTheme.primaryRose.withOpacity(0.35),
            ),
            const SizedBox(height: 12),
            const Text(
              'No expenses recorded',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ Add Expense" to log dinners, groceries, or vacations together!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    return switch (category) {
      'Dining' => Icons.restaurant_rounded,
      'Groceries' => Icons.shopping_cart_rounded,
      'Travel' => Icons.flight_takeoff_rounded,
      'Home' => Icons.home_rounded,
      'Entertainment' => Icons.movie_rounded,
      'Utilities' => Icons.bolt_rounded,
      _ => Icons.receipt_long_rounded,
    };
  }

  Color _getCategoryColor(String category) {
    return switch (category) {
      'Dining' => const Color(0xFFFF7043),
      'Groceries' => const Color(0xFF66BB6A),
      'Travel' => const Color(0xFF42A5F5),
      'Home' => const Color(0xFFAB47BC),
      'Entertainment' => const Color(0xFFEC407A),
      'Utilities' => const Color(0xFFFFA726),
      _ => const Color(0xFF78909C),
    };
  }
}

// ============================================================================
// TAB 2: JOINT SAVINGS GOALS (PIGGY BANK)
// ============================================================================

class _SavingsTab extends ConsumerWidget {
  final String coupleId;
  final String myUid;
  final String myName;
  final String partnerName;

  const _SavingsTab({
    required this.coupleId,
    required this.myUid,
    required this.myName,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsStreamProvider(coupleId));

    return goalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading goals: $err')),
      data: (goals) {
        final totalSaved = goals.fold<double>(
          0.0,
          (sum, goal) => sum + goal.currentAmount,
        );

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(savingsGoalsStreamProvider(coupleId));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildTotalSavingsHeroCard(totalSaved, goals.length),
              const SizedBox(height: 16),
              if (goals.isEmpty)
                _buildEmptySavingsState()
              else
                ...goals.map((goal) => _buildSavingsGoalCard(context, ref, goal)),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalSavingsHeroCard(double totalSaved, int goalCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF8A9E),
            AppTheme.primaryRose,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRose.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Joint Piggy Bank Total',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${totalSaved.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saving together across $goalCount shared dream(s) ✨',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalCard(
    BuildContext context,
    WidgetRef ref,
    SavingsGoalModel goal,
  ) {
    final isReached = goal.isTargetReached || goal.isCompleted;
    final progress = goal.progressRatio;
    final pct = goal.progressPercentage;

    String countdownText = '';
    if (goal.targetDate != null) {
      final daysLeft = goal.targetDate!.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        countdownText = 'Target date passed';
      } else if (daysLeft == 0) {
        countdownText = 'Target date is today!';
      } else {
        countdownText = '$daysLeft days left (${DateFormat.yMMMd().format(goal.targetDate!)})';
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        side: BorderSide(
          color: isReached ? const Color(0xFFFFD54F) : AppTheme.outlineLight,
          width: isReached ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Category, Title, Celebration Badge, Popup Menu
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getSavingsCategoryColor(goal.category).withOpacity(0.15),
                  radius: 18,
                  child: Icon(
                    _getSavingsCategoryIcon(goal.category),
                    color: _getSavingsCategoryColor(goal.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryLight,
                        ),
                      ),
                      Text(
                        goal.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isReached)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD54F)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🎉 ', style: TextStyle(fontSize: 12)),
                        Text(
                          'Goal Reached!',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF57F17),
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (action) {
                    if (action == 'delete') {
                      _confirmDeleteGoal(context, ref, goal);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: AppTheme.errorRed, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Goal',
                              style: TextStyle(color: AppTheme.errorRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: AppTheme.surfaceVariantLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isReached ? AppTheme.successGreen : AppTheme.primaryRose,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Metrics row: $current of $target (pct%) and remaining
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${goal.currentAmount.toStringAsFixed(2)} of \$${goal.targetAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isReached ? AppTheme.successGreen : AppTheme.primaryRose)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isReached ? AppTheme.successGreen : AppTheme.primaryRose,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isReached
                        ? 'Target completely fulfilled! 🥳'
                        : '\$${goal.remainingAmount.toStringAsFixed(2)} remaining',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isReached
                          ? AppTheme.successGreen
                          : AppTheme.textSecondaryLight,
                      fontWeight: isReached ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (countdownText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    countdownText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Contribute Action & Recent History
            Row(
              children: [
                if (goal.contributions.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showContributionsHistory(context, goal),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: Text(
                      '${goal.contributions.length} deposit(s)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showContributeModal(context, ref, goal),
                  style: FilledButton.styleFrom(
                    backgroundColor: isReached
                        ? AppTheme.successGreen
                        : AppTheme.primaryRose,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Contribute'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showContributeModal(
    BuildContext context,
    WidgetRef ref,
    SavingsGoalModel goal,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContributeModal(
        coupleId: coupleId,
        goal: goal,
        myUid: myUid,
        partnerName: partnerName,
      ),
    );
  }

  void _showContributionsHistory(
    BuildContext context,
    SavingsGoalModel goal,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final reversedContribs = goal.contributions.reversed.toList();
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppTheme.primaryRose),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${goal.title} Deposits',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: reversedContribs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contrib = reversedContribs[index];
                    final dateStr = DateFormat.yMMMd().format(contrib.date);
                    final isMe = contrib.uid == myUid;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryRose.withOpacity(0.12),
                        radius: 16,
                        child: Text(
                          isMe ? 'Me' : 'P',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryRose,
                          ),
                        ),
                      ),
                      title: Text(
                        '+\$${contrib.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      subtitle: contrib.note != null && contrib.note!.isNotEmpty
                          ? Text(
                              '${contrib.note!} • $dateStr',
                              style: const TextStyle(fontSize: 12),
                            )
                          : Text(dateStr, style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteGoal(
    BuildContext context,
    WidgetRef ref,
    SavingsGoalModel goal,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Savings Goal?'),
        content: Text(
          'Are you sure you want to delete "${goal.title}"? Current progress (\$${goal.currentAmount.toStringAsFixed(2)}) will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(financeRepositoryProvider)
                    .deleteSavingsGoal(coupleId, goal.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete savings goal: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySavingsState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.savings_outlined,
              size: 56,
              color: AppTheme.primaryRose.withOpacity(0.35),
            ),
            const SizedBox(height: 12),
            const Text(
              'No savings goals yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Start a joint piggy bank for your next vacation, wedding, or home dream!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSavingsCategoryIcon(String category) {
    return switch (category) {
      'Vacation' => Icons.flight_takeoff_rounded,
      'Wedding' => Icons.favorite_rounded,
      'Home' => Icons.home_rounded,
      'Emergency' => Icons.shield_rounded,
      'Date Night' => Icons.local_dining_rounded,
      'Vehicle' => Icons.directions_car_rounded,
      _ => Icons.savings_rounded,
    };
  }

  Color _getSavingsCategoryColor(String category) {
    return switch (category) {
      'Vacation' => const Color(0xFF00ACC1),
      'Wedding' => AppTheme.primaryRose,
      'Home' => const Color(0xFF8E24AA),
      'Emergency' => const Color(0xFF43A047),
      'Date Night' => const Color(0xFFFB8C00),
      'Vehicle' => const Color(0xFF3949AB),
      _ => const Color(0xFF5E35B1),
    };
  }
}

// ============================================================================
// MODAL: ADD EXPENSE SHEET
// ============================================================================

class _AddExpenseModal extends ConsumerStatefulWidget {
  final String coupleId;
  final String myUid;
  final String partnerUid;
  final String myName;
  final String partnerName;

  const _AddExpenseModal({
    required this.coupleId,
    required this.myUid,
    required this.partnerUid,
    required this.myName,
    required this.partnerName,
  });

  @override
  ConsumerState<_AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends ConsumerState<_AddExpenseModal> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Dining';
  late String _paidByUid;
  SplitRatio _splitRatio = SplitRatio.half;
  double _customPayerPercent = 50.0;
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _paidByUid = widget.myUid;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitExpense() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense title')),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than \$0')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final entry = FinanceEntry(
        id: '',
        title: title,
        amount: (amount * 100).roundToDouble() / 100.0,
        category: _selectedCategory,
        paidBy: _paidByUid,
        splitRatio: _splitRatio,
        customSplitPercentage:
            _splitRatio == SplitRatio.custom ? _customPayerPercent : null,
        date: _expenseDate,
      );

      await ref.read(financeRepositoryProvider).addExpense(widget.coupleId, entry);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense logged successfully! 💸'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Log Shared Expense',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Expense Title',
                hintText: 'e.g. Dinner at Italian Bistro, Groceries, Movie',
                filled: true,
                fillColor: AppTheme.surfaceVariantLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Amount & Date row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (\$)',
                      prefixText: '\$ ',
                      filled: true,
                      fillColor: AppTheme.surfaceVariantLight,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.inputBorderRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expenseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _expenseDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(DateFormat('MMM d').format(_expenseDate)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.inputBorderRadius),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category Chips
            const Text(
              'Category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FinanceEntry.categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryRose,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppTheme.textPrimaryLight,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Who Paid
            const Text(
              'Who Paid?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: widget.myUid,
                  label: Text('You (${widget.myName})'),
                  icon: const Icon(Icons.person_rounded),
                ),
                ButtonSegment(
                  value: widget.partnerUid,
                  label: Text(widget.partnerName),
                  icon: const Icon(Icons.favorite_rounded),
                ),
              ],
              selected: {_paidByUid},
              onSelectionChanged: (set) {
                setState(() => _paidByUid = set.first);
              },
            ),
            const SizedBox(height: 16),

            // Split Ratio
            const Text(
              'Split Ratio',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('50/50 Equal'),
                  selected: _splitRatio == SplitRatio.half,
                  selectedColor: AppTheme.primaryRose,
                  labelStyle: TextStyle(
                    color: _splitRatio == SplitRatio.half
                        ? Colors.white
                        : AppTheme.textPrimaryLight,
                    fontWeight: _splitRatio == SplitRatio.half
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _splitRatio = SplitRatio.half);
                  },
                ),
                ChoiceChip(
                  label: Text(_paidByUid == widget.myUid
                      ? '100% ${widget.partnerName} owes'
                      : '100% You owe'),
                  selected: _splitRatio == SplitRatio.paidByOther,
                  selectedColor: AppTheme.primaryRose,
                  labelStyle: TextStyle(
                    color: _splitRatio == SplitRatio.paidByOther
                        ? Colors.white
                        : AppTheme.textPrimaryLight,
                    fontWeight: _splitRatio == SplitRatio.paidByOther
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _splitRatio = SplitRatio.paidByOther);
                  },
                ),
                ChoiceChip(
                  label: const Text('Custom %'),
                  selected: _splitRatio == SplitRatio.custom,
                  selectedColor: AppTheme.primaryRose,
                  labelStyle: TextStyle(
                    color: _splitRatio == SplitRatio.custom
                        ? Colors.white
                        : AppTheme.textPrimaryLight,
                    fontWeight: _splitRatio == SplitRatio.custom
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _splitRatio = SplitRatio.custom);
                  },
                ),
              ],
            ),

            if (_splitRatio == SplitRatio.custom) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payer covers: ${_customPayerPercent.round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Partner covers: ${(100 - _customPayerPercent).round()}%',
                    style: const TextStyle(color: AppTheme.textSecondaryLight),
                  ),
                ],
              ),
              Slider(
                value: _customPayerPercent,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${_customPayerPercent.round()}%',
                activeColor: AppTheme.primaryRose,
                onChanged: (val) {
                  setState(() => _customPayerPercent = val);
                },
              ),
            ],
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSaving ? null : _submitExpense,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryRose,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Save Expense',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODAL: CREATE SAVINGS GOAL
// ============================================================================

class _CreateSavingsGoalModal extends ConsumerStatefulWidget {
  final String coupleId;
  final String myUid;

  const _CreateSavingsGoalModal({
    required this.coupleId,
    required this.myUid,
  });

  @override
  ConsumerState<_CreateSavingsGoalModal> createState() =>
      _CreateSavingsGoalModalState();
}

class _CreateSavingsGoalModalState
    extends ConsumerState<_CreateSavingsGoalModal> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _initialDepositController = TextEditingController();
  String _selectedCategory = 'Vacation';
  DateTime? _targetDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _initialDepositController.dispose();
    super.dispose();
  }

  Future<void> _submitGoal() async {
    final title = _titleController.text.trim();
    final target = double.tryParse(_targetController.text.replaceAll(',', '.')) ?? 0.0;
    final initialDeposit =
        double.tryParse(_initialDepositController.text.replaceAll(',', '.')) ?? 0.0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a goal title')),
      );
      return;
    }

    if (target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a target amount greater than \$0')),
      );
      return;
    }

    if (initialDeposit < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initial deposit cannot be negative')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final initialContribs = <SavingsContribution>[];
      if (initialDeposit > 0) {
        initialContribs.add(
          SavingsContribution(
            id: 'c_${DateTime.now().millisecondsSinceEpoch}',
            uid: widget.myUid,
            amount: (initialDeposit * 100).roundToDouble() / 100.0,
            note: 'Initial deposit 💖',
          ),
        );
      }

      final goal = SavingsGoalModel(
        id: '',
        title: title,
        targetAmount: (target * 100).roundToDouble() / 100.0,
        currentAmount: (initialDeposit * 100).roundToDouble() / 100.0,
        targetDate: _targetDate,
        category: _selectedCategory,
        isCompleted: initialDeposit >= target,
        contributions: initialContribs,
        createdBy: widget.myUid,
      );

      await ref
          .read(financeRepositoryProvider)
          .createSavingsGoal(widget.coupleId, goal);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joint savings goal created! 🐷✨'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create goal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'New Joint Savings Goal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Goal Title',
                hintText: 'e.g. Trip to Paris 🗼, Wedding Fund 💍',
                filled: true,
                fillColor: AppTheme.surfaceVariantLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Target Amount & Initial Deposit
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Target Amount (\$)',
                      prefixText: '\$ ',
                      filled: true,
                      fillColor: AppTheme.surfaceVariantLight,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.inputBorderRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _initialDepositController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Starting (\$)',
                      prefixText: '\$ ',
                      hintText: '0.00',
                      filled: true,
                      fillColor: AppTheme.surfaceVariantLight,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.inputBorderRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Target Date picker
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) {
                  setState(() => _targetDate = picked);
                }
              },
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(
                _targetDate == null
                    ? 'Pick Target Date (Optional)'
                    : 'Target Date: ${DateFormat.yMMMd().format(_targetDate!)}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category selector
            const Text(
              'Category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SavingsGoalModel.categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryRose,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppTheme.textPrimaryLight,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Create button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSaving ? null : _submitGoal,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryRose,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Create Piggy Bank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODAL: CONTRIBUTE TO SAVINGS GOAL
// ============================================================================

class _ContributeModal extends ConsumerStatefulWidget {
  final String coupleId;
  final SavingsGoalModel goal;
  final String myUid;
  final String partnerName;

  const _ContributeModal({
    required this.coupleId,
    required this.goal,
    required this.myUid,
    required this.partnerName,
  });

  @override
  ConsumerState<_ContributeModal> createState() => _ContributeModalState();
}

class _ContributeModalState extends ConsumerState<_ContributeModal> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
  }

  Future<void> _submitContribution() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid deposit amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final contribution = SavingsContribution(
        id: '',
        uid: widget.myUid,
        amount: (amount * 100).roundToDouble() / 100.0,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      );

      await ref.read(financeRepositoryProvider).addContribution(
            widget.coupleId,
            widget.goal.id,
            contribution,
          );

      final willReachTarget =
          widget.goal.currentAmount + amount >= widget.goal.targetAmount;

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willReachTarget
                  ? '🎉 GOAL REACHED! You hit the target for "${widget.goal.title}"! 🍾'
                  : 'Added \$${amount.toStringAsFixed(2)} to "${widget.goal.title}"! 🐷',
            ),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to deposit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.savings_rounded, color: AppTheme.primaryRose),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Deposit to "${widget.goal.title}"',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Remaining needed: \$${widget.goal.remainingAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),

            // Quick deposit chips
            Wrap(
              spacing: 8,
              children: [10.0, 25.0, 50.0, 100.0].map((amt) {
                return ActionChip(
                  label: Text('+\$${amt.toInt()}'),
                  backgroundColor: AppTheme.surfaceVariantLight,
                  onPressed: () => _setAmount(amt),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Amount input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Deposit Amount (\$)',
                prefixText: '\$ ',
                filled: true,
                fillColor: AppTheme.surfaceVariantLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Optional note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Cheer note (optional)',
                hintText: 'e.g. Skipped takeout dinner! 🍕',
                filled: true,
                fillColor: AppTheme.surfaceVariantLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSaving ? null : _submitContribution,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryRose,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Deposit into Piggy Bank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
