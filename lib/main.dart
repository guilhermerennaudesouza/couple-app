import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:couple_app/core/firebase/firebase_config.dart';
import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/l10n/locale_provider.dart';
import 'package:couple_app/core/notifications/local_notification_service.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/core/theme/theme_provider.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
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

/// Root widget for the Couple Application with dynamic theme and locale resolution.
class CoupleApp extends ConsumerWidget {
  const CoupleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Couple App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      home: const MainNavigationShell(),
    );
  }
}

/// Root application shell with adaptive 5-tab Material 3 navigation.
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
    final strings = AppStrings.of(context);

    return coupleIdAsync.when(
      data: (coupleId) {
        if (coupleId == null || coupleId.trim().isEmpty) {
          return PairingScreen(
            onPairedSuccess: () {
              ref.invalidate(currentCoupleIdProvider);
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
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.favorite_border_rounded),
                selectedIcon: const Icon(Icons.favorite_rounded, color: AppTheme.primaryRose),
                label: strings.navToday,
              ),
              NavigationDestination(
                icon: const Icon(Icons.check_circle_outline_rounded),
                selectedIcon: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryRose),
                label: strings.navTasks,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryRose),
                label: strings.navCalendar,
              ),
              NavigationDestination(
                icon: const Icon(Icons.how_to_vote_outlined),
                selectedIcon: const Icon(Icons.how_to_vote_rounded, color: AppTheme.primaryRose),
                label: strings.navDecide,
              ),
              NavigationDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryRose),
                label: strings.navHub,
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
                  style: TextStyle(color: context.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(currentCoupleIdProvider),
                  child: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Samsung One UI inspired Hub screen displaying feature cards, preferences and space info.
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
    final strings = AppStrings.of(context);
    final activeThemeMode = ref.watch(themeModeProvider);
    final activeLocale = ref.watch(localeProvider);

    final anniversaryText = couple != null
        ? DateFormat.yMMMMd(activeLocale.toString()).format(couple.anniversaryDate)
        : '...';

    final daysTogether = couple != null
        ? DateTime.now().difference(couple.anniversaryDate).inDays
        : null;

    final partnerNames = couple != null && couple.partnerProfiles.isNotEmpty
        ? couple.partnerProfiles.values.map((p) => p.name).join(' & ')
        : strings.privateSpace;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.hubTitle),
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
                  color: AppTheme.primaryRose.withOpacity(0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.spaceHeroTag,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppTheme.primaryRose,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    partnerNames,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    daysTogether != null && daysTogether >= 0
                        ? strings.daysTogetherCount(daysTogether)
                        : '${strings.anniversary}: $anniversaryText',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Feature Spaces
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                strings.featureSpaces,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.textSecondary,
                ),
              ),
            ),

            // Card 1: 📸 Memories, Wishlist & Capsules
            _HubFeatureCard(
              icon: Icons.photo_library_rounded,
              iconColor: AppTheme.primaryRose,
              iconBgColor: AppTheme.primaryRose.withOpacity(0.12),
              title: strings.memoriesTitle,
              subtitle: strings.memoriesSub,
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
              title: strings.financeTitle,
              subtitle: strings.financeSub,
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
              title: strings.vaultTitle,
              subtitle: strings.vaultSub,
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
              title: strings.notesTitle,
              subtitle: strings.notesSub,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotesScreen(coupleId: coupleId),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // ⚙️ PREFERENCES & SETTINGS (Language & Theme Mode)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                strings.settings.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.textSecondary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? (context.isDarkMode ? AppTheme.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                border: Border.all(
                  color: context.outlineColor.withOpacity(0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language Switcher Row
                  Row(
                    children: [
                      const Icon(Icons.language_rounded, color: AppTheme.primaryRose, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.language,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<String>(
                            value: 'pt',
                            label: Text('🇧🇷 PT'),
                          ),
                          ButtonSegment<String>(
                            value: 'en',
                            label: Text('🇺🇸 EN'),
                          ),
                        ],
                        selected: {activeLocale.languageCode == 'pt' ? 'pt' : 'en'},
                        onSelectionChanged: (newSelection) {
                          final selected = newSelection.first;
                          if (selected == 'pt') {
                            ref.read(localeProvider.notifier).setLocale(kLocalePtBr);
                          } else {
                            ref.read(localeProvider.notifier).setLocale(kLocaleEnUs);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Theme Mode Switcher Row
                  Row(
                    children: [
                      Icon(
                        context.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppTheme.primaryRose,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.theme,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: const Icon(Icons.light_mode_outlined, size: 16),
                            label: Text(strings.themeLight),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: const Icon(Icons.dark_mode_outlined, size: 16),
                            label: Text(strings.themeDark),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            icon: const Icon(Icons.brightness_auto_outlined, size: 16),
                            label: Text(strings.themeSystem),
                          ),
                        ],
                        selected: {activeThemeMode},
                        onSelectionChanged: (newSelection) {
                          ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ℹ️ Couple Space Info Card
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                strings.spaceDetails,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.textSecondary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? (context.isDarkMode ? AppTheme.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                border: Border.all(
                  color: context.outlineColor.withOpacity(0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: strings.spaceId,
                    value: coupleId,
                    onCopy: () => _copyToClipboard(context, coupleId, strings.spaceId, strings),
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    label: strings.inviteCode,
                    value: couple?.inviteCode ?? '...',
                    isHighlighted: true,
                    onCopy: couple != null
                        ? () => _copyToClipboard(context, couple.inviteCode, strings.inviteCode, strings)
                        : null,
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    label: strings.anniversary,
                    value: anniversaryText,
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    label: strings.connectionStatus,
                    value: couple?.isFull == true
                        ? strings.pairedStatus
                        : strings.waitingPartnerStatus,
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
                      label: Text(
                        strings.unpairBtn,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _confirmUnpair(context, ref, strings),
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

  void _copyToClipboard(BuildContext context, String text, String label, AppStrings strings) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label ${strings.copied}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmUnpair(BuildContext context, WidgetRef ref, AppStrings strings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.unpairConfirmTitle),
        content: Text(strings.unpairConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.unpairBtn),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(pairingRepositoryProvider).clearCurrentCoupleId();
      ref.invalidate(currentCoupleIdProvider);
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
      color: Theme.of(context).cardTheme.color ?? (context.isDarkMode ? AppTheme.surfaceDark : Colors.white),
      borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            border: Border.all(
              color: context.outlineColor.withOpacity(0.8),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.textSecondary,
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
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
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
              color: isHighlighted ? AppTheme.primaryRose : context.textPrimary,
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
