import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:couple_app/core/crypto/vault_crypto_service.dart';
import 'package:couple_app/core/l10n/app_strings.dart';
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

// ---------------------------------------------------------------------------
// Pure, unit-tested edit builders ensuring optional-field clearing & invariants
// ---------------------------------------------------------------------------

MemoryModel buildEditedMemory(
  MemoryModel original, {
  required String title,
  required String caption,
  required String locationInput,
  required DateTime date,
}) {
  final loc = locationInput.trim();
  return original.copyWith(
    title: title.trim(),
    caption: caption.trim(),
    location: loc.isEmpty ? null : loc,
    clearLocation: loc.isEmpty,
    date: date,
  );
}

/// Returns `null` if [priceInput] is non-empty yet cannot be parsed as a valid positive number.
WishModel? buildEditedWish(
  WishModel original, {
  required String title,
  required String descriptionInput,
  required String priceInput,
  required String urlInput,
}) {
  final cleanTitle = title.trim();
  if (cleanTitle.isEmpty) return null;
  final trimmedPrice = priceInput.trim();
  double? parsedPrice;
  if (trimmedPrice.isNotEmpty) {
    parsedPrice = parseBrlCurrency(trimmedPrice);
    if (parsedPrice == null || parsedPrice < 0) return null;
  }
  final desc = descriptionInput.trim();
  final url = urlInput.trim();
  return original.copyWith(
    title: cleanTitle,
    description: desc.isEmpty ? null : desc,
    clearDescription: desc.isEmpty,
    estimatedPrice: parsedPrice,
    clearPrice: trimmedPrice.isEmpty,
    url: url.isEmpty ? null : url,
    clearUrl: url.isEmpty,
  );
}

SavingsGoalModel buildEditedSavingsGoal(
  SavingsGoalModel original, {
  required String title,
  required double targetAmount,
  required String category,
}) {
  return original.copyWith(
    title: title.trim(),
    targetAmount: targetAmount,
    category: category,
    isCompleted: original.currentAmount >= targetAmount,
  );
}

int minAllowedCouponMaxUses(LoyaltyCouponModel coupon) => max(1, coupon.usedCount);

int maxAllowedCouponMaxUses(LoyaltyCouponModel coupon) => max(20, coupon.maxUses);

// ---------------------------------------------------------------------------
// 1. Edit Task Dialog (Stateful controller lifecycle)
// ---------------------------------------------------------------------------

Future<void> showEditTaskDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required TaskModel task,
}) async {
  final updated = await showDialog<TaskModel?>(
    context: context,
    builder: (_) => _EditTaskDialog(task: task),
  );
  if (updated != null) {
    await ref.read(taskRepositoryProvider).updateTask(coupleId, updated);
  }
}

class _EditTaskDialog extends StatefulWidget {
  final TaskModel task;
  const _EditTaskDialog({required this.task});

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _descCtrl = TextEditingController(text: widget.task.description);
    _category = TaskRepository.standardCategories.contains(widget.task.category)
        ? widget.task.category
        : TaskRepository.standardCategories.first;
    _dueDate = widget.task.dueDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Tarefa' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Título' : 'Title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Detalhes' : 'Details',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: strings.categoryLabel),
              items: TaskRepository.standardCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded, color: AppTheme.primaryRose),
              title: Text(
                _dueDate != null
                    ? '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}'
                    : strings.setDueDate,
              ),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null && mounted) setState(() => _dueDate = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final t = _titleCtrl.text.trim();
            if (t.isEmpty) return;
            Navigator.of(context).pop(
              widget.task.copyWith(
                title: t,
                description: _descCtrl.text.trim(),
                category: _category,
                dueDate: _dueDate,
                clearDueDate: _dueDate == null,
              ),
            );
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Edit Checklist Metadata Dialog (never overwrites concurrent item edits)
// ---------------------------------------------------------------------------

Future<void> showEditChecklistDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required ChecklistModel list,
}) async {
  final result = await showDialog<Map<String, String>?>(
    context: context,
    builder: (_) => _EditChecklistDialog(list: list),
  );
  if (result != null) {
    await ref.read(taskRepositoryProvider).updateListMetadata(
          coupleId,
          list.id,
          title: result['title']!,
          category: result['category']!,
        );
  }
}

class _EditChecklistDialog extends StatefulWidget {
  final ChecklistModel list;
  const _EditChecklistDialog({required this.list});

  @override
  State<_EditChecklistDialog> createState() => _EditChecklistDialogState();
}

class _EditChecklistDialogState extends State<_EditChecklistDialog> {
  late final TextEditingController _titleCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.list.title);
    _category = TaskRepository.standardCategories.contains(widget.list.category)
        ? widget.list.category
        : TaskRepository.standardCategories.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Lista' : 'Edit Checklist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(labelText: strings.listTitleLabel),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: strings.categoryLabel),
            items: TaskRepository.standardCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final t = _titleCtrl.text.trim();
            if (t.isEmpty) return;
            Navigator.of(context).pop({'title': t, 'category': _category});
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Edit Expense Dialog
// ---------------------------------------------------------------------------

Future<void> showEditExpenseDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required FinanceEntry entry,
}) async {
  final updated = await showDialog<FinanceEntry?>(
    context: context,
    builder: (_) => _EditExpenseDialog(entry: entry),
  );
  if (updated != null) {
    await ref.read(financeRepositoryProvider).addExpense(coupleId, updated);
  }
}

class _EditExpenseDialog extends StatefulWidget {
  final FinanceEntry entry;
  const _EditExpenseDialog({required this.entry});

  @override
  State<_EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<_EditExpenseDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.entry.title);
    _amountCtrl = TextEditingController(
      text: widget.entry.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _category = FinanceEntry.categories.contains(widget.entry.category)
        ? widget.entry.category
        : FinanceEntry.categories.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Despesa' : 'Edit Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Descrição' : 'Description',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Valor (R\$)' : 'Amount',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: strings.categoryLabel),
              items: FinanceEntry.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final t = _titleCtrl.text.trim();
            final parsed = parseBrlCurrency(_amountCtrl.text);
            if (t.isEmpty || parsed == null || parsed <= 0) return;
            Navigator.of(context).pop(
              widget.entry.copyWith(
                title: t,
                amount: parsed,
                category: _category,
              ),
            );
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Edit Savings Goal Metadata Dialog (recomputes isCompleted & never clobbers deposits)
// ---------------------------------------------------------------------------

Future<void> showEditSavingsGoalDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required SavingsGoalModel goal,
}) async {
  final updated = await showDialog<SavingsGoalModel?>(
    context: context,
    builder: (_) => _EditSavingsGoalDialog(goal: goal),
  );
  if (updated != null) {
    await ref.read(financeRepositoryProvider).updateSavingsGoalMetadata(
          coupleId,
          updated.id,
          title: updated.title,
          targetAmount: updated.targetAmount,
          category: updated.category,
          isCompleted: updated.isCompleted,
        );
  }
}

class _EditSavingsGoalDialog extends StatefulWidget {
  final SavingsGoalModel goal;
  const _EditSavingsGoalDialog({required this.goal});

  @override
  State<_EditSavingsGoalDialog> createState() => _EditSavingsGoalDialogState();
}

class _EditSavingsGoalDialogState extends State<_EditSavingsGoalDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _targetCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.goal.title);
    _targetCtrl = TextEditingController(
      text: widget.goal.targetAmount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _category = SavingsGoalModel.categories.contains(widget.goal.category)
        ? widget.goal.category
        : SavingsGoalModel.categories.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Meta' : 'Edit Goal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Nome da meta' : 'Goal title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    strings.isPortuguese ? 'Valor alvo (R\$)' : 'Target amount',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: strings.categoryLabel),
              items: SavingsGoalModel.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final t = _titleCtrl.text.trim();
            final target = parseBrlCurrency(_targetCtrl.text);
            if (t.isEmpty || target == null || target <= 0) return;
            Navigator.of(context).pop(
              buildEditedSavingsGoal(
                widget.goal,
                title: t,
                targetAmount: target,
                category: _category,
              ),
            );
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Edit Memory Dialog (supports clearing location cleanly)
// ---------------------------------------------------------------------------

Future<void> showEditMemoryDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required MemoryModel memory,
}) async {
  final updated = await showDialog<MemoryModel?>(
    context: context,
    builder: (_) => _EditMemoryDialog(memory: memory),
  );
  if (updated != null) {
    await ref.read(memoriesRepositoryProvider).updateMemory(coupleId, updated);
  }
}

class _EditMemoryDialog extends StatefulWidget {
  final MemoryModel memory;
  const _EditMemoryDialog({required this.memory});

  @override
  State<_EditMemoryDialog> createState() => _EditMemoryDialogState();
}

class _EditMemoryDialogState extends State<_EditMemoryDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _captionCtrl;
  late final TextEditingController _locationCtrl;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.memory.title);
    _captionCtrl = TextEditingController(text: widget.memory.caption);
    _locationCtrl = TextEditingController(text: widget.memory.location ?? '');
    _selectedDate = widget.memory.date;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Memória' : 'Edit Memory'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Título' : 'Title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _captionCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                    strings.isPortuguese ? 'História / Legenda' : 'Story / Caption',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese
                    ? 'Local (opcional)'
                    : 'Location (optional)',
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.primaryRose,
              ),
              title: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && mounted) {
                  setState(() => _selectedDate = picked);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final t = _titleCtrl.text.trim();
            if (t.isEmpty) return;
            Navigator.of(context).pop(
              buildEditedMemory(
                widget.memory,
                title: t,
                caption: _captionCtrl.text,
                locationInput: _locationCtrl.text,
                date: _selectedDate,
              ),
            );
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Edit Wish Dialog (supports clearing description/price/url & validates price)
// ---------------------------------------------------------------------------

Future<void> showEditWishDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required WishModel wish,
}) async {
  final updated = await showDialog<WishModel?>(
    context: context,
    builder: (_) => _EditWishDialog(wish: wish),
  );
  if (updated != null) {
    await ref.read(memoriesRepositoryProvider).updateWish(coupleId, updated);
  }
}

class _EditWishDialog extends StatefulWidget {
  final WishModel wish;
  const _EditWishDialog({required this.wish});

  @override
  State<_EditWishDialog> createState() => _EditWishDialogState();
}

class _EditWishDialogState extends State<_EditWishDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _urlCtrl;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.wish.title);
    _descCtrl = TextEditingController(text: widget.wish.description ?? '');
    _priceCtrl = TextEditingController(
      text: widget.wish.estimatedPrice != null
          ? widget.wish.estimatedPrice!.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    _urlCtrl = TextEditingController(text: widget.wish.url ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Desejo' : 'Edit Wish'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Desejo' : 'Wish title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Detalhes' : 'Details',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (_priceError != null) setState(() => _priceError = null);
              },
              decoration: InputDecoration(
                labelText: strings.isPortuguese
                    ? 'Preço estimado (R\$)'
                    : 'Estimated price',
                errorText: _priceError,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Link (opcional)' : 'Link (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final edited = buildEditedWish(
              widget.wish,
              title: _titleCtrl.text,
              descriptionInput: _descCtrl.text,
              priceInput: _priceCtrl.text,
              urlInput: _urlCtrl.text,
            );
            if (edited == null) {
              if (_priceCtrl.text.trim().isNotEmpty &&
                  parseBrlCurrency(_priceCtrl.text) == null) {
                setState(() {
                  _priceError = strings.isPortuguese
                      ? 'Preço inválido (ex: 150,50)'
                      : 'Invalid price';
                });
              }
              return;
            }
            Navigator.of(context).pop(edited);
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Edit Vault Item Dialog (AES-256-GCM re-encryption)
// ---------------------------------------------------------------------------

Future<bool> showEditVaultItemDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required VaultItemModel item,
  required String currentPlaintext,
  required SecretKey unlockedKey,
}) async {
  final result = await showDialog<Map<String, String>?>(
    context: context,
    builder: (_) => _EditVaultItemDialog(
      initialTitle: item.title,
      initialPlaintext: currentPlaintext,
    ),
  );
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

class _EditVaultItemDialog extends StatefulWidget {
  final String initialTitle;
  final String initialPlaintext;

  const _EditVaultItemDialog({
    required this.initialTitle,
    required this.initialPlaintext,
  });

  @override
  State<_EditVaultItemDialog> createState() => _EditVaultItemDialogState();
}

class _EditVaultItemDialogState extends State<_EditVaultItemDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _secretCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _secretCtrl = TextEditingController(text: widget.initialPlaintext);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Segredo 🔐' : 'Edit Secret 🔐'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: strings.isPortuguese ? 'Título' : 'Title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _secretCtrl,
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
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final t = _titleCtrl.text.trim();
            final s = _secretCtrl.text.trim();
            if (t.isEmpty || s.isEmpty) return;
            Navigator.of(context).pop({'title': t, 'secret': s});
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Edit Love Coupon Metadata Dialog (enforces usedCount <= maxUses & partial save)
// ---------------------------------------------------------------------------

Future<void> showEditCouponDialog(
  BuildContext context,
  WidgetRef ref, {
  required String coupleId,
  required LoyaltyCouponModel coupon,
}) async {
  final result = await showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (_) => _EditCouponDialog(coupon: coupon),
  );
  if (result != null) {
    await ref.read(loyaltyRepositoryProvider).updateCouponMetadata(
          coupleId,
          coupon.id,
          title: result['title'] as String,
          description: result['description'] as String,
          emoji: result['emoji'] as String,
          category: result['category'] as String,
          maxUses: result['maxUses'] as int,
        );
  }
}

class _EditCouponDialog extends StatefulWidget {
  final LoyaltyCouponModel coupon;
  const _EditCouponDialog({required this.coupon});

  @override
  State<_EditCouponDialog> createState() => _EditCouponDialogState();
}

class _EditCouponDialogState extends State<_EditCouponDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _emojiCtrl;
  late int _maxUses;
  late String _category;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.coupon.title);
    _descCtrl = TextEditingController(text: widget.coupon.description);
    _emojiCtrl = TextEditingController(text: widget.coupon.emoji);
    _maxUses = max(widget.coupon.maxUses, minAllowedCouponMaxUses(widget.coupon));
    _category =
        LoyaltyCouponModel.couponCategories.contains(widget.coupon.category)
            ? widget.coupon.category
            : LoyaltyCouponModel.categoryRomance;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final minUses = minAllowedCouponMaxUses(widget.coupon);
    final maxUsesCap = maxAllowedCouponMaxUses(widget.coupon);

    return AlertDialog(
      title: Text(strings.isPortuguese ? 'Editar Cupom' : 'Edit Coupon'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText:
                    strings.isPortuguese ? 'Título do vale' : 'Coupon title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
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
                    controller: _emojiCtrl,
                    maxLength: 4,
                    decoration: const InputDecoration(labelText: 'Emoji'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: InputDecoration(labelText: strings.categoryLabel),
                    items: LoyaltyCouponModel.couponCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  strings.isPortuguese
                      ? 'Usos totais: $_maxUses'
                      : 'Max uses: $_maxUses',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _maxUses > minUses
                      ? () => setState(() => _maxUses--)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _maxUses < maxUsesCap
                      ? () => setState(() => _maxUses++)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
          onPressed: () {
            final t = _titleCtrl.text.trim();
            if (t.isEmpty) return;
            Navigator.of(context).pop({
              'title': t,
              'description': _descCtrl.text.trim(),
              'emoji': _emojiCtrl.text.trim().isNotEmpty
                  ? _emojiCtrl.text.trim()
                  : widget.coupon.emoji,
              'category': _category,
              'maxUses': _maxUses,
            });
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}
