import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/crypto/vault_crypto_service.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/pairing_repository.dart';
import '../../auth/domain/couple_model.dart';
import '../../cheatsheet/data/cheatsheet_repository.dart';
import '../../cheatsheet/domain/cheatsheet_model.dart';
import '../data/vault_repository.dart';
import '../domain/vault_config_model.dart';
import '../domain/vault_item_model.dart';

/// Screen providing a zero-knowledge AES-256-GCM encrypted private vault
/// alongside a shared romantic partner cheatsheet for sizes and preferences.
class VaultScreen extends ConsumerStatefulWidget {
  final CoupleModel? initialCouple;
  final String? coupleId;
  final String? currentUid;

  const VaultScreen({
    super.key,
    this.initialCouple,
    this.coupleId,
    this.currentUid,
  });

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final VaultCryptoService _cryptoService = VaultCryptoService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Active in-memory unlocked secret key (cleared on Lock Now)
  SecretKey? _unlockedKey;

  // PIN Lock Gate State
  String _enteredPin = '';
  String? _setupInitialPin;
  bool _isSettingUpPin = false;
  VaultPinMode _pinMode = VaultPinMode.createNew;
  VaultConfigModel? _remoteConfig;
  bool _isProcessingPin = false;
  String? _pinErrorMessage;
  bool _hasStoredPin = false;
  
  // Vault Feed State
  String _selectedCategory = 'All';

  // Cheatsheet Tab State: 0 = My Cheatsheet, 1 = Partner's Cheatsheet
  int _cheatsheetViewIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _checkSecuritySetup();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getActiveCoupleId() {
    return widget.coupleId ??
        widget.initialCouple?.id ??
        ref.read(currentCoupleIdProvider).valueOrNull ??
        '';
  }

  String _getEffectiveUid(CoupleModel? couple) {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    final providerUid = ref.read(currentUserUidProvider).valueOrNull;
    if (providerUid != null && providerUid.isNotEmpty) {
      return providerUid;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid.isNotEmpty) {
        return user.uid;
      }
    } catch (_) {}
    if (couple != null && couple.members.isNotEmpty) {
      return couple.members.first;
    }
    return '';
  }

  String _getPartnerUid(CoupleModel? couple, String effectiveUid) {
    if (couple != null) {
      final other = couple.getOtherUid(effectiveUid);
      if (other != null) return other;
      for (final m in couple.members) {
        if (m != effectiveUid) return m;
      }
    }
    return '';
  }

  Future<void> _checkSecuritySetup([String? explicitCoupleId]) async {
    final coupleId = (explicitCoupleId != null && explicitCoupleId.isNotEmpty)
        ? explicitCoupleId
        : _getActiveCoupleId();
    if (coupleId.isEmpty) return;

    try {
      final storedKey =
          await _secureStorage.read(key: 'vault_cached_key_$coupleId');
      final hasPinFlag =
          await _secureStorage.read(key: 'vault_has_pin_$coupleId');
      await _localAuth.isDeviceSupported();

      VaultPinMode resolvedMode =
          (storedKey != null || hasPinFlag == 'true')
              ? VaultPinMode.unlockSentinel
              : VaultPinMode.createNew;
      VaultConfigModel? remoteConfig;

      try {
        final repo = ref.read(vaultRepositoryProvider);
        remoteConfig = await repo.getVaultConfig(coupleId);
        if (remoteConfig != null) {
          resolvedMode = VaultPinMode.unlockSentinel;
        } else {
          resolvedMode = await repo.resolveVaultPinMode(coupleId);
        }
      } catch (e) {
        debugPrint('VaultScreen remote config check fallback: $e');
      }

      if (mounted) {
        final hadPin = _hasStoredPin;
        setState(() {
          _remoteConfig = remoteConfig;
          _pinMode = resolvedMode;
          _hasStoredPin = storedKey != null || hasPinFlag == 'true';
          _isSettingUpPin = resolvedMode == VaultPinMode.createNew;
        });
        if (_hasStoredPin &&
            resolvedMode == VaultPinMode.unlockSentinel &&
            !hadPin &&
            _unlockedKey == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _unlockedKey == null) {
              _unlockWithBiometrics(silentError: true);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('VaultScreen._checkSecuritySetup error: $e');
    }
  }

  Future<String> _getOrCreateSalt(String coupleId) async {
    return 'krivo_vault_salt_$coupleId';
  }

  void _onDigitPressed(String digit) {
    if (_isProcessingPin || _enteredPin.length >= 6) return;
    setState(() {
      _pinErrorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 6) {
      _handleCompletedPin();
    }
  }

  void _onBackspacePressed() {
    if (_isProcessingPin) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _pinErrorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _handleCompletedPin() async {
    if (_isProcessingPin) return;
    final coupleId = _getActiveCoupleId();
    final pin = _enteredPin;
    final strings = AppStrings.of(context);
    final repo = ref.read(vaultRepositoryProvider);

    if (_pinMode == VaultPinMode.createNew) {
      if (_setupInitialPin == null) {
        setState(() {
          _setupInitialPin = pin;
          _enteredPin = '';
        });
      } else if (pin == _setupInitialPin) {
        setState(() => _isProcessingPin = true);
        try {
          final salt = await _getOrCreateSalt(coupleId);
          final key = await _cryptoService.deriveKey(pin: pin, salt: salt);
          final sentinelPayload = await _cryptoService.encrypt(
            plaintext: VaultConfigModel.sentinelPlaintext,
            key: key,
          );
          final newConfig = VaultConfigModel(sentinel: sentinelPayload);
          await repo.saveVaultConfig(coupleId, newConfig);

          final exportedKey = await _cryptoService.exportKeyBytes(key);
          await _secureStorage.write(
            key: 'vault_cached_key_$coupleId',
            value: exportedKey,
          );
          await _secureStorage.write(
            key: 'vault_has_pin_$coupleId',
            value: 'true',
          );

          if (mounted) {
            setState(() {
              _unlockedKey = key;
              _remoteConfig = newConfig;
              _pinMode = VaultPinMode.unlockSentinel;
              _hasStoredPin = true;
              _isSettingUpPin = false;
              _isProcessingPin = false;
              _setupInitialPin = null;
              _enteredPin = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(strings.pinSetSuccess),
                backgroundColor: AppTheme.primaryRose,
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _isProcessingPin = false;
            _pinErrorMessage = strings.isPortuguese
                ? 'Falha ao processar chave. Tente novamente.'
                : 'Failed to derive key. Please try again.';
            _enteredPin = '';
            _setupInitialPin = null;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _pinErrorMessage = strings.pinMismatch;
          _enteredPin = '';
          _setupInitialPin = null;
        });
      }
      return;
    }

    // Unlock against shared Firestore sentinel OR legacy backfill against existing items
    setState(() => _isProcessingPin = true);
    try {
      final salt = await _getOrCreateSalt(coupleId);
      final derivedKey = await _cryptoService.deriveKey(pin: pin, salt: salt);

      if (_pinMode == VaultPinMode.legacyBackfill) {
        final existingItems = await repo.getAllVaultItemsOnce(coupleId);
        bool decryptedAny = existingItems.isEmpty;
        for (final item in existingItems) {
          try {
            await _cryptoService.decrypt(payload: item.payload, key: derivedKey);
            decryptedAny = true;
            break;
          } catch (_) {}
        }
        if (!decryptedAny) {
          if (!mounted) return;
          setState(() {
            _isProcessingPin = false;
            _pinErrorMessage = strings.incorrectPin;
            _enteredPin = '';
          });
          HapticFeedback.vibrate();
          return;
        }
        // Valid legacy PIN -> backfill shared sentinel
        final sentinelPayload = await _cryptoService.encrypt(
          plaintext: VaultConfigModel.sentinelPlaintext,
          key: derivedKey,
        );
        final backfilled = VaultConfigModel(sentinel: sentinelPayload);
        await repo.saveVaultConfig(coupleId, backfilled);
        _remoteConfig = backfilled;
      } else {
        final config = _remoteConfig ?? await repo.getVaultConfig(coupleId);
        if (config != null) {
          _remoteConfig = config;
          try {
            final check = await _cryptoService.decrypt(
              payload: config.sentinel,
              key: derivedKey,
            );
            if (check != VaultConfigModel.sentinelPlaintext) {
              throw const VaultCryptoException('Sentinel mismatch');
            }
          } catch (_) {
            if (!mounted) return;
            setState(() {
              _isProcessingPin = false;
              _pinErrorMessage = strings.incorrectPin;
              _enteredPin = '';
            });
            HapticFeedback.vibrate();
            return;
          }
        } else {
          final storedKey =
              await _secureStorage.read(key: 'vault_cached_key_$coupleId');
          if (storedKey != null) {
            final derivedKeyBytes =
                await _cryptoService.exportKeyBytes(derivedKey);
            if (derivedKeyBytes != storedKey) {
              if (!mounted) return;
              setState(() {
                _isProcessingPin = false;
                _pinErrorMessage = strings.incorrectPin;
                _enteredPin = '';
              });
              HapticFeedback.vibrate();
              return;
            }
          }
        }
      }

      // Cache verified key locally for biometrics
      final derivedKeyBytes = await _cryptoService.exportKeyBytes(derivedKey);
      await _secureStorage.write(
        key: 'vault_cached_key_$coupleId',
        value: derivedKeyBytes,
      );
      await _secureStorage.write(
        key: 'vault_has_pin_$coupleId',
        value: 'true',
      );

      if (mounted) {
        setState(() {
          _unlockedKey = derivedKey;
          _pinMode = VaultPinMode.unlockSentinel;
          _hasStoredPin = true;
          _isSettingUpPin = false;
          _isProcessingPin = false;
          _enteredPin = '';
          _pinErrorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingPin = false;
        _pinErrorMessage =
            '${strings.isPortuguese ? "Erro ao desbloquear" : "Unlock error"}: $e';
        _enteredPin = '';
      });
    }
  }

  Future<void> _unlockWithBiometrics({bool silentError = false}) async {
    final strings = AppStrings.of(context);
    final coupleId = _getActiveCoupleId();
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) {
        if (!silentError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                strings.isPortuguese
                    ? 'Biometria não disponível neste aparelho.'
                    : 'Biometrics not available on this device.',
              ),
            ),
          );
        }
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: strings.biometricScanReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        final cachedKeyBase64 =
            await _secureStorage.read(key: 'vault_cached_key_$coupleId');
        if (cachedKeyBase64 != null && cachedKeyBase64.isNotEmpty) {
          final key = _cryptoService.importKeyBytes(cachedKeyBase64);
          final config = _remoteConfig ??
              await ref.read(vaultRepositoryProvider).getVaultConfig(coupleId);
          if (config != null) {
            try {
              final check = await _cryptoService.decrypt(
                payload: config.sentinel,
                key: key,
              );
              if (check != VaultConfigModel.sentinelPlaintext) {
                throw const VaultCryptoException('Stale cached key');
              }
            } catch (_) {
              await _secureStorage.delete(key: 'vault_cached_key_$coupleId');
              if (mounted) {
                setState(() {
                  _hasStoredPin = false;
                  _pinErrorMessage = strings.isPortuguese
                      ? 'O PIN do casal foi alterado. Digite o novo PIN de 6 dígitos.'
                      : 'The couple PIN changed. Please enter the new 6-digit PIN.';
                });
              }
              return;
            }
          }
          if (mounted) {
            setState(() {
              _unlockedKey = key;
              _enteredPin = '';
              _pinErrorMessage = null;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  strings.isPortuguese
                      ? 'Digite seu PIN de 6 dígitos uma vez para ativar a biometria.'
                      : 'Please enter your 6-digit PIN once to enable biometric unlock.',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('VaultScreen._unlockWithBiometrics error: $e');
      if (!silentError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${strings.isPortuguese ? "Biometria indisponível" : "Biometric verification unavailable"}: $e'),
          ),
        );
      }
    }
  }

  void _lockVault() {
    final strings = AppStrings.of(context);
    setState(() {
      _unlockedKey = null;
      _enteredPin = '';
      _setupInitialPin = null;
      _pinErrorMessage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.vaultLocked),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String?>>(currentCoupleIdProvider, (previous, next) {
      final id = next.valueOrNull;
      if (id != null && id.isNotEmpty) {
        _checkSecuritySetup(id);
      }
    });

    final activeCoupleId = _getActiveCoupleId();
    final coupleAsync = activeCoupleId.isNotEmpty
        ? ref.watch(coupleStreamProvider(activeCoupleId))
        : null;
    final couple = coupleAsync?.value ?? widget.initialCouple;
    final effectiveUid = _getEffectiveUid(couple);
    final partnerUid = _getPartnerUid(couple, effectiveUid);

    final strings = AppStrings.of(context);
    final partnerProfile = couple?.getMyProfile(partnerUid);
    final partnerName =
        partnerProfile != null && partnerProfile.name.isNotEmpty
            ? partnerProfile.name
            : (strings.isPortuguese ? 'Seu Amor' : 'Partner');

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.vaultTitleBar),
        actions: [
          if (_tabController.index == 0 && _unlockedKey != null) ...[
            IconButton(
              tooltip: strings.isPortuguese ? 'Alterar PIN do Cofre' : 'Change Vault PIN',
              onPressed: () => _showChangePinDialog(activeCoupleId),
              icon: const Icon(Icons.password_rounded, size: 20),
            ),
            TextButton.icon(
              onPressed: _lockVault,
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text(strings.lockNow),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryRose,
              ),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppTheme.primaryRose,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: Icon(
                _unlockedKey != null
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
              ),
              text: strings.tabSecretVault,
            ),
            Tab(
              icon: const Icon(Icons.favorite_rounded),
              text: strings.tabPartnerCheatsheet,
            ),
          ],
        ),
      ),
      body: activeCoupleId.isEmpty
          ? Center(
              child: Text(strings.noSpaceConnectedDesc),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _unlockedKey == null
                    ? _buildLockGateView()
                    : _buildUnlockedVaultView(activeCoupleId, effectiveUid),
                _buildPartnerCheatsheetView(
                  activeCoupleId,
                  effectiveUid,
                  partnerUid,
                  couple,
                ),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(
        activeCoupleId,
        effectiveUid,
        couple,
        partnerName,
      ),
    );
  }

  Widget? _buildFloatingActionButton(
    String coupleId,
    String effectiveUid,
    CoupleModel? couple,
    String partnerName,
  ) {
    final strings = AppStrings.of(context);
    if (_tabController.index == 0) {
      if (_unlockedKey == null) return null;
      return FloatingActionButton.extended(
        heroTag: 'fab_add_vault_item',
        onPressed: () => _showAddVaultItemSheet(coupleId, effectiveUid),
        backgroundColor: AppTheme.primaryRose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.newSecret),
      );
    } else {
      // Cheatsheet Tab
      return FloatingActionButton.extended(
        heroTag: 'fab_edit_cheatsheet',
        onPressed: () => _showEditCheatsheetSheet(
          coupleId,
          _cheatsheetViewIndex == 0 ? effectiveUid : _getPartnerUid(couple, effectiveUid),
          _cheatsheetViewIndex == 0,
          partnerName,
        ),
        backgroundColor: AppTheme.primaryRose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: Text(
          _cheatsheetViewIndex == 0
              ? strings.editMyCheatsheet
              : strings.editPartnerCheatsheet(partnerName),
        ),
      );
    }
  }

  // ===========================================================================
  // TAB 1: LOCK GATE VIEW
  // ===========================================================================

  Widget _buildLockGateView() {
    final strings = AppStrings.of(context);
    final titleText = _pinMode == VaultPinMode.createNew
        ? (_setupInitialPin == null
            ? strings.pinSetupTitle
            : strings.pinConfirmTitle)
        : (_pinMode == VaultPinMode.legacyBackfill
            ? (strings.isPortuguese ? 'Confirmar PIN Atual' : 'Confirm Existing PIN')
            : strings.vaultPrivateTitle);

    final subtitleText = _pinMode == VaultPinMode.createNew
        ? (_setupInitialPin == null
            ? strings.pinSetupDesc
            : strings.pinConfirmDesc)
        : (_pinMode == VaultPinMode.legacyBackfill
            ? (strings.isPortuguese
                ? 'Digite o PIN de 6 dígitos já usado no Cofre para sincronizar a proteção entre os dois celulares.'
                : 'Enter your existing 6-digit Vault PIN to sync protection across both phones.')
            : strings.pinUnlockDesc);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRose.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_rounded,
                  color: AppTheme.primaryRose,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                titleText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // PIN Dots Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: isFilled ? 18 : 14,
                    height: isFilled ? 18 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? AppTheme.primaryRose
                          : Colors.transparent,
                      border: Border.all(
                        color: isFilled
                            ? AppTheme.primaryRose
                            : context.outlineColor,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              if (_pinErrorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _pinErrorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_isProcessingPin) ...[
                const SizedBox(height: 16),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.primaryRose,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Numeric Keypad
              _buildPinKeypad(context),
              if (!_isSettingUpPin && _hasStoredPin) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryRose,
                    side: BorderSide(color: AppTheme.primaryRose.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.fingerprint_rounded, size: 22),
                  label: Text(
                    strings.unlockWithBiometrics,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _unlockWithBiometrics(silentError: false),
                ),
              ],
              if (_pinMode != VaultPinMode.createNew) ...[
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => _confirmResetVault(_getActiveCoupleId()),
                  child: Text(
                    strings.isPortuguese
                        ? 'Esqueci o PIN / Resetar Cofre'
                        : 'Forgot PIN / Reset Vault',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinKeypad(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1', '2', '3'].map((d) => _buildKeypadButton(context, d)).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['4', '5', '6'].map((d) => _buildKeypadButton(context, d)).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['7', '8', '9'].map((d) => _buildKeypadButton(context, d)).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Biometric or empty
              SizedBox(
                width: 64,
                height: 64,
                child: (!_isSettingUpPin && _hasStoredPin)
                    ? IconButton(
                        icon: Icon(
                          Icons.fingerprint_rounded,
                          size: 32,
                          color: AppTheme.primaryRose,
                        ),
                        onPressed: _unlockWithBiometrics,
                      )
                    : const SizedBox.shrink(),
              ),
              _buildKeypadButton(context, '0'),
              // Backspace
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  icon: Icon(
                    Icons.backspace_outlined,
                    size: 24,
                    color: context.textSecondary,
                  ),
                  onPressed: _onBackspacePressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(BuildContext context, String digit) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.surfaceVariant,
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: UNLOCKED VAULT VIEW
  // ===========================================================================

  Widget _buildUnlockedVaultView(String coupleId, String currentUid) {
    final strings = AppStrings.of(context);
    final vaultItemsAsync = ref.watch(vaultItemsStreamProvider(coupleId));

    return vaultItemsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            strings.isPortuguese
                ? 'Erro ao carregar o cofre: $err'
                : 'Error loading vault: $err',
            style: const TextStyle(color: AppTheme.errorRed),
          ),
        ),
      ),
      data: (items) {
        final filteredItems = _selectedCategory == 'All'
            ? items
            : items.where((i) => i.category == _selectedCategory).toList();

        return Column(
          children: [
            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  'All',
                  ...VaultItemModel.standardCategories,
                ].map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(_translateVaultCategory(category, strings)),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryRose.withOpacity(0.18),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppTheme.primaryRose
                            : context.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Divider(height: 1, color: context.outlineColor),
            // Vault Items List
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_clock_outlined,
                              size: 56,
                              color: AppTheme.primaryRose.withOpacity(0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              strings.noEncryptedItemsYet,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.noEncryptedItemsDesc,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildVaultItemCard(coupleId, item);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVaultItemCard(String coupleId, VaultItemModel item) {
    final strings = AppStrings.of(context);
    IconData typeIcon;
    switch (item.type) {
      case VaultItemModel.typePassword:
        typeIcon = Icons.password_rounded;
        break;
      case VaultItemModel.typeDocument:
        typeIcon = Icons.description_rounded;
        break;
      case VaultItemModel.typeCode:
        typeIcon = Icons.qr_code_2_rounded;
        break;
      case VaultItemModel.typeNote:
      default:
        typeIcon = Icons.note_alt_rounded;
        break;
    }

    final formattedDate =
        DateFormat(strings.isPortuguese ? 'd MMM, yyyy' : 'MMM d, yyyy', strings.isPortuguese ? 'pt_BR' : 'en_US').format(item.updatedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryRose.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            typeIcon,
            color: AppTheme.primaryRose,
            size: 22,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _translateVaultCategory(item.category, strings),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.textSecondary,
        ),
        onTap: () => _showVaultItemDetailsSheet(coupleId, item),
      ),
    );
  }

  Future<void> _showVaultItemDetailsSheet(
    String coupleId,
    VaultItemModel item,
  ) async {
    final strings = AppStrings.of(context);
    String? decryptedText;
    bool isRevealed = false;
    bool hasDecryptionError = false;

    // Decrypt the item secret using active memory key
    try {
      if (_unlockedKey != null) {
        decryptedText = await _cryptoService.decrypt(
          payload: item.payload,
          key: _unlockedKey!,
        );
      }
    } catch (e) {
      hasDecryptionError = true;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.dialogBorderRadius)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.errorRed,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: Text(strings.deleteSecretTitle),
                              content: Text(
                                strings.deleteSecretConfirm(item.title),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, false),
                                  child: Text(strings.isPortuguese ? 'Cancelar' : 'Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.errorRed,
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, true),
                                  child: Text(strings.isPortuguese ? 'Excluir' : 'Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await ref
                                .read(vaultRepositoryProvider)
                                .deleteVaultItem(coupleId, item.id);
                            if (Navigator.canPop(bottomSheetContext)) {
                              Navigator.pop(bottomSheetContext);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(_translateVaultCategory(item.category, strings)),
                        backgroundColor: context.surfaceVariant,
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(_translateVaultType(item.type, strings)),
                        backgroundColor: context.surfaceVariant,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.secretContentLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.outlineColor),
                    ),
                    child: hasDecryptionError
                        ? Text(
                            strings.isPortuguese
                                ? 'Falha na descriptografia. Chave incompatível ou dados alterados.'
                                : 'Decryption failed. Key mismatch or tampered data.',
                            style: const TextStyle(color: AppTheme.errorRed),
                          )
                        : Text(
                            isRevealed
                                ? (decryptedText ?? (strings.isPortuguese ? 'Conteúdo vazio' : 'Empty secret'))
                                : '••••••••••••••••••••••',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: isRevealed ? null : 'Courier',
                              color: context.textPrimary,
                              letterSpacing: isRevealed ? null : 2,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasDecryptionError
                              ? null
                              : () {
                                  setSheetState(() {
                                    isRevealed = !isRevealed;
                                  });
                                },
                          icon: Icon(
                            isRevealed
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          label: Text(isRevealed ? strings.hide : strings.reveal),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (hasDecryptionError || decryptedText == null)
                              ? null
                              : () {
                                  Clipboard.setData(
                                    ClipboardData(text: decryptedText!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        strings.copiedToClipboard,
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(strings.copySecret),
                        ),
                      ),
                    ],
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

  void _showAddVaultItemSheet(String coupleId, String effectiveUid) {
    final strings = AppStrings.of(context);
    final titleController = TextEditingController();
    final secretController = TextEditingController();
    String selectedType = VaultItemModel.typeNote;
    String selectedCategory = 'Personal';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.dialogBorderRadius)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.newEncryptedSecret,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: strings.isPortuguese ? 'Título' : 'Title',
                        hintText: strings.isPortuguese
                            ? 'ex: Senha da Netflix, Bilhete de Amor, Código do Cofre'
                            : 'e.g. Netflix Password, Love Note, Safe Code',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: strings.isPortuguese ? 'Tipo' : 'Type',
                      ),
                      items: VaultItemModel.standardTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_translateVaultType(type, strings)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: strings.categoryLabel,
                      ),
                      items: VaultItemModel.standardCategories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(_translateVaultCategory(cat, strings)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: secretController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: strings.isPortuguese ? 'Texto Secreto' : 'Secret Plaintext',
                        hintText: strings.isPortuguese
                            ? 'Digite seu segredo. Ele será criptografado no seu aparelho com AES-256-GCM antes de ser salvo.'
                            : 'Enter your secret text. This is encrypted client-side with AES-256-GCM before sending.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              final secret = secretController.text.trim();
                              if (title.isEmpty || secret.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      strings.isPortuguese
                                          ? 'Por favor, informe o título e o conteúdo secreto.'
                                          : 'Please provide both a title and secret content.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (_unlockedKey == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(strings.vaultLocked),
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isSaving = true);
                              try {
                                final encryptedPayload =
                                    await _cryptoService.encrypt(
                                  plaintext: secret,
                                  key: _unlockedKey!,
                                );

                                final item = VaultItemModel(
                                  id: '',
                                  title: title,
                                  category: selectedCategory,
                                  type: selectedType,
                                  payload: encryptedPayload,
                                  createdBy: effectiveUid,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );

                                await ref
                                    .read(vaultRepositoryProvider)
                                    .saveVaultItem(coupleId, item);

                                if (Navigator.canPop(bottomSheetContext)) {
                                  Navigator.pop(bottomSheetContext);
                                }

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(strings.secretSaved),
                                    backgroundColor: AppTheme.primaryRose,
                                  ),
                                );
                              } catch (e) {
                                if (Navigator.canPop(bottomSheetContext)) {
                                  setSheetState(() => isSaving = false);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${strings.isPortuguese ? "Erro ao salvar" : "Error saving secret"}: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(strings.encryptAndSaveBtn),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      secretController.dispose();
    });
  }

  String _translateVaultCategory(String category, AppStrings strings) {
    if (!strings.isPortuguese) return category;
    switch (category) {
      case 'All':
        return 'Todos';
      case 'Personal':
        return 'Pessoal';
      case 'Passwords':
        return 'Senhas';
      case 'Financial':
        return 'Financeiro';
      case 'Romantic':
        return 'Romântico';
      case 'Important Codes':
        return 'Códigos Importantes';
      case 'Documents':
        return 'Documentos';
      case 'Other':
        return 'Outros';
      default:
        return category;
    }
  }

  String _translateVaultType(String type, AppStrings strings) {
    if (!strings.isPortuguese) return type.toUpperCase();
    switch (type.toLowerCase()) {
      case 'note':
        return 'NOTA';
      case 'password':
        return 'SENHA';
      case 'document':
        return 'DOCUMENTO';
      case 'code':
        return 'CÓDIGO';
      default:
        return type.toUpperCase();
    }
  }

  // ===========================================================================
  // TAB 2: PARTNER CHEATSHEET VIEW
  // ===========================================================================

  Widget _buildPartnerCheatsheetView(
    String coupleId,
    String effectiveUid,
    String partnerUid,
    CoupleModel? couple,
  ) {
    final targetUid =
        _cheatsheetViewIndex == 0 ? effectiveUid : partnerUid;
    final cheatsheetAsync = ref.watch(
      partnerCheatsheetStreamProvider((
        coupleId: coupleId,
        uid: targetUid,
      )),
    );

    final strings = AppStrings.of(context);
    final partnerProfile = couple?.getMyProfile(partnerUid);
    final partnerName =
        partnerProfile != null && partnerProfile.name.isNotEmpty
            ? partnerProfile.name
            : (strings.isPortuguese ? 'Seu Amor' : 'Partner');

    return Column(
      children: [
        // View Switcher (My Cheatsheet vs Partner's Cheatsheet)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment<int>(
                value: 0,
                label: Text(strings.cheatsheetMe),
                icon: const Icon(Icons.person_rounded),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text(strings.cheatsheetPartner(partnerName)),
                icon: const Icon(Icons.favorite_rounded),
              ),
            ],
            selected: {_cheatsheetViewIndex},
            onSelectionChanged: (newSelection) {
              setState(() {
                _cheatsheetViewIndex = newSelection.first;
              });
            },
          ),
        ),
        // Cheatsheet Card Grid
        Expanded(
          child: cheatsheetAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRose),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  '${strings.isPortuguese ? "Erro ao carregar o guia" : "Error loading cheatsheet"}: $err',
                  style: const TextStyle(color: AppTheme.errorRed),
                ),
              ),
            ),
            data: (cheatsheet) {
              final model = cheatsheet ?? PartnerCheatsheetModel(uid: targetUid);

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_cheatsheetViewIndex == 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.secondaryBlush.withValues(alpha: 0.15)
                              : AppTheme.pastelPeach.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.secondaryBlush.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility_rounded,
                              color: AppTheme.primaryRose,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                strings.cheatsheetVisibilityHint,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildCheatsheetCard(
                          emoji: '💍',
                          title: strings.ringSize,
                          value: model.ringSize,
                        ),
                        _buildCheatsheetCard(
                          emoji: '👟',
                          title: strings.shoeSize,
                          value: model.shoeSize,
                        ),
                        _buildCheatsheetCard(
                          emoji: '👗',
                          title: strings.clothingSize,
                          value: model.clothingSize,
                        ),
                        _buildCheatsheetCard(
                          emoji: '☕',
                          title: strings.favoriteCoffee,
                          value: model.coffeeOrder,
                        ),
                        _buildCheatsheetCard(
                          emoji: '🍕',
                          title: strings.comfortFood,
                          value: model.comfortFood,
                        ),
                        _buildCheatsheetCard(
                          emoji: '⚠️',
                          title: strings.allergiesDislikes,
                          value: model.allergies,
                        ),
                        _buildCheatsheetCard(
                          emoji: '🌸',
                          title: strings.favoriteFlowers,
                          value: model.favoriteFlowers,
                        ),
                        _buildCheatsheetCard(
                          emoji: '🎁',
                          title: strings.giftNotes,
                          value: model.notes,
                        ),
                      ],
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCheatsheetCard({
    required String emoji,
    required String title,
    required String? value,
  }) {
    final strings = AppStrings.of(context);
    final hasValue = value != null && value.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue
              ? AppTheme.primaryRose.withOpacity(0.25)
              : context.outlineColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
              Icon(
                hasValue ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 16,
                color: hasValue
                    ? AppTheme.successGreen
                    : context.textSecondary.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                hasValue ? value : strings.notSetYet,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                  fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                  color: hasValue
                      ? context.textPrimary
                      : context.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditCheatsheetSheet(
    String coupleId,
    String targetUid,
    bool isMyCheatsheet, [
    String? partnerName,
  ]) async {
    final strings = AppStrings.of(context);
    final pName = partnerName ?? (strings.isPortuguese ? 'Seu Amor' : 'Partner');
    final existing = await ref
        .read(cheatsheetRepositoryProvider)
        .getCheatsheet(coupleId, targetUid);

    final ringController =
        TextEditingController(text: existing?.ringSize ?? '');
    final shoeController =
        TextEditingController(text: existing?.shoeSize ?? '');
    final clothingController =
        TextEditingController(text: existing?.clothingSize ?? '');
    final coffeeController =
        TextEditingController(text: existing?.coffeeOrder ?? '');
    final comfortFoodController =
        TextEditingController(text: existing?.comfortFood ?? '');
    final allergiesController =
        TextEditingController(text: existing?.allergies ?? '');
    final flowersController =
        TextEditingController(text: existing?.favoriteFlowers ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    bool isSaving = false;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.dialogBorderRadius)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMyCheatsheet
                          ? strings.editMyCheatsheet
                          : strings.editPartnerCheatsheet(pName),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ringController,
                      decoration: InputDecoration(
                        labelText: '💍 ${strings.ringSize}',
                        hintText: strings.isPortuguese ? 'ex: 16, 17mm, aro 15' : 'e.g. 6.5, 17mm',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: shoeController,
                      decoration: InputDecoration(
                        labelText: '👟 ${strings.shoeSize}',
                        hintText: strings.isPortuguese ? 'ex: 37 BR / 38 BR' : 'e.g. US 8.5 / EU 39',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: clothingController,
                      decoration: InputDecoration(
                        labelText: '👗 / 👕 ${strings.clothingSize}',
                        hintText: strings.isPortuguese ? 'ex: P / M / 38 / 40' : 'e.g. Small / Medium / 32W',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: coffeeController,
                      decoration: InputDecoration(
                        labelText: '☕ ${strings.favoriteCoffee}',
                        hintText: strings.isPortuguese ? 'ex: Cappuccino com canela, expresso duplo' : 'e.g. Iced oat latte with vanilla syrup',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: comfortFoodController,
                      decoration: InputDecoration(
                        labelText: '🍕 ${strings.comfortFood}',
                        hintText: strings.isPortuguese ? 'ex: Pizza de calabresa, chocolate amargo' : 'e.g. Pepperoni pizza, dark chocolate',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: allergiesController,
                      decoration: InputDecoration(
                        labelText: '⚠️ ${strings.allergiesDislikes}',
                        hintText: strings.isPortuguese ? 'ex: Amendoim, lactose, frutos do mar' : 'e.g. Peanuts, lactose intolerance, cilantro',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: flowersController,
                      decoration: InputDecoration(
                        labelText: '🌸 ${strings.favoriteFlowers}',
                        hintText: strings.isPortuguese ? 'ex: Rosas vermelhas, orquídeas, lírios' : 'e.g. Peonies, white lilies, lavender scent',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '🎁 ${strings.giftNotes}',
                        hintText: strings.isPortuguese
                            ? 'ex: Coleciona discos de vinil, prefere joias de prata a ouro'
                            : 'e.g. Collects vinyl records, prefers silver over gold jewelry',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setSheetState(() => isSaving = true);
                              try {
                                final updated = PartnerCheatsheetModel(
                                  uid: targetUid,
                                  ringSize: ringController.text.trim().isEmpty
                                      ? null
                                      : ringController.text.trim(),
                                  shoeSize: shoeController.text.trim().isEmpty
                                      ? null
                                      : shoeController.text.trim(),
                                  clothingSize:
                                      clothingController.text.trim().isEmpty
                                          ? null
                                          : clothingController.text.trim(),
                                  coffeeOrder:
                                      coffeeController.text.trim().isEmpty
                                          ? null
                                          : coffeeController.text.trim(),
                                  comfortFood:
                                      comfortFoodController.text.trim().isEmpty
                                          ? null
                                          : comfortFoodController.text.trim(),
                                  allergies:
                                      allergiesController.text.trim().isEmpty
                                          ? null
                                          : allergiesController.text.trim(),
                                  favoriteFlowers:
                                      flowersController.text.trim().isEmpty
                                          ? null
                                          : flowersController.text.trim(),
                                  notes: notesController.text.trim().isEmpty
                                      ? null
                                      : notesController.text.trim(),
                                  updatedAt: DateTime.now(),
                                );

                                await ref
                                    .read(cheatsheetRepositoryProvider)
                                    .saveCheatsheet(coupleId, updated);

                                if (Navigator.canPop(sheetCtx)) {
                                  Navigator.pop(sheetCtx);
                                }

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(strings.cheatsheetSaved),
                                    backgroundColor: AppTheme.primaryRose,
                                  ),
                                );
                              } catch (e) {
                                if (Navigator.canPop(sheetCtx)) {
                                  setSheetState(() => isSaving = false);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${strings.isPortuguese ? "Erro ao salvar" : "Error saving"}: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(strings.saveCheatsheet),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      ringController.dispose();
      shoeController.dispose();
      clothingController.dispose();
      coffeeController.dispose();
      comfortFoodController.dispose();
      allergiesController.dispose();
      flowersController.dispose();
      notesController.dispose();
    });
  }

  Future<void> _showChangePinDialog(String coupleId) async {
    final strings = AppStrings.of(context);
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isSaving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: Text(strings.isPortuguese ? 'Alterar PIN do Cofre' : 'Change Vault PIN'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: strings.isPortuguese ? 'PIN Atual (6 dígitos)' : 'Current PIN (6 digits)',
                      ),
                    ),
                    TextField(
                      controller: newController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: strings.isPortuguese ? 'Novo PIN (6 dígitos)' : 'New PIN (6 digits)',
                      ),
                    ),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: strings.isPortuguese ? 'Confirmar Novo PIN' : 'Confirm New PIN',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(color: AppTheme.errorRed, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final cur = currentController.text.trim();
                          final next = newController.text.trim();
                          final conf = confirmController.text.trim();
                          if (cur.length != 6 || next.length != 6) {
                            setDlgState(() => errorText = strings.isPortuguese
                                ? 'Os PINs devem ter exatamente 6 dígitos.'
                                : 'PINs must be exactly 6 digits.');
                            return;
                          }
                          if (next != conf) {
                            setDlgState(() => errorText = strings.pinMismatch);
                            return;
                          }
                          setDlgState(() {
                            isSaving = true;
                            errorText = null;
                          });
                          try {
                            final salt = await _getOrCreateSalt(coupleId);
                            final curKey = await _cryptoService.deriveKey(pin: cur, salt: salt);
                            final repo = ref.read(vaultRepositoryProvider);
                            final config = _remoteConfig ?? await repo.getVaultConfig(coupleId);
                            if (config != null) {
                              final check = await _cryptoService.decrypt(
                                payload: config.sentinel,
                                key: curKey,
                              );
                              if (check != VaultConfigModel.sentinelPlaintext) {
                                throw const VaultCryptoException('Wrong current PIN');
                              }
                            }
                            final newKey = await _cryptoService.deriveKey(pin: next, salt: salt);
                            final allItems = await repo.getAllVaultItemsOnce(coupleId);
                            final reencrypted = <VaultItemModel>[];
                            for (final item in allItems) {
                              final plain = await _cryptoService.decrypt(
                                payload: item.payload,
                                key: curKey,
                              );
                              final newPayload = await _cryptoService.encrypt(
                                plaintext: plain,
                                key: newKey,
                              );
                              reencrypted.add(
                                item.copyWith(
                                  payload: newPayload,
                                  updatedAt: DateTime.now(),
                                ),
                              );
                            }
                            final newSentinel = await _cryptoService.encrypt(
                              plaintext: VaultConfigModel.sentinelPlaintext,
                              key: newKey,
                            );
                            final newConfig = VaultConfigModel(sentinel: newSentinel);
                            await repo.reencryptAllItemsAndSentinel(
                              coupleId,
                              reencryptedItems: reencrypted,
                              newConfig: newConfig,
                            );
                            final exported = await _cryptoService.exportKeyBytes(newKey);
                            await _secureStorage.write(
                              key: 'vault_cached_key_$coupleId',
                              value: exported,
                            );
                            if (mounted) {
                              setState(() {
                                _unlockedKey = newKey;
                                _remoteConfig = newConfig;
                              });
                            }
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    strings.isPortuguese
                                        ? 'PIN alterado e segredos re-criptografados com sucesso! 🔐'
                                        : 'PIN changed and all secrets re-encrypted! 🔐',
                                  ),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            }
                          } catch (_) {
                            setDlgState(() {
                              isSaving = false;
                              errorText = strings.incorrectPin;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(strings.save),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
    });
  }

  Future<void> _confirmResetVault(String coupleId) async {
    final strings = AppStrings.of(context);
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Resetar Cofre Privado?' : 'Reset Private Vault?'),
        content: Text(
          strings.isPortuguese
              ? 'Como o Cofre usa criptografia de conhecimento zero, não é possível recuperar o PIN. Resetar vai APAGAR PERMANENTEMENTE todos os segredos salvos pelo casal.'
              : 'Because the Vault uses zero-knowledge encryption, PINs cannot be recovered. Resetting will PERMANENTLY DELETE all saved secrets for the couple.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.isPortuguese ? 'Continuar' : 'Continue'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.isPortuguese ? 'Confirmação Final ⚠️' : 'Final Confirmation ⚠️'),
        content: Text(
          strings.isPortuguese
              ? 'Tem certeza absoluta? Todos os itens do Cofre serão apagados para que vocês possam criar um novo PIN compartilhado.'
              : 'Are you absolutely sure? Every Vault item will be wiped so you can create a fresh shared PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.isPortuguese ? 'Apagar Tudo e Resetar' : 'Wipe All & Reset'),
          ),
        ],
      ),
    );
    if (secondConfirm != true || !mounted) return;

    try {
      await ref.read(vaultRepositoryProvider).resetVault(coupleId);
      await _secureStorage.delete(key: 'vault_cached_key_$coupleId');
      await _secureStorage.delete(key: 'vault_has_pin_$coupleId');
      if (mounted) {
        setState(() {
          _unlockedKey = null;
          _remoteConfig = null;
          _hasStoredPin = false;
          _pinMode = VaultPinMode.createNew;
          _isSettingUpPin = true;
          _setupInitialPin = null;
          _enteredPin = '';
          _pinErrorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.isPortuguese
                  ? 'Cofre resetado. Crie um novo PIN compartilhado de 6 dígitos.'
                  : 'Vault reset. Create a new shared 6-digit PIN.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao resetar Cofre: $e')),
        );
      }
    }
  }
}
