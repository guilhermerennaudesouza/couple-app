import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_strings.dart';
import '../../auth/domain/couple_model.dart';
import '../../auth/data/pairing_repository.dart';
import '../domain/task_model.dart';
import '../domain/checklist_model.dart';
import '../data/task_repository.dart';

/// Active filter for the Tasks & Chores tab.
enum TaskFilter { all, mine, partner, completed }

/// Interactive dual-tab screen for shared tasks, chores, and couple checklists.
class TasksScreen extends ConsumerStatefulWidget {
  final CoupleModel? initialCouple;
  final String? coupleId;
  final String? currentUid;

  const TasksScreen({
    super.key,
    this.initialCouple,
    this.coupleId,
    this.currentUid,
  });

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskFilter _currentTaskFilter = TaskFilter.all;
  final Map<String, TextEditingController> _inlineItemControllers = {};

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
    for (final controller in _inlineItemControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getEffectiveUid() {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'guest_uid';
  }

  TextEditingController _getInlineController(String listId) {
    return _inlineItemControllers.putIfAbsent(
      listId,
      () => TextEditingController(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUid = _getEffectiveUid();
    final activeCoupleId = widget.coupleId ??
        widget.initialCouple?.id ??
        ref.watch(currentCoupleIdProvider).valueOrNull ??
        '';

    final strings = AppStrings.of(context);

    if (activeCoupleId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryRose, size: 24),
              const SizedBox(width: 8),
              Text(
                strings.sharedTasksTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
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

    final coupleAsync = ref.watch(coupleStreamProvider(activeCoupleId));
    final couple = widget.initialCouple ?? coupleAsync.valueOrNull;
    final partnerUid = couple?.getOtherUid(effectiveUid);
    final partnerProfile = couple?.getPartnerProfile(effectiveUid);
    final partnerName = partnerProfile?.displayName.isNotEmpty == true
        ? partnerProfile!.displayName
        : (strings.isPortuguese ? 'Seu Amor' : 'Partner');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryRose, size: 24),
            const SizedBox(width: 8),
            Text(
              strings.sharedTasksTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryRose,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: context.textSecondary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(
              icon: const Icon(Icons.assignment_outlined),
              text: strings.tasksTab,
            ),
            Tab(
              icon: const Icon(Icons.format_list_bulleted_rounded),
              text: strings.listsTab,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(activeCoupleId, effectiveUid, partnerUid, partnerName),
          _buildListsTab(activeCoupleId, effectiveUid, partnerName),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryRose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? strings.newTask : strings.newList,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddTaskSheet(context, activeCoupleId, effectiveUid, partnerUid, partnerName);
          } else {
            _showAddListSheet(context, activeCoupleId, effectiveUid);
          }
        },
      ),
    );
  }

  // ==========================================
  // Tasks Tab
  // ==========================================

  Widget _buildTasksTab(
    String coupleId,
    String myUid,
    String? partnerUid,
    String partnerName,
  ) {
    final strings = AppStrings.of(context);
    final tasksAsync = ref.watch(tasksStreamProvider(coupleId));

    return Column(
      children: [
        _buildTaskFilterChips(partnerName),
        Expanded(
          child: tasksAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRose),
            ),
            error: (err, _) => Center(
              child: Text(
                'Could not load tasks: $err',
                style: const TextStyle(color: AppTheme.errorRed),
              ),
            ),
            data: (tasks) {
              final filteredTasks = _filterTasks(tasks, myUid, partnerUid);

              if (filteredTasks.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.checklist_rtl_rounded,
                  title: strings.noTasksFound,
                  subtitle: _currentTaskFilter == TaskFilter.completed
                      ? strings.noCompletedTasksDesc
                      : strings.noTasksDesc,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 84),
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = filteredTasks[index];
                  return _buildTaskCard(
                    task,
                    coupleId,
                    myUid,
                    partnerUid,
                    partnerName,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskFilterChips(String partnerName) {
    final strings = AppStrings.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _filterChip(TaskFilter.all, strings.isPortuguese ? 'Todas' : 'All Tasks'),
          const SizedBox(width: 8),
          _filterChip(TaskFilter.mine, strings.isPortuguese ? 'Minhas' : 'Mine'),
          const SizedBox(width: 8),
          _filterChip(TaskFilter.partner, strings.isPortuguese ? 'De $partnerName' : "$partnerName's"),
          const SizedBox(width: 8),
          _filterChip(TaskFilter.completed, strings.isPortuguese ? 'Concluídas' : 'Completed'),
        ],
      ),
    );
  }

  Widget _filterChip(TaskFilter filter, String label) {
    final isSelected = _currentTaskFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _currentTaskFilter = filter);
        }
      },
      selectedColor: AppTheme.primaryRoseLight.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryRoseDark : context.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryRose : AppTheme.outlineLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  List<TaskModel> _filterTasks(
    List<TaskModel> tasks,
    String myUid,
    String? partnerUid,
  ) {
    switch (_currentTaskFilter) {
      case TaskFilter.all:
        return tasks.where((t) => !t.isCompleted).toList();
      case TaskFilter.mine:
        return tasks.where((t) => !t.isCompleted && t.assignedTo == myUid).toList();
      case TaskFilter.partner:
        return tasks
            .where((t) => !t.isCompleted && partnerUid != null && t.assignedTo == partnerUid)
            .toList();
      case TaskFilter.completed:
        return tasks.where((t) => t.isCompleted).toList();
    }
  }

  Widget _buildTaskCard(
    TaskModel task,
    String coupleId,
    String myUid,
    String? partnerUid,
    String partnerName,
  ) {
    final strings = AppStrings.of(context);
    final isDone = task.isCompleted;
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !task.isCompleted;

    return Dismissible(
      key: Key('task_${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withOpacity(0.85),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        ref.read(taskRepositoryProvider).deleteTask(coupleId, task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.taskDeleted(task.title)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          side: BorderSide(
            color: isDone
                ? context.outlineColor.withOpacity(0.5)
                : context.outlineColor,
          ),
        ),
        color: isDone
            ? (context.isDarkMode ? AppTheme.surfaceVariantDark : Colors.grey.shade50)
            : context.cardColor,
        elevation: isDone ? 0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox with animation
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Checkbox(
                  value: task.isCompleted,
                  activeColor: AppTheme.primaryRose,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (val) {
                    final nextVal = val ?? !task.isCompleted;
                    ref.read(taskRepositoryProvider).toggleTask(
                          coupleId,
                          task.id,
                          nextVal,
                        );
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? context.textSecondary
                            : context.textPrimary,
                        decoration:
                            isDone ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Badges row: Category, Assignee, Due Date
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Category Chip
                        _buildSmallChip(
                          icon: _categoryIcon(task.category),
                          label: _translateCategory(task.category, strings),
                          color: context.surfaceVariant,
                          textColor: AppTheme.primaryRoseDark,
                        ),

                        // Assignee Badge
                        _buildAssigneeBadge(task.assignedTo, myUid, partnerUid, partnerName, strings),

                        // Due Date Badge
                        if (task.dueDate != null)
                          _buildDueDateBadge(task.dueDate!, isOverdue, isDone, strings),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18),
                color: context.textSecondary.withOpacity(0.6),
                onPressed: () {
                  ref.read(taskRepositoryProvider).deleteTask(coupleId, task.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeBadge(
    String? assignedTo,
    String myUid,
    String? partnerUid,
    String partnerName,
    AppStrings strings,
  ) {
    if (assignedTo == null || assignedTo.isEmpty) {
      return _buildSmallChip(
        icon: Icons.person_outline_rounded,
        label: strings.sharedBadge,
        color: context.surfaceVariant,
        textColor: context.textSecondary,
      );
    }

    final isMe = assignedTo == myUid;
    return _buildSmallChip(
      icon: isMe ? Icons.face_rounded : Icons.favorite_rounded,
      label: isMe ? strings.youBadge : partnerName,
      color: isMe
          ? AppTheme.pastelPeach.withOpacity(0.6)
          : AppTheme.secondaryBlush.withOpacity(0.3),
      textColor: isMe ? const Color(0xFFB45309) : AppTheme.primaryRoseDark,
    );
  }

  Widget _buildDueDateBadge(DateTime date, bool isOverdue, bool isDone, AppStrings strings) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final formatted = isToday
        ? strings.todayBadge
        : DateFormat(strings.isPortuguese ? 'd MMM' : 'MMM d', strings.isPortuguese ? 'pt_BR' : 'en_US').format(date);

    Color bg;
    Color fg;

    if (isDone) {
      bg = context.surfaceVariant;
      fg = context.textSecondary;
    } else if (isOverdue) {
      bg = AppTheme.errorRed.withOpacity(0.12);
      fg = AppTheme.errorRed;
    } else if (isToday) {
      bg = AppTheme.goldAccent.withOpacity(0.2);
      fg = const Color(0xFFB45309);
    } else {
      bg = AppTheme.pastelLavender.withOpacity(0.5);
      fg = const Color(0xFF6B46C1);
    }

    return _buildSmallChip(
      icon: isOverdue && !isDone ? Icons.warning_amber_rounded : Icons.schedule_rounded,
      label: isOverdue && !isDone ? strings.overdueBadge(formatted) : formatted,
      color: bg,
      textColor: fg,
    );
  }

  String _translateCategory(String category, AppStrings strings) {
    if (!strings.isPortuguese) return category;
    switch (category.toLowerCase()) {
      case 'home':
        return 'Casa';
      case 'shopping':
        return 'Compras';
      case 'errands':
        return 'Tarefas';
      case 'romance':
        return 'Romance';
      case 'travel':
        return 'Viagem';
      case 'health':
        return 'Saúde';
      case 'finance':
        return 'Finanças';
      case 'general':
        return 'Geral';
      default:
        return category;
    }
  }

  Widget _buildSmallChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Checklists Tab
  // ==========================================

  Widget _buildListsTab(String coupleId, String myUid, String partnerName) {
    final strings = AppStrings.of(context);
    final listsAsync = ref.watch(listsStreamProvider(coupleId));

    return listsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, _) => Center(
        child: Text(
          'Could not load checklists: $err',
          style: TextStyle(color: AppTheme.errorRed),
        ),
      ),
      data: (lists) {
        if (lists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.format_list_bulleted_rounded,
                  size: 64,
                  color: AppTheme.secondaryBlush,
                ),
                const SizedBox(height: 16),
                Text(
                  strings.noChecklistsYet,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.noChecklistsDesc,
                  style: TextStyle(color: context.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(strings.addTemplatesBtn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRose,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    ref.read(taskRepositoryProvider).seedDefaultListsIfEmpty(coupleId);
                  },
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 84),
          itemCount: lists.length,
          itemBuilder: (context, index) {
            final list = lists[index];
            return _buildChecklistCard(list, coupleId, myUid, partnerName);
          },
        );
      },
    );
  }

  Widget _buildChecklistCard(
    ChecklistModel list,
    String coupleId,
    String myUid,
    String partnerName,
  ) {
    final strings = AppStrings.of(context);
    final inlineController = _getInlineController(list.id);
    final progress = list.progressPercentage;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        side: BorderSide(color: context.outlineColor),
      ),
      elevation: 0.5,
      child: ExpansionTile(
        key: PageStorageKey('list_${list.id}'),
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _categoryColor(list.category).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _categoryIcon(list.category),
            color: _categoryColor(list.category),
            size: 22,
          ),
        ),
        title: Text(
          list.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        list.isFullyCompleted
                            ? AppTheme.successGreen
                            : AppTheme.primaryRose,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${list.completedCount}/${list.totalCount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: list.isFullyCompleted
                        ? AppTheme.successGreen
                        : context.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: context.textSecondary),
          onSelected: (value) {
            if (value == 'delete') {
              ref.read(taskRepositoryProvider).deleteList(coupleId, list.id);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                  const SizedBox(width: 8),
                  Text(strings.deleteList, style: const TextStyle(color: AppTheme.errorRed)),
                ],
              ),
            ),
          ],
        ),
        children: [
          Divider(height: 1, thickness: 0.6, color: context.outlineColor),

          // Items List
          if (list.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  strings.noItemsYet,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.items.length,
              itemBuilder: (context, i) {
                final item = list.items[i];
                return Dismissible(
                  key: Key('item_${item.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: AppTheme.errorRed.withOpacity(0.8),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                  ),
                  onDismissed: (_) {
                    ref.read(taskRepositoryProvider).removeChecklistItem(
                          coupleId,
                          list.id,
                          item.id,
                        );
                  },
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Checkbox(
                      value: item.isDone,
                      activeColor: AppTheme.primaryRose,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        ref.read(taskRepositoryProvider).toggleChecklistItem(
                              coupleId,
                              list.id,
                              item.id,
                              val ?? !item.isDone,
                            );
                      },
                    ),
                    title: Text(
                      item.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: item.isDone
                            ? context.textSecondary
                            : context.textPrimary,
                        decoration:
                            item.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.close_rounded, size: 16),
                      color: context.textSecondary.withOpacity(0.5),
                      onPressed: () {
                        ref.read(taskRepositoryProvider).removeChecklistItem(
                              coupleId,
                              list.id,
                              item.id,
                            );
                      },
                    ),
                  ),
                );
              },
            ),

          // Inline Add Item Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inlineController,
                    decoration: InputDecoration(
                      hintText: strings.addAnItem,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary.withOpacity(0.7),
                      ),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.outlineColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.outlineColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primaryRose),
                      ),
                    ),
                    onSubmitted: (text) {
                      _submitInlineItem(text, coupleId, list.id, myUid, inlineController);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryRose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                  ),
                  onPressed: () {
                    _submitInlineItem(
                      inlineController.text,
                      coupleId,
                      list.id,
                      myUid,
                      inlineController,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitInlineItem(
    String text,
    String coupleId,
    String listId,
    String myUid,
    TextEditingController controller,
  ) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    ref.read(taskRepositoryProvider).addChecklistItem(
          coupleId,
          listId,
          trimmed,
          myUid,
        );
    controller.clear();
  }

  // ==========================================
  // Dialogs & Sheets
  // ==========================================

  void _showAddTaskSheet(
    BuildContext context,
    String coupleId,
    String myUid,
    String? partnerUid,
    String partnerName,
  ) {
    final strings = AppStrings.of(context);
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'General';
    String? assignedTo;
    DateTime? selectedDueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.dialogBorderRadius)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.addTaskOrChore,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: strings.taskTitleLabel,
                        hintText: strings.taskTitleExample,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: strings.taskNotesLabel,
                        hintText: strings.taskNotesHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Selection
                    Text(
                      strings.categoryLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: TaskRepository.standardCategories.map((cat) {
                        final isSel = selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(_translateCategory(cat, strings)),
                          selected: isSel,
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() => selectedCategory = cat);
                            }
                          },
                          selectedColor: AppTheme.primaryRoseLight.withOpacity(0.3),
                          side: BorderSide(
                            color: isSel ? AppTheme.primaryRose : context.outlineColor,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Assignee Selection
                    Text(
                      strings.assignToLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: Text(strings.unassignedLabel),
                          selected: assignedTo == null,
                          onSelected: (_) => setSheetState(() => assignedTo = null),
                        ),
                        ChoiceChip(
                          label: Text(strings.meLabel),
                          selected: assignedTo == myUid,
                          onSelected: (_) => setSheetState(() => assignedTo = myUid),
                        ),
                        if (partnerUid != null)
                          ChoiceChip(
                            label: Text(partnerName),
                            selected: assignedTo == partnerUid,
                            onSelected: (_) => setSheetState(() => assignedTo = partnerUid),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Due Date Picker
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(
                            selectedDueDate == null
                                ? strings.setDueDate
                                : strings.dueOn(DateFormat(strings.isPortuguese ? 'd MMM, yyyy' : 'MMM d, yyyy', strings.isPortuguese ? 'pt_BR' : 'en_US').format(selectedDueDate!)),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDueDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) {
                              setSheetState(() => selectedDueDate = picked);
                            }
                          },
                        ),
                        if (selectedDueDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setSheetState(() => selectedDueDate = null),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                          ),
                        ),
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          final task = TaskModel(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: title,
                            description: descController.text.trim(),
                            assignedTo: assignedTo,
                            dueDate: selectedDueDate,
                            createdBy: myUid,
                            category: selectedCategory,
                          );

                          ref.read(taskRepositoryProvider).addTask(coupleId, task);
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          strings.saveTask,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      titleController.dispose();
      descController.dispose();
    });
  }

  void _showAddListSheet(BuildContext context, String coupleId, String myUid) {
    final strings = AppStrings.of(context);
    final titleController = TextEditingController();
    String selectedCategory = 'Shopping';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.dialogBorderRadius)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.createSharedChecklist,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: strings.listTitleLabel,
                        hintText: strings.listTitleExample,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      strings.categoryLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: TaskRepository.standardCategories.map((cat) {
                        final isSel = selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(_translateCategory(cat, strings)),
                          selected: isSel,
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() => selectedCategory = cat);
                            }
                          },
                          selectedColor: AppTheme.primaryRoseLight.withOpacity(0.3),
                          side: BorderSide(
                            color: isSel ? AppTheme.primaryRose : context.outlineColor,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                          ),
                        ),
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          final list = ChecklistModel(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: title,
                            category: selectedCategory,
                            items: const [],
                            updatedAt: DateTime.now(),
                          );

                          ref.read(taskRepositoryProvider).addList(coupleId, list);
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          strings.createListBtn,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      titleController.dispose();
    });
  }

  // ==========================================
  // Helper Widgets & Utilities
  // ==========================================

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppTheme.secondaryBlush),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'shopping':
        return Icons.shopping_basket_rounded;
      case 'errands':
        return Icons.directions_run_rounded;
      case 'romance':
        return Icons.favorite_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'health':
        return Icons.favorite_border_rounded;
      case 'finance':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'romance':
        return AppTheme.primaryRose;
      case 'shopping':
        return const Color(0xFFE65100);
      case 'travel':
        return const Color(0xFF0288D1);
      case 'home':
        return const Color(0xFF2E7D32);
      case 'finance':
        return const Color(0xFF6A1B9A);
      default:
        return AppTheme.tertiaryMauve;
    }
  }
}
