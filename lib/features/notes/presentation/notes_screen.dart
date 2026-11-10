import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_strings.dart';
import '../../auth/domain/couple_model.dart';
import '../../auth/data/pairing_repository.dart';
import '../domain/note_model.dart';
import '../data/note_repository.dart';
import '../../widgets/widget_sync_service.dart';
import 'scratch_and_doodle_widgets.dart';

/// Screen displaying the shared digital love notes / sticky notes wall.
///
/// Features a pastel sticky note grid, live widget pinning to Android Home Screen,
/// offline durability, and an interactive note editor.
class NotesScreen extends ConsumerStatefulWidget {
  final CoupleModel? initialCouple;
  final String? coupleId;
  final String? currentUid;

  const NotesScreen({
    super.key,
    this.initialCouple,
    this.coupleId,
    this.currentUid,
  });

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _getEffectiveUid() {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'guest_uid';
  }

  String _getUserDisplayName(CoupleModel? couple, String uid) {
    if (couple != null) {
      final myProfile = couple.getMyProfile(uid);
      if (myProfile != null && myProfile.name.isNotEmpty) {
        return myProfile.name;
      }
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    return 'Amor';
  }

  Color _parseNoteColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').replaceAll('0x', '');
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      } else if (clean.length == 8) {
        return Color(int.parse('0x$clean'));
      }
    } catch (_) {}
    return const Color(0xFFFFE082); // Default Warm Vanilla
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final effectiveUid = _getEffectiveUid();
    final activeCoupleId = widget.coupleId ??
        widget.initialCouple?.id ??
        ref.watch(currentCoupleIdProvider).valueOrNull ??
        '';

    if (activeCoupleId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(strings.loveNotesAndWidget),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.note_alt_outlined,
                  size: 64,
                  color: AppTheme.primaryRose.withOpacity(0.5),
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
    final currentCouple = coupleAsync.valueOrNull ?? widget.initialCouple;
    final notesAsync = ref.watch(notesStreamProvider(activeCoupleId));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.push_pin_rounded, color: AppTheme.primaryRose, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                strings.loveNotesAndWidget,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: strings.widgetInfo,
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showWidgetInfoDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryRose,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.edit_note_rounded),
        label: Text(
          strings.newNote,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showNoteEditor(
          context: context,
          coupleId: activeCoupleId,
          authorUid: effectiveUid,
          authorName: _getUserDisplayName(currentCouple, effectiveUid),
        ),
      ),
      body: notesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRose),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppTheme.errorRed),
                const SizedBox(height: 12),
                Text(
                  strings.isPortuguese
                      ? 'Falha ao carregar recados: $error'
                      : 'Failed to load sticky notes: $error',
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(notesStreamProvider(activeCoupleId)),
                  child: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return _buildEmptyState(
              context: context,
              coupleId: activeCoupleId,
              authorUid: effectiveUid,
              authorName: _getUserDisplayName(currentCouple, effectiveUid),
            );
          }

          return _buildNotesGrid(
            context: context,
            coupleId: activeCoupleId,
            effectiveUid: effectiveUid,
            authorName: _getUserDisplayName(currentCouple, effectiveUid),
            notes: notes,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required String coupleId,
    required String authorUid,
    required String authorName,
  }) {
    final strings = AppStrings.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: AppTheme.pastelPeach.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sticky_note_2_rounded,
                size: 72,
                color: AppTheme.primaryRose,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.noStickyNotesYet,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              strings.noStickyNotesDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                strings.leaveFirstLoveNote,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showNoteEditor(
                context: context,
                coupleId: coupleId,
                authorUid: authorUid,
                authorName: authorName,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesGrid({
    required BuildContext context,
    required String coupleId,
    required String effectiveUid,
    required String authorName,
    required List<NoteModel> notes,
  }) {
    return RefreshIndicator(
      color: AppTheme.primaryRose,
      onRefresh: () async {
        ref.invalidate(notesStreamProvider(coupleId));
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return _buildNoteCard(
            context: context,
            coupleId: coupleId,
            effectiveUid: effectiveUid,
            authorName: authorName,
            note: note,
          );
        },
      ),
    );
  }

  Widget _buildNoteCard({
    required BuildContext context,
    required String coupleId,
    required String effectiveUid,
    required String authorName,
    required NoteModel note,
  }) {
    final strings = AppStrings.of(context);
    final isPt = strings.isPortuguese;
    final noteColor = _parseNoteColor(note.colorHex);
    final isAuthor = note.authorUid == effectiveUid;
    final dateFormatted = DateFormat(
      isPt ? "d 'de' MMM, HH:mm" : 'MMM d, h:mm a',
      isPt ? 'pt_BR' : 'en_US',
    ).format(note.updatedAt);
    final isConcealedScratch = note.isScratchCard && !note.isScratched;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        onTap: () {
          if (isConcealedScratch) {
            showDialog<void>(
              context: context,
              builder: (_) => ScratchCardRevealDialog(
                title: note.title.isNotEmpty
                    ? note.title
                    : (isPt ? 'Raspadinha do Amor ✨' : 'Love Scratch Card ✨'),
                secretContent: note.content,
                authorName: note.authorName,
                drawingDataJson: note.drawingDataJson,
                onRevealed: () {
                  ref.read(noteRepositoryProvider).saveNote(
                        coupleId,
                        note.copyWith(isScratched: true),
                      );
                },
              ),
            );
          } else {
            _showNoteEditor(
              context: context,
              coupleId: coupleId,
              authorUid: effectiveUid,
              authorName: authorName,
              existingNote: note,
            );
          }
        },
        onLongPress: () => _showDeleteConfirmDialog(context, coupleId, note),
        child: Container(
          decoration: BoxDecoration(
            color: noteColor,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: note.isPinnedToWidget
                  ? AppTheme.primaryRose.withOpacity(0.8)
                  : Colors.black.withOpacity(0.06),
              width: note.isPinnedToWidget ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Pin badge & title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isNotEmpty
                          ? note.title
                          : (isPt ? 'Recadinho' : 'Love Note'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF2E221F),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final repo = ref.read(noteRepositoryProvider);
                      if (note.isPinnedToWidget) {
                        await repo.unpinNoteFromWidget(coupleId, note.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isPt ? 'Desafixado do Widget' : 'Unpinned from Home Widget'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        await repo.pinNoteToWidget(coupleId, note.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isPt ? 'Fixado no Widget do seu Amor! 💕' : 'Pinned to Partner\'s Home Widget! 💕'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: note.isPinnedToWidget
                            ? AppTheme.primaryRose
                            : Colors.black.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        note.isPinnedToWidget
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        size: 14,
                        color: note.isPinnedToWidget
                            ? Colors.white
                            : const Color(0xFF5A4944),
                      ),
                    ),
                  ),
                ],
              ),

              if (note.isPinnedToWidget) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRose.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.home_filled, size: 10, color: AppTheme.primaryRoseDark),
                      const SizedBox(width: 4),
                      Text(
                        isPt ? 'Widget na Tela Inicial 📌' : 'Glance Widget 📌',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryRoseDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // Content Body (Scratch Card vs Revealed Note + Optional Doodle)
              Expanded(
                child: isConcealedScratch
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFE29587),
                              Color(0xFFD66D75),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('✨💌✨', style: TextStyle(fontSize: 22)),
                            SizedBox(height: 6),
                            Text(
                              'Raspadinha Secreta!\nToque para raspar 💕',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (note.content.isNotEmpty)
                              Text(
                                note.content,
                                maxLines:
                                    (note.drawingDataJson ?? '').isNotEmpty
                                        ? 2
                                        : 5,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF3E312D),
                                  height: 1.35,
                                ),
                              ),
                            if ((note.drawingDataJson ?? '').isNotEmpty)
                              DoodleDisplayBox(
                                drawingDataJson: note.drawingDataJson!,
                                height: note.content.isNotEmpty ? 64 : 96,
                              ),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 8),

              // Footer: Author & Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isAuthor ? (isPt ? 'Você 💕' : 'You 💕') : note.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B5852),
                      ),
                    ),
                  ),
                  Text(
                    dateFormatted,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8D7A74),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoteEditor({
    required BuildContext context,
    required String coupleId,
    required String authorUid,
    required String authorName,
    NoteModel? existingNote,
  }) {
    final titleController = TextEditingController(text: existingNote?.title ?? '');
    final contentController = TextEditingController(text: existingNote?.content ?? '');
    String selectedColor = existingNote?.colorHex ?? NoteModel.presetColors.first;
    bool isPinned = existingNote?.isPinnedToWidget ?? false;
    bool isScratchCard = existingNote?.isScratchCard ?? false;
    String? drawingDataJson = existingNote?.drawingDataJson;
    bool showDoodleCanvas = (existingNote?.drawingDataJson ?? '').isNotEmpty;
    final strings = AppStrings.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final activeBgColor = _parseNoteColor(selectedColor);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.dialogBorderRadius),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
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

                      // Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            strings.isPortuguese
                                ? (existingNote == null ? 'Novo Recado' : 'Editar Recado')
                                : (existingNote == null ? 'New Sticky Note' : 'Edit Note'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          if (existingNote != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppTheme.errorRed),
                              tooltip: strings.isPortuguese ? 'Excluir Recado' : 'Delete Note',
                              onPressed: () async {
                                Navigator.pop(bottomSheetContext);
                                await _showDeleteConfirmDialog(
                                    context, coupleId, existingNote);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Pastel note preview card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: activeBgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: titleController,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E221F),
                              ),
                              decoration: InputDecoration(
                                hintText: strings.isPortuguese
                                    ? 'Título do recado (ex: Bom dia, meu amor)'
                                    : 'Note Title (e.g. Good morning my love)',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF8D7A74),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const Divider(color: Colors.black12, height: 16),
                            TextField(
                              controller: contentController,
                              maxLines: 6,
                              minLines: 3,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF3E312D),
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: strings.isPortuguese
                                    ? 'Escreva seu recadinho carinhoso, memória ou surpresa romântica aqui...'
                                    : 'Write a sweet note, memory, romantic surprise, or grocery reminder...',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF8D7A74),
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pastel Color Picker
                      Text(
                        strings.isPortuguese ? 'Cor do Recado' : 'Sticky Note Color',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: NoteModel.presetColors.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, idx) {
                            final colorHex = NoteModel.presetColors[idx];
                            final color = _parseNoteColor(colorHex);
                            final isSelected = colorHex == selectedColor;
                            final colorName = strings.isPortuguese
                                ? (NoteModel.colorNamesPt[colorHex] ?? 'Pastel')
                                : (NoteModel.colorNames[colorHex] ?? 'Pastel');

                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  selectedColor = colorHex;
                                });
                              },
                              child: Tooltip(
                                message: colorName,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primaryRose
                                          : Colors.black.withOpacity(0.12),
                                      width: isSelected ? 3 : 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.primaryRose
                                                  .withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 20,
                                          color: Color(0xFF2E221F),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Doodle Canvas Toggle & Pad ("Desenho na Tela 🎨")
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            strings.isPortuguese
                                ? 'Desenho à Mão Livre 🎨'
                                : 'Freehand Doodle 🎨',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(
                                () => showDoodleCanvas = !showDoodleCanvas,
                              );
                            },
                            icon: Icon(
                              showDoodleCanvas
                                  ? Icons.expand_less_rounded
                                  : Icons.brush_rounded,
                              size: 18,
                            ),
                            label: Text(
                              showDoodleCanvas
                                  ? 'Ocultar Quadro'
                                  : 'Desenhar Recado',
                            ),
                          ),
                        ],
                      ),
                      if (showDoodleCanvas) ...[
                        const SizedBox(height: 6),
                        InteractiveDoodlePad(
                          initialJson: drawingDataJson,
                          onChanged: (json) {
                            drawingDataJson = json;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Scratch Card Mode ("Raspadinha do Amor ✨")
                      SwitchListTile(
                        value: isScratchCard,
                        activeColor: AppTheme.primaryRose,
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: AppTheme.primaryRose,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.isPortuguese
                                  ? 'Enviar como Raspadinha Secreta ✨'
                                  : 'Send as Secret Scratch Card ✨',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          strings.isPortuguese
                              ? 'Oculta a mensagem sob uma camada dourada até seu amor raspar com o dedo'
                              : 'Hides the message under a scratchable foil layer until your partner scratches it',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            isScratchCard = val;
                          });
                        },
                      ),

                      // Glance Widget Pin Toggle
                      SwitchListTile(
                        value: isPinned,
                        activeColor: AppTheme.primaryRose,
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            const Icon(Icons.push_pin_rounded,
                                size: 18, color: AppTheme.primaryRose),
                            const SizedBox(width: 8),
                            Text(
                              strings.isPortuguese
                                  ? 'Fixar no Widget da Tela Inicial'
                                  : 'Pin to Home Screen Widget',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          strings.isPortuguese
                              ? 'Exibir este recado no widget da tela inicial do seu parceiro(a)'
                              : 'Show this note on your partner\'s Android Glance widget',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            isPinned = val;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRose,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.buttonBorderRadius,
                              ),
                            ),
                          ),
                          icon: Icon(
                            isPinned
                                ? Icons.push_pin_rounded
                                : Icons.check_circle_rounded,
                          ),
                          label: Text(
                            existingNote == null
                                ? (isPinned
                                    ? (strings.isPortuguese
                                        ? 'Salvar & Fixar no Widget'
                                        : 'Save & Pin to Widget')
                                    : (strings.isPortuguese
                                        ? 'Salvar Recado'
                                        : 'Save Note'))
                                : (isPinned
                                    ? (strings.isPortuguese
                                        ? 'Atualizar & Fixar'
                                        : 'Update & Pin')
                                    : (strings.isPortuguese
                                        ? 'Salvar Alterações'
                                        : 'Save Changes')),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final content = contentController.text.trim();

                            if (title.isEmpty &&
                                content.isEmpty &&
                                (drawingDataJson ?? '').isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    strings.isPortuguese
                                        ? 'Por favor, digite um recado ou faça um desenho.'
                                        : 'Please enter a note title, content, or drawing.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final note = NoteModel(
                              id: existingNote?.id ?? '',
                              title: title.isNotEmpty
                                  ? title
                                  : (strings.isPortuguese ? 'Recadinho' : 'Love Note'),
                              content: content,
                              colorHex: selectedColor,
                              isPinnedToWidget: isPinned,
                              authorUid: existingNote?.authorUid ?? authorUid,
                              authorName: existingNote?.authorName ?? authorName,
                              updatedAt: DateTime.now(),
                              isScratchCard: isScratchCard,
                              isScratched: isScratchCard ? false : true,
                              drawingDataJson: drawingDataJson,
                            );

                            final repo = ref.read(noteRepositoryProvider);
                            await repo.saveNote(coupleId, note);

                            if (existingNote?.isPinnedToWidget == true && !isPinned) {
                              await WidgetSyncService.clearGlanceNote();
                            }

                            if (bottomSheetContext.mounted) {
                              Navigator.pop(bottomSheetContext);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isPinned
                                      ? (strings.isPortuguese
                                          ? 'Recado salvo e fixado no widget! 💕'
                                          : 'Note saved & pinned to widget! 💕')
                                      : (strings.isPortuguese ? 'Recado salvo!' : 'Note saved!')),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      titleController.dispose();
      contentController.dispose();
    });
  }

  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    String coupleId,
    NoteModel note,
  ) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.dialogBorderRadius),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
            const SizedBox(width: 8),
            Text(strings.isPortuguese ? 'Excluir Recado?' : 'Delete Sticky Note?'),
          ],
        ),
        content: Text(
          strings.isPortuguese
              ? 'Tem certeza de que deseja excluir "${note.title.isNotEmpty ? note.title : 'este recado'}"?'
                  '${note.isPinnedToWidget ? ' Ele também será removido do seu widget.' : ''}'
              : 'Are you sure you want to delete "${note.title.isNotEmpty ? note.title : 'this note'}"?'
                  '${note.isPinnedToWidget ? ' It will also be cleared from your home screen widget.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repo = ref.read(noteRepositoryProvider);
      await repo.deleteNote(coupleId, note.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.isPortuguese
                  ? 'Recado excluído com sucesso'
                  : 'Sticky note deleted',
            ),
          ),
        );
      }
    }
  }

  void _showWidgetInfoDialog(BuildContext context) {
    final strings = AppStrings.of(context);
    final isPt = strings.isPortuguese;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.dialogBorderRadius),
        ),
        title: Row(
          children: [
            const Icon(Icons.widgets_rounded, color: AppTheme.primaryRose),
            const SizedBox(width: 8),
            Text(isPt ? 'Widgets do Android na Tela Inicial' : 'Android Glance Widget'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPt ? 'Como adicionar os widgets à sua tela inicial:' : 'How to add widgets to your Home Screen:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(isPt ? '1. Vá para a tela inicial do seu celular Android.' : '1. Go to your Android phone home screen.'),
            Text(isPt ? '2. Toque e segure em um espaço vazio.' : '2. Touch and hold an empty space on the home screen.'),
            Text(isPt ? '3. Toque em "Widgets" e procure por "Couple App".' : '3. Tap "Widgets" and find "Couple App".'),
            Text(isPt ? '4. Arraste o widget do casal ou de notas para sua tela.' : '4. Drag the widget to your screen.'),
            const SizedBox(height: 12),
            Text(
              isPt
                  ? 'Sempre que você ou seu amor fixarem uma nota ou atualizarem o app, o widget atualiza automaticamente! 💕'
                  : 'Whenever either partner pins a note in Krivo, the widget instantly updates with the new message! 💕',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isPt ? 'Entendi!' : 'Got it!'),
          ),
        ],
      ),
    );
  }
}
