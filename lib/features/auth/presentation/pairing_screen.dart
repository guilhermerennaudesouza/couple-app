import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/theme_provider.dart';

import '../data/pairing_repository.dart';
import '../domain/couple_model.dart';

class PairingScreen extends ConsumerStatefulWidget {
  final VoidCallback? onPairedSuccess;

  const PairingScreen({
    super.key,
    this.onPairedSuccess,
  });

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Create Space Form
  final _createFormKey = GlobalKey<FormState>();
  final _createNameController = TextEditingController();
  DateTime _selectedAnniversary = DateTime.now();
  bool _isCreating = false;
  CoupleModel? _createdCouple;

  // Join Space Form
  final _joinFormKey = GlobalKey<FormState>();
  final _joinNameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrapAnonymousAuth();
  }

  Future<void> _bootstrapAnonymousAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('PairingScreen anonymous auth error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _createNameController.dispose();
    _joinNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<String> _ensureAuthenticatedUid() async {
    final existing = FirebaseAuth.instance.currentUser?.uid;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final credential = await FirebaseAuth.instance.signInAnonymously();
    final uid = credential.user?.uid;
    if (uid == null || uid.isEmpty) {
      throw const PairingException(
        'Não foi possível autenticar no servidor. Verifique sua internet e tente novamente.',
      );
    }
    return uid;
  }

  Future<void> _handleCreateCouple() async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    try {
      final uid = await _ensureAuthenticatedUid();
      final repository = ref.read(pairingRepositoryProvider);
      final couple = await repository.createCouple(
        uid,
        _createNameController.text.trim(),
        _selectedAnniversary,
      );

      if (mounted) {
        setState(() {
          _createdCouple = couple;
          _isCreating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final strings = AppStrings.of(context);
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.isPortuguese ? 'Erro ao criar espaço: $e' : 'Error creating couple space: $e'),
            backgroundColor: AppTheme.primaryRose,
          ),
        );
      }
    }
  }

  Future<void> _handleJoinCouple() async {
    if (!_joinFormKey.currentState!.validate()) return;
    setState(() => _isJoining = true);

    try {
      final uid = await _ensureAuthenticatedUid();
      final repository = ref.read(pairingRepositoryProvider);
      await repository.joinCouple(
        _joinCodeController.text.trim(),
        uid,
        _joinNameController.text.trim(),
      );

      if (mounted) {
        final strings = AppStrings.of(context);
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.isPortuguese ? 'Conectado(a) com seu parceiro(a) com sucesso! 🎉' : 'Successfully connected with your partner! 🎉'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        widget.onPairedSuccess?.call();
      }
    } on PairingException catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.primaryRose,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final strings = AppStrings.of(context);
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.isPortuguese ? 'Falha ao entrar no espaço: $e' : 'Failed to join couple space: $e'),
            backgroundColor: AppTheme.primaryRose,
          ),
        );
      }
    }
  }

  Future<void> _pickAnniversaryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedAnniversary,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = context.isDarkMode;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppTheme.primaryRose,
                    onPrimary: Colors.white,
                    surface: AppTheme.surfaceDark,
                    onSurface: context.textPrimary,
                  )
                : ColorScheme.light(
                    primary: AppTheme.primaryRose,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: context.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedAnniversary = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).pairingTitle),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).theme,
            icon: Icon(
              context.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppTheme.primaryRose,
              size: 20,
            ),
            onPressed: () {
              final current = ref.read(themeModeProvider);
              final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              ref.read(themeModeProvider.notifier).setThemeMode(next);
            },
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryRose,
            ),
            onPressed: () {
              ref.read(localeProvider.notifier).toggleLanguage();
            },
            icon: const Icon(Icons.language_rounded, size: 18),
            label: Text(
              ref.watch(localeProvider).languageCode == 'pt' ? '🇧🇷 PT' : '🇺🇸 EN',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryRose,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: context.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: AppStrings.of(context).tabCreate, icon: const Icon(Icons.favorite_outline_rounded)),
            Tab(text: AppStrings.of(context).tabJoin, icon: const Icon(Icons.link_rounded)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCreateTab(AppStrings.of(context)),
            _buildJoinTab(AppStrings.of(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTab(AppStrings strings) {
    if (_createdCouple != null) {
      return _buildWaitingForPartnerView(_createdCouple!, strings);
    }

    final formattedDate = DateFormat.yMMMMd(
      strings.isPortuguese ? 'pt_BR' : 'en_US',
    ).format(_selectedAnniversary);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _createFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: AppTheme.primaryRose,
              size: 56,
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            Text(
              strings.pairingTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.pairingSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _createNameController,
              decoration: InputDecoration(
                labelText: strings.yourNameLabel,
                hintText: strings.yourNameHint,
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return strings.isPortuguese ? 'Por favor, digite seu nome' : 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _pickAnniversaryDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: context.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cake_outlined,
                      color: AppTheme.primaryRose,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.anniversaryLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.calendar_today_rounded, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isCreating ? null : _handleCreateCouple,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      strings.createSpaceBtn,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForPartnerView(CoupleModel initialCouple, AppStrings strings) {
    final coupleAsync = ref.watch(coupleStreamProvider(initialCouple.id));

    return coupleAsync.when(
      data: (couple) {
        final currentCouple = couple ?? initialCouple;

        if (currentCouple.isFull) {
          final myUid = ref.watch(currentUserUidProvider).valueOrNull ??
              (currentCouple.members.isNotEmpty ? currentCouple.members.first : '');
          final other = currentCouple.getPartnerProfile(myUid);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.celebration_rounded,
                    color: AppTheme.successGreen,
                    size: 72,
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 20),
                  Text(
                    strings.isPortuguese
                        ? 'Você está conectado(a) com ${other?.name ?? "seu amor"}!'
                        : 'You are paired with ${other?.name ?? "your partner"}!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.isPortuguese
                        ? 'Seu espaço a dois está pronto.'
                        : 'Your private space is ready.',
                    style: TextStyle(color: context.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => widget.onPairedSuccess?.call(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(strings.isPortuguese ? 'Entrar no Nosso Espaço' : 'Enter Our Space'),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                strings.isPortuguese ? 'Compartilhe com seu amor' : 'Share With Your Partner',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.isPortuguese
                    ? 'Peça ao seu parceiro(a) para digitar este código de 6 dígitos no app dele(a).'
                    : 'Ask your partner to enter this 6-digit code or scan the QR code in their app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              // Code display card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBlush.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                  border: Border.all(
                    color: AppTheme.primaryRose.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      strings.isPortuguese ? 'CÓDIGO DE PAREAMENTO' : 'PAIRING CODE',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppTheme.primaryRose,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentCouple.inviteCode,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: AppTheme.primaryRose,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: currentCouple.inviteCode),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(strings.copied),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(strings.isPortuguese ? 'Copiar Código' : 'Copy Code'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryRose,
                        side: const BorderSide(color: AppTheme.primaryRose),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Scannable QR code container
              Center(
                child: Container(
                  width: 192,
                  height: 192,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: 'coupleapp://join?code=${currentCouple.inviteCode}',
                    version: QrVersions.auto,
                    size: 164,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF2B2B2B),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Live waiting status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryMauve.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.tertiaryMauve,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      strings.isPortuguese
                          ? 'Aguardando seu parceiro(a) entrar...'
                          : 'Waiting for your partner to join...',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.tertiaryMauve,
                      ),
                    ),
                  ],
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(
                    begin: 0.7,
                    end: 1.0,
                    duration: 1500.ms,
                  ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          strings.isPortuguese ? 'Erro: $err' : 'Error: $err',
        ),
      ),
    );
  }

  Widget _buildJoinTab(AppStrings strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _joinFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.link_rounded,
              color: AppTheme.primaryRose,
              size: 56,
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            Text(
              strings.joinSpaceBtn,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.waitingPartnerBanner,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _joinNameController,
              decoration: InputDecoration(
                labelText: strings.yourNameLabel,
                hintText: strings.yourNameHint,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return strings.isPortuguese ? 'Por favor, digite seu nome' : 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _joinCodeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: AppTheme.primaryRose,
              ),
              decoration: InputDecoration(
                labelText: strings.enterInviteCodeLabel,
                hintText: '000000',
                counterText: '',
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (value) {
                if (value == null || value.trim().length != 6) {
                  return strings.isPortuguese ? 'Digite o código de 6 dígitos completo' : 'Enter the full 6-digit code';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isJoining ? null : () => _openQrScanner(context),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                strings.isPortuguese ? 'Escanear QR Code' : 'Scan QR Code',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryRose,
                side: const BorderSide(color: AppTheme.primaryRose),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isJoining ? null : _handleJoinCouple,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isJoining
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      strings.joinSpaceBtn,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQrScanner(BuildContext context) async {
    final strings = AppStrings.of(context);
    bool handled = false;

    final scannedCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * 0.65,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.outlineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  strings.isPortuguese
                      ? 'Aponte a câmera para o QR Code do seu par'
                      : 'Point the camera at your partner\'s QR code',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: MobileScanner(
                      onDetect: (capture) {
                        if (handled) return;
                        for (final barcode in capture.barcodes) {
                          final raw = barcode.rawValue;
                          if (raw == null) continue;
                          final parsed = PairingRepository.parseInviteCodeFromQr(raw);
                          if (parsed != null) {
                            handled = true;
                            Navigator.of(sheetCtx).pop(parsed);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (scannedCode != null && mounted) {
      setState(() {
        _joinCodeController.text = scannedCode;
      });
    }
  }
}
