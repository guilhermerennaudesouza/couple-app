import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/core/widgets/partner_avatar_widget.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

typedef ReclaimSlotCallback = Future<void> Function({
  String? replacingOldUid,
  String? fallbackName,
});

/// Shown automatically when a device has a saved `coupleId` whose document
/// loaded from Firestore, but the current Firebase Auth UID is no longer in
/// `couple.members` (preventing silent `permission-denied` errors everywhere).
class SessionRecoveryScreen extends ConsumerStatefulWidget {
  final CoupleModel couple;
  final String myUid;
  final ReclaimSlotCallback? onReclaimSlot;
  final Future<void> Function()? onUnpair;

  const SessionRecoveryScreen({
    super.key,
    required this.couple,
    required this.myUid,
    this.onReclaimSlot,
    this.onUnpair,
  });

  @override
  ConsumerState<SessionRecoveryScreen> createState() =>
      _SessionRecoveryScreenState();
}

class _SessionRecoveryScreenState extends ConsumerState<SessionRecoveryScreen> {
  bool _isWorking = false;
  String? _busyUid;

  Future<void> _reclaim({String? replacingOldUid, String? fallbackName}) async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _busyUid = replacingOldUid ?? '__open_slot__';
    });

    try {
      if (widget.onReclaimSlot != null) {
        await widget.onReclaimSlot!(
          replacingOldUid: replacingOldUid,
          fallbackName: fallbackName,
        );
      } else {
        final repo = ref.read(pairingRepositoryProvider);
        await repo.reclaimPartnerSlot(
          widget.couple.id,
          newUid: widget.myUid,
          replacingOldUid: replacingOldUid,
          fallbackName: fallbackName,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final isPt = AppStrings.of(context).isPortuguese;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isPt ? 'Não foi possível reconectar:' : 'Failed to reconnect:'} $e',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _busyUid = null;
        });
      }
    }
  }

  Future<void> _handleUnpair() async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _busyUid = '__unpair__';
    });

    try {
      if (widget.onUnpair != null) {
        await widget.onUnpair!();
      } else {
        final repo = ref.read(pairingRepositoryProvider);
        await repo.unpairCurrentUser(widget.couple.id, widget.myUid);
        await WidgetSyncService.clearAllWidgets();
        ref.invalidate(currentCoupleIdProvider);
      }
    } catch (e) {
      if (!mounted) return;
      final isPt = AppStrings.of(context).isPortuguese;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isPt ? 'Erro ao desconectar:' : 'Failed to disconnect:'} $e',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _busyUid = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPt = AppStrings.of(context).isPortuguese;
    final members = widget.couple.members;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRose.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sync_lock_rounded,
                        color: AppTheme.primaryRose,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isPt ? 'Reconectar sua sessão' : 'Reconnect your session',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isPt
                        ? 'A sessão deste aparelho perdeu o vínculo com o espaço do casal. Toque no seu perfil abaixo para reconectar sem perder seus dados:'
                        : 'This device session lost its link to the couple space. Tap your profile below to reconnect without losing data:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final memberUid in members) ...[
                    _buildProfileCard(context, memberUid, isPt),
                    const SizedBox(height: 12),
                  ],
                  if (!widget.couple.isFull) ...[
                    FilledButton.icon(
                      onPressed: _isWorking
                          ? null
                          : () => _reclaim(
                                fallbackName: isPt ? 'Você' : 'You',
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryRose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.buttonBorderRadius),
                        ),
                      ),
                      icon: _busyUid == '__open_slot__'
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.favorite_rounded),
                      label: Text(
                        isPt
                            ? 'Entrar novamente neste espaço'
                            : 'Rejoin this couple space',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isWorking ? null : _handleUnpair,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.buttonBorderRadius),
                      ),
                    ),
                    icon: _busyUid == '__unpair__'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link_off_rounded, size: 18),
                    label: Text(
                      isPt
                          ? 'Desconectar e parear com outro código'
                          : 'Disconnect and pair with another code',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, String memberUid, bool isPt) {
    final profile = widget.couple.partnerProfiles[memberUid];
    final displayName = (profile?.displayName.trim().isNotEmpty == true)
        ? profile!.displayName.trim()
        : (isPt ? 'Parceiro(a)' : 'Partner');
    final isThisBusy = _busyUid == memberUid;

    return Material(
      color: context.surfaceVariant,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _isWorking ? null : () => _reclaim(replacingOldUid: memberUid),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              PartnerAvatarWidget(
                name: displayName,
                avatarUrl: profile?.avatarUrl,
                radius: 24,
                showBorder: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPt
                          ? 'Toque para reconectar como este perfil'
                          : 'Tap to reconnect as this profile',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isThisBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppTheme.primaryRose,
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRose.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isPt ? 'Sou eu' : 'This is me',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryRose,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
