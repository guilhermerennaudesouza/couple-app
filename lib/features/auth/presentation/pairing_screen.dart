import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _createNameController.dispose();
    _joinNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  late final String _fallbackUid = 'user_${DateTime.now().millisecondsSinceEpoch}';

  String _getEffectiveUid() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? _fallbackUid;
  }

  Future<void> _handleCreateCouple() async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    try {
      final repository = ref.read(pairingRepositoryProvider);
      final couple = await repository.createCouple(
        _getEffectiveUid(),
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
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating couple space: $e'),
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
      final repository = ref.read(pairingRepositoryProvider);
      final couple = await repository.joinCouple(
        _joinCodeController.text.trim(),
        _getEffectiveUid(),
        _joinNameController.text.trim(),
      );

      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected with your partner! 🎉'),
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
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join couple space: $e'),
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryRose,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimaryLight,
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
        title: const Text('Connect with Partner'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryRose,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: AppTheme.textSecondaryLight,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Create Space', icon: Icon(Icons.favorite_outline_rounded)),
            Tab(text: 'Join Partner', icon: Icon(Icons.link_rounded)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCreateTab(),
            _buildJoinTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    if (_createdCouple != null) {
      return _buildWaitingForPartnerView(_createdCouple!);
    }

    final formattedDate = DateFormat.yMMMMd().format(_selectedAnniversary);

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
            const Text(
              'Start Your Shared Space',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a private space for just the two of you, backed securely on Firebase Spark tier.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _createNameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter how your partner calls you',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
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
                  color: Theme.of(context).colorScheme.surface,
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
                          const Text(
                            'Anniversary Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryLight,
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
                  : const Text(
                      'Create Our Couple Space',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForPartnerView(CoupleModel initialCouple) {
    final coupleAsync = ref.watch(coupleStreamProvider(initialCouple.id));

    return coupleAsync.when(
      data: (couple) {
        final currentCouple = couple ?? initialCouple;

        if (currentCouple.isFull) {
          final other = currentCouple.getPartnerProfile(_getEffectiveUid());
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
                    'You are paired with ${other?.name ?? 'your partner'}!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your private space is ready.',
                    style: TextStyle(color: AppTheme.textSecondaryLight),
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
                    child: const Text('Enter Our Space'),
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
              const Text(
                'Share With Your Partner',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask your partner to enter this 6-digit code or scan the QR code in their app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryLight,
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
                    const Text(
                      'PAIRING CODE',
                      style: TextStyle(
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
                          const SnackBar(
                            content: Text('Pairing code copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Code'),
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
              // Stylized QR code container
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _StylizedQrPainter(code: currentCouple.inviteCode),
                    child: const Center(
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryRose,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
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
                    const Text(
                      'Waiting for your partner to join...',
                      style: TextStyle(
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
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildJoinTab() {
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
            const Text(
              'Join Your Partner',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the 6-digit code shown on your partner’s screen to link your devices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _joinNameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
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
              decoration: const InputDecoration(
                labelText: '6-Digit Invite Code',
                hintText: '000000',
                counterText: '',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (value) {
                if (value == null || value.trim().length != 6) {
                  return 'Enter the full 6-digit code';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
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
                  : const Text(
                      'Join Partner Space',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A custom painter rendering a crisp, stylized QR pattern for pairing codes.
class _StylizedQrPainter extends CustomPainter {
  final String code;

  _StylizedQrPainter({required this.code});

  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()
      ..color = const Color(0xFF2B2B2B)
      ..style = PaintingStyle.fill;

    final double cellSize = size.width / 21;

    void drawFinder(double x, double y) {
      // Outer square 7x7
      canvas.drawRect(
        Rect.fromLTWH(x * cellSize, y * cellSize, 7 * cellSize, 7 * cellSize),
        paintDark,
      );
      // Inner clear square 5x5
      final paintWhite = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH((x + 1) * cellSize, (y + 1) * cellSize, 5 * cellSize, 5 * cellSize),
        paintWhite,
      );
      // Core center 3x3
      canvas.drawRect(
        Rect.fromLTWH((x + 2) * cellSize, (y + 2) * cellSize, 3 * cellSize, 3 * cellSize),
        paintDark,
      );
    }

    // Draw three standard QR finder patterns
    drawFinder(1, 1);
    drawFinder(13, 1);
    drawFinder(1, 13);

    // Deterministic pseudo pattern seeded by code
    final seed = code.hashCode;
    for (int r = 0; r < 21; r++) {
      for (int c = 0; c < 21; c++) {
        // Skip finder regions
        if ((r < 8 && c < 8) || (r < 8 && c > 12) || (r > 12 && c < 8)) {
          continue;
        }
        // Skip center badge region
        if (r >= 8 && r <= 12 && c >= 8 && c <= 12) {
          continue;
        }
        final bit = ((seed * (r + 1) + (c + 1) * 31) ^ (r * c)) % 3 == 0;
        if (bit) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cellSize + 0.5, r * cellSize + 0.5, cellSize - 1, cellSize - 1),
              const Radius.circular(1.5),
            ),
            paintDark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StylizedQrPainter oldDelegate) {
    return oldDelegate.code != code;
  }
}
