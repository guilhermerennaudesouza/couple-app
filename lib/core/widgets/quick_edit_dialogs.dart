import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/crypto/vault_crypto_service.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/core/utils/currency_parser.dart';
import 'package:couple_app/features/finance/data/finance_repository.dart';
import 'package:couple_app/features/finance/domain/finance_model.dart';
import 'package:couple_app/features/finance/domain/savings_model.dart';
import 'package:couple_app/features/loyalty/data/loyalty_repository.dart';
import 'package:couple_app/features/loyalty/domain/loyalty_coupon_model.dart';
import 'package:couple_app/features/memories/data/memories_repository.dart';
import 'package:couple_app/features/memories/domain/memory_model.dart';
import 'package:couple_app/features/tasks/data/task_repository.dart';
import 'package:couple_app/features/tasks/domain/checklist_model.dart';
import 'package:couple_app/features/tasks/domain/task_model.dart';
import 'package:couple_app/features/vault/data/vault_repository.dart';
import 'package:couple_app/features/vault/domain/vault_item_model.dart';
import 'package:couple_app/features/wishlist/domain/wish_model.dart';

/// 1. Edit existing shared Task (preserves id, completion state, createdBy).
Future<void> showEditTaskDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required TaskModel task,
}) async {
  final strings = AppStrings.of(context);
  final titleCtrl = TextEditingController(text: task.title);
  final descCtrl = TextEditingController(text: task.description);
  String category = TaskRepository.standardCategories.contains(task.category)
      ? task.category
      : TaskRepository.standardCategories.first;
  DateTime? dueDate = task.dueDate;

  final updated = await showDialog<TaskModel?>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Editar Tarefa' : 'Edit Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Título' : 'Title',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Detalhes' : 'Details',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(labelText: strings.categoryLabel),
                items: TaskRepository.standardCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded, color: AppTheme.primaryRose),
                title: Text(
                  dueDate != null
                      ? '${dueDate!.day.toString().padLeft(2, '0')}/${dueDate!.month.toString().padLeft(2, '0')}/${dueDate!.year}'
                      : strings.setDueDate,
                ),
                trailing: dueDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setDialogState(() => dueDate = null),
                      )
                    : null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: dueDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setDialogState(() => dueDate = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) return;
              Navigator.of(dialogCtx).pop(
                task.copyWith(
                  title: t,
                  description: descCtrl.text.trim(),
                  category: category,
                  dueDate: dueDate,
                  clearDueDate: dueDate == null,
                ),
              );
            },
            child: Text(strings.save),
          ),
        ],
      ),
    ),
  );
  titleCtrl.dispose();
  descCtrl.dispose();

  if (updated != null) {
    await ref.read(taskRepositoryProvider).updateTask(coupleId, updated);
  }
}

/// 2. Edit existing Checklist title & category (preserves all items).
Future<void> showEditChecklistDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required ChecklistModel list,
}) async {
  final strings = AppStrings.of(context);
  final titleCtrl = TextEditingController(text: list.title);
  String category = TaskRepository.standardCategories.contains(list.category)
      ? list.category
      : TaskRepository.standardCategories.first;

  final updated = await showDialog<ChecklistModel?>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Editar Lista' : 'Edit Checklist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: strings.listTitleLabel),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(labelText: strings.categoryLabel),
              items: TaskRepository.standardCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => category = v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) return;
              Navigator.of(dialogCtx).pop(
                list.copyWith(
                  title: t,
                  category: category,
                  updatedAt: DateTime.now(),
                ),
              );
            },
            child: Text(strings.save),
          ),
        ],
      ),
    ),
  );
  titleCtrl.dispose();

  if (updated != null) {
    await ref.read(taskRepositoryProvider).updateList(coupleId, updated);
  }
}

/// 3. Edit existing shared Expense using BRL currency parser (preserves id & settlement).
Future<void> showEditExpenseDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required FinanceEntry entry,
}) async {
  final strings = AppStrings.of(context);
  final titleCtrl = TextEditingController(text: entry.title);
  final amountCtrl = TextEditingController(
    text: entry.amount.toStringAsFixed(2).replaceAll('.', ','),
  );
  String category = FinanceEntry.categories.contains(entry.category)
      ? entry.category
      : FinanceEntry.categories.first;

  final updated = await showDialog<FinanceEntry?>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Editar Despesa' : 'Edit Expense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Descrição' : 'Description',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Valor (R\$)' : 'Amount',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(labelText: strings.categoryLabel),
                items: FinanceEntry.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
            onPressed: () {
              final t = titleCtrl.text.trim();
              final parsed = parseBrlCurrency(amountCtrl.text);
              if (t.isEmpty || parsed == null || parsed <= 0) return;
              Navigator.of(dialogCtx).pop(
                entry.copyWith(
                  title: t,
                  amount: parsed,
                  category: category,
                ),
              );
            },
            child: Text(strings.save),
          ),
        ],
      ),
    ),
  );
  titleCtrl.dispose();
  amountCtrl.dispose();

  if (updated != null) {
    await ref.read(financeRepositoryProvider).addExpense(coupleId, updated);
  }
}

/// 4. Edit existing Savings Goal (preserves id, currentAmount, and contribution history).
Future<void> showEditSavingsGoalDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required SavingsGoalModel goal,
}) async {
  final strings = AppStrings.of(context);
  final titleCtrl = TextEditingController(text: goal.title);
  final targetCtrl = TextEditingController(
    text: goal.targetAmount.toStringAsFixed(2).replaceAll('.', ','),
  );
  String category = SavingsGoalModel.categories.contains(goal.category)
      ? goal.category
      : SavingsGoalModel.categories.first;

  final updated = await showDialog<SavingsGoalModel?>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Editar Meta' : 'Edit Goal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Nome da meta' : 'Goal title',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Valor alvo (R\$)' : 'Target amount',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(labelText: strings.categoryLabel),
                items: SavingsGoalModel.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
            onPressed: () {
              final t = titleCtrl.text.trim();
              final target = parseBrlCurrency(targetCtrl.text);
              if (t.isEmpty || target == null || target <= 0) return;
              Navigator.of(dialogCtx).pop(
                goal.copyWith(
                  title: t,
                  targetAmount: target,
                  category: category,
                ),
              );
            },
            child: Text(strings.save),
          ),
        ],
      ),
    ),
  );
  titleCtrl.dispose();
  targetCtrl.dispose();

  if (updated != null) {
    await ref.read(financeRepositoryProvider).createSavingsGoal(coupleId, updated);
  }
}

/// 5. Edit existing Memory (preserves id, photos, createdBy).
Future<void> showEditMemoryDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required MemoryModel memory,
}) async {
  final strings = AppStrings.of(context);
  final titleCtrl = TextEditingController(text: memory.title);
  final captionCtrl = TextEditingController(text: memory.caption);
  final locationCtrl = TextEditingController(text: memory.location ?? '');
  DateTime selectedDate = memory.date;

  final updated = await showDialog<MemoryModel?>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Editar Memória' : 'Edit Memory'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Título' : 'Title',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: captionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'História / Legenda' : 'Story / Caption',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Local (opcional)' : 'Location (optional)',
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryRose),
                title: Text(
                  '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => selectedDate = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) return;
              final loc = locationCtrl.text.trim();
              Navigator.of(dialogCtx).pop(
                memory.copyWith(
                  title: t,
                  caption: captionCtrl.text.trim(),
                  location: loc.isEmpty ? null : loc,
                  date: selectedDate,
                ),
              );
            },
            child: Text(strings.save),
          ),
        ],
      ),
    ),
  );
  titleCtrl.dispose();
  captionCtrl.dispose();
  locationCtrl.dispose();

  if (updated != null) {
    await ref.read(memoriesRepositoryProvider).updateMemory(coupleId, updated);
  }
}

/// 6. Edit existing Wish item using BRL currency parser (preserves id & purchase status).
Future<void> showEditWishDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required WishModel wish,
}) async {
  final strings = AppStrings.of(context);
  final titleCtrl = TextEditingController(text: wish.title);
  final descCtrl = TextEditingController(text: wish.description ?? '');
  final priceCtrl = TextEditingController(
    text: wish.estimatedPrice != null
        ? wish.estimatedPrice!.toStringAsFixed(2).replaceAll('.', ',')
        : '',
  );
  final linkCtrl = TextEditingController(text: wish.url ?? '');

  final updated = await showDialog<WishModel?>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Desejo' : 'Edit Wish'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Desejo' : 'Wish title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Detalhes' : 'Details',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Preço estimado (R\$)' : 'Estimated price',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: linkCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Link (opcional)' : 'Link (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final t = titleCtrl.text.trim();
            if (t.isEmpty) return;
            final price = priceCtrl.text.trim().isEmpty
                ? null
                : parseBrlCurrency(priceCtrl.text);
            final desc = descCtrl.text.trim();
            final link = linkCtrl.text.trim();
            Navigator.of(dialogCtx).pop(
              wish.copyWith(
                title: t,
                description: desc.isEmpty ? null : desc,
                estimatedPrice: price,
                url: link.isEmpty ? null : link,
              ),
            );
          },
          child: Text(strings.save),
        ),
      ],
    ),
  );
  titleCtrl.dispose();
  descCtrl.dispose();
  priceCtrl.dispose();
  linkCtrl.dispose();

  if (updated != null) {
    await ref.read(memoriesRepositoryProvider).updateWish(coupleId, updated);
  }
}

/// 7. Edit an unlocked Vault Item, re-encrypting the secret with [unlockedKey].
Future<bool> showEditVaultItemDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required VaultItemModel item,
  required String currentPlaintext,
  required SecretKey unlockedKey,
}) async {
  final strings = AppStrings.of(context);
  final titleCtrl = TextEditingController(text: item.title);
  final secretCtrl = TextEditingController(text: currentPlaintext);

  final result = await showDialog<Map<String, String>?>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Segredo 🔐' : 'Edit Secret 🔐'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Título' : 'Title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: secretCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: strings.secretContentLabel,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final t = titleCtrl.text.trim();
            final s = secretCtrl.text.trim();
            if (t.isEmpty || s.isEmpty) return;
            Navigator.of(dialogCtx).pop({'title': t, 'secret': s});
          },
          child: Text(strings.save),
        ),
      ],
    ),
  );
  titleCtrl.dispose();
  secretCtrl.dispose();

  if (result == null) return false;
  final crypto = VaultCryptoService();
  final reEncrypted = await crypto.encrypt(
    plaintext: result['secret']!,
    key: unlockedKey,
  );
  await ref.read(vaultRepositoryProvider).saveVaultItem(
        coupleId,
        item.copyWith(
          title: result['title']!,
          payload: reEncrypted,
          updatedAt: DateTime.now(),
        ),
      );
  return true;
}

/// 8. Edit existing Love Coupon / Loyalty Card (preserves id & usedCount).
Future<void> showEditCouponDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required LoyaltyCouponModel coupon,
}) async {
  final strings = AppStrings.of(context);
  final titleCtrl = TextEditingController(text: coupon.title);
  final descCtrl = TextEditingController(text: coupon.description);
  final emojiCtrl = TextEditingController(text: coupon.emoji);
  int maxUses = coupon.maxUses;
  String category = LoyaltyCouponModel.couponCategories.contains(coupon.category)
      ? coupon.category
      : LoyaltyCouponModel.categoryRomance;

  final updated = await showDialog<LoyaltyCouponModel?>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Editar Cupom' : 'Edit Coupon'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Título do vale' : 'Coupon title',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: strings.isPortuguese ? 'Descrição' : 'Description',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: emojiCtrl,
                      maxLength: 4,
                      decoration: const InputDecoration(labelText: 'Emoji'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(labelText: strings.categoryLabel),
                      items: LoyaltyCouponModel.couponCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => category = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    strings.isPortuguese ? 'Usos totais: $maxUses' : 'Max uses: $maxUses',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: maxUses > 1
                        ? () => setDialogState(() => maxUses--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: maxUses < 20
                        ? () => setDialogState(() => maxUses++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) return;
              Navigator.of(dialogCtx).pop(
                coupon.copyWith(
                  title: t,
                  description: descCtrl.text.trim(),
                  emoji: emojiCtrl.text.trim().isNotEmpty
                      ? emojiCtrl.text.trim()
                      : coupon.emoji,
                  category: category,
                  maxUses: maxUses,
                ),
              );
            },
            child: Text(strings.save),
          ),
        ],
      ),
    ),
  );
  titleCtrl.dispose();
  descCtrl.dispose();
  emojiCtrl.dispose();

  if (updated != null) {
    await ref.read(loyaltyRepositoryProvider).addCoupon(coupleId, updated);
  }
}
