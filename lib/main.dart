import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:couple_app/core/firebase/firebase_config.dart';
import 'package:couple_app/core/notifications/local_notification_service.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';
import 'package:couple_app/features/auth/presentation/pairing_screen.dart';
import 'package:couple_app/features/calendar/presentation/calendar_screen.dart';
import 'package:couple_app/features/daily_question/presentation/daily_question_screen.dart';
import 'package:couple_app/features/decide/presentation/decide_screen.dart';
import 'package:couple_app/features/finance/presentation/finance_screen.dart';
import 'package:couple_app/features/memories/presentation/memories_screen.dart';
import 'package:couple_app/features/notes/presentation/notes_screen.dart';
import 'package:couple_app/features/tasks/presentation/tasks_screen.dart';
import 'package:couple_app/features/vault/presentation/vault_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initialize();
  await LocalNotificationService.initialize();

  runApp(
    const ProviderScope(
      child: CoupleApp(),
    ),
  );
}

/// Root widget for the Couple Application.
class CoupleApp extends StatelessWidget {
  const CoupleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Couple App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const MainNavigationShell(),
    );
  }
}

/// Root application shell with adaptive 5-tab Material 3 navigation.
///
/// Watches [currentCoupleIdProvider]:
/// - When not paired (null or empty ID), displays [PairingScreen].
/// - When paired, renders the core feature tabs and the Samsung One UI inspired Hub.
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final coupleIdAsync = ref.watch(currentCoupleIdProvider);

    return coupleIdAsync.when(
      data: (coupleId) {
        if (coupleId == null || coupleId.trim().isEmpty) {
          return PairingScreen(
            onPairedSuccess: () {
              ref.refresh(currentCoupleIdProvider);
            },
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              DailyQuestionScreen(coupleId: coupleId),
              TasksScreen(coupleId: coupleId),
              CalendarScreen(coupleId: coupleId),
              DecideScreen(coupleId: coupleId),
              CoupleHubScreen(coupleId: coupleId),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.favorite_border_rounded),
                selectedIcon: Icon(Icons.favorite_rounded, color: AppTheme.primaryRose),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.check_circle_outline_rounded),
                selectedIcon: Icon(Icons.check_circle_rounded, color: AppTheme.primaryRose),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded, color: AppTheme.primaryRose),
                label: 'Calendar',
              ),
              NavigationDestination(
                icon: Icon(Icons.how_to_vote_outlined),
                selectedIcon: Icon(Icons.how_to_vote_rounded, color: AppTheme.primaryRose),
                label: 'Decide',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded, color: AppTheme.primaryRose),
                label: 'More',
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                color: AppTheme.primaryRose,
                size: 64,
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRose),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.errorRed,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load couple space',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondaryLight),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.refresh(currentCoupleIdProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Samsung One UI inspired Hub screen displaying feature cards and space info.
class CoupleHubScreen extends ConsumerWidget {
  final String coupleId;

  const CoupleHubScreen({
    super.key,
    required this.coupleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupleAsync = ref.watch(coupleStreamProvider(coupleId));
    final couple = coupleAsync.valueOrNull;

    final anniversaryText = couple != null
        ? DateFormat.yMMMMd().format(couple.anniversaryDate)
        : 'Loading...';

    final daysTogether = couple != null
        ? DateTime.now().difference(couple.anniversaryDate).inDays
        : null;

    final partnerNames = couple != null && couple.partnerProfiles.isNotEmpty
        ? couple.partnerProfiles.values.map((p) => p.name).join(' & ')
        : 'Our Private Space';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Couple Hub'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Samsung One UI Hero Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryRose.withOpacity(0.12),
                    AppTheme.secondaryBlush.withOpacity(0.18),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                border: Border.all(
                  color: AppTheme.primaryRose.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KRIVO COUPLE HUB',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppTheme.primaryRose,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    partnerNames,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    daysTogether != null && daysTogether >= 0
                        ? '$daysTogether days of shared love 💕'
                        : 'Anniversary: $anniversaryText',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'FEATURE SPACES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondaryLight,
                ),
              ),
            ),

            // Card 1: 📸 Memories, Wishlist & Capsules
            _HubFeatureCard(
              icon: Icons.photo_library_rounded,
              iconColor: AppTheme.primaryRose,
              iconBgColor: AppTheme.primaryRose.withOpacity(0.12),
              title: 'Memories, Wishlist & Capsules',
              subtitle: 'Timeline milestones, photo capsules & gift wishes',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemoriesScreen(coupleId: coupleId),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 2: 💰 Shared Finance & Savings
            _HubFeatureCard(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF2E7D32),
              iconBgColor: const Color(0xFF2E7D32).withOpacity(0.12),
              title: 'Shared Finance & Savings',
              subtitle: '50/50 splits, custom shares & piggy bank targets',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FinanceScreen(coupleId: coupleId),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 3: 🔐 Private Encrypted Vault
            _HubFeatureCard(
              icon: Icons.lock_rounded,
              iconColor: AppTheme.tertiaryMauve,
              iconBgColor: AppTheme.tertiaryMauve.withOpacity(0.15),
              title: 'Private Encrypted Vault',
              subtitle: 'Zero-knowledge AES-256 encrypted sensitive secrets',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VaultScreen(coupleId: coupleId),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 4: 💌 Love Notes & Sticky Wall
            _HubFeatureCard(
              icon: Icons.sticky_note_2_rounded,
              iconColor: const Color(0xFFE65100),
              iconBgColor: const Color(0xFFE65100).withOpacity(0.12),
              title: 'Love Notes & Sticky Wall',
              subtitle: 'Color sticky notes, sweet messages & widget pins',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotesScreen(coupleId: coupleId),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // ℹ️ Couple Space Info Card
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'SPACE DETAILS & SETTINGS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondaryLight,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                border: Border.all(
                  color: AppTheme.outlineLight.withOpacity(0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Space ID',
                    value: coupleId,
                    onCopy: () => _copyToClipboard(context, coupleId, 'Space ID'),
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    label: 'Invite Code',
                    value: couple?.inviteCode ?? '...',
                    isHighlighted: true,
                    onCopy: couple != null
                        ? () => _copyToClipboard(context, couple.inviteCode, 'Invite Code')
                        : null,
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    label: 'Anniversary',
                    value: anniversaryText,
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    label: 'Connection Status',
                    value: couple?.isFull == true
                        ? 'Paired (2/2 partners) 🎉'
                        : 'Waiting for partner (1/2)',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                        ),
                      ),
                      icon: const Icon(Icons.link_off_rounded, size: 20),
                      label: const Text(
                        'Unpair / Disconnect Space',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _confirmUnpair(context, ref),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmUnpair(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair from Couple Space?'),
        content: const Text(
          'Are you sure you want to disconnect from this space? You will return to the pairing screen and will need the invite code to reconnect with your partner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(pairingRepositoryProvider).clearCurrentCoupleId();
      ref.refresh(currentCoupleIdProvider);
    }
  }
}

/// A clean One UI card item navigating to a specific feature space.
class _HubFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubFeatureCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            border: Border.all(
              color: AppTheme.outlineLight.withOpacity(0.8),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryLight,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryLight,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row inside the Space Details card displaying a label and value with optional copy action.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryLight,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              color: isHighlighted ? AppTheme.primaryRose : AppTheme.textPrimaryLight,
              fontFamily: isHighlighted ? 'monospace' : null,
              letterSpacing: isHighlighted ? 1.5 : 0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Copy $label',
            onPressed: onCopy,
          ),
        ],
      ],
    );
  }
}
