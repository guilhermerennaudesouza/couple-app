import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/l10n/locale_provider.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/core/widgets/partner_avatar_widget.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';

/// Opens the Couple Profile & Avatar editing modal bottom sheet.
Future<void> showEditCoupleProfileSheet(
  BuildContext context, {
  required String coupleId,
  required CoupleModel couple,
  required String myUid,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _EditCoupleProfileSheet(
      coupleId: coupleId,
      couple: couple,
      myUid: myUid,
    ),
  );
}

class _EditCoupleProfileSheet extends ConsumerStatefulWidget {
  final String coupleId;
  final CoupleModel couple;
  final String myUid;

  const _EditCoupleProfileSheet({
    required this.coupleId,
    required this.couple,
    required this.myUid,
  });

  @override
  ConsumerState<_EditCoupleProfileSheet> createState() =>
      _EditCoupleProfileSheetState();
}

class _EditCoupleProfileSheetState
    extends ConsumerState<_EditCoupleProfileSheet> {
  late final TextEditingController _nameController;
  late DateTime _selectedAnniversary;
  String? _avatarUrl;
  bool _clearAvatar = false;
  bool _isSaving = false;
  bool _isPickingPhoto = false;

  @override
  void initState() {
    super.initState();
    final myProfile = widget.couple.getMyProfile(widget.myUid);
    _nameController = TextEditingController(text: myProfile?.name ?? '');
    _avatarUrl = myProfile?.avatarUrl;
    _selectedAnniversary = widget.couple.anniversaryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final strings = AppStrings.of(context);
    setState(() => _isPickingPhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!PairingRepository.isValidAvatarDataUri(dataUri)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.avatarTooLargeError),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _avatarUrl = dataUri;
          _clearAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${strings.isPortuguese ? 'Erro ao escolher foto:' : 'Failed to pick photo:'} $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  Future<void> _pickAnniversaryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedAnniversary,
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedAnniversary = picked);
    }
  }

  Future<void> _save() async {
    final strings = AppStrings.of(context);
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.profileNameRequired),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      HapticFeedback.lightImpact();
      final repo = ref.read(pairingRepositoryProvider);
      await repo.updatePartnerProfile(
        widget.coupleId,
        widget.myUid,
        name: trimmedName,
        avatarUrl: _clearAvatar ? null : _avatarUrl,
        clearAvatar: _clearAvatar,
      );

      final orig = widget.couple.anniversaryDate;
      final anniversaryChanged = orig.year != _selectedAnniversary.year ||
          orig.month != _selectedAnniversary.month ||
          orig.day != _selectedAnniversary.day;
      if (anniversaryChanged) {
        await repo.updateAnniversaryDate(
          widget.coupleId,
          _selectedAnniversary,
          isPortuguese: strings.isPortuguese,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.profileUpdatedSuccess),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${strings.isPortuguese ? 'Erro ao salvar perfil:' : 'Failed to save profile:'} $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final locale = ref.watch(localeProvider);
    final formattedAnniv =
        DateFormat.yMMMMd(locale.toString()).format(_selectedAnniversary);

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.outlineColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.editCoupleProfileTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  PartnerAvatarWidget(
                    name: _nameController.text.isEmpty
                        ? 'Eu'
                        : _nameController.text,
                    avatarUrl: _clearAvatar ? null : _avatarUrl,
                    radius: 44,
                    showBorder: true,
                  ),
                  Material(
                    color: AppTheme.primaryRose,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isPickingPhoto ? null : _pickAvatar,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _isPickingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _isPickingPhoto ? null : _pickAvatar,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(strings.choosePhotoBtn),
                ),
                if (_avatarUrl != null && !_clearAvatar)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _clearAvatar = true;
                        _avatarUrl = null;
                      });
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppTheme.errorRed,
                    ),
                    label: Text(
                      strings.removePhotoBtn,
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 32,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: strings.myDisplayNameLabel,
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: context.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickAnniversaryDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: AppTheme.primaryRose,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.anniversary,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedAnniv,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryRose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                strings.saveProfileBtn,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
