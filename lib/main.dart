import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:couple_app/core/firebase/firebase_config.dart';
import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/l10n/locale_provider.dart';
import 'package:couple_app/core/notifications/local_notification_service.dart';
import 'package:couple_app/core/services/app_update_service.dart';
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
import 'package:couple_app/features/loyalty/presentation/loyalty_screen.dart';
import 'package:couple_app/features/adult_games/presentation/adult_games_screen.dart';
import 'package:couple_app/features/cycle/presentation/cycle_screen.dart';
import 'package:couple_app/features/stats/presentation/couple_stats_screen.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initialize();
  await LocalNotificationService.initialize();
  await initializeDateFormatting('pt_BR', null);
  await initializeDateFormatting('en_US', null);
  await WidgetSyncService.initialize();

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

        // Keep all Android Glance home screen widgets automatically synchronized
        ref.watch(widgetSyncProvider(coupleId));

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
                Text(
                  strings.unableToLoadSpace,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

/// Samsung One UI inspired Hub screen displaying feature cards, preferences, in-app updates and space info.
class CoupleHubScreen extends ConsumerStatefulWidget {
  final String coupleId;

  const CoupleHubScreen({
    super.key,
    required this.coupleId,
  });

  @override
  ConsumerState<CoupleHubScreen> createState() => _CoupleHubScreenState();
}

class _CoupleHubScreenState extends ConsumerState<CoupleHubScreen> {
  String _installedVersion = '1.0.0';
  bool _isCheckingUpdate = false;
  static bool _hasAutoCheckedOnLaunch = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _installedVersion = info.version;
        });
      }
    } catch (e) {
      debugPrint('CoupleHubScreen: failed to load package info: $e');
    }

    if (!_hasAutoCheckedOnLaunch) {
      _hasAutoCheckedOnLaunch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkForUpdate(silent: true);
        }
      });
    }
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    if (!silent) {
      setState(() => _isCheckingUpdate = true);
    }

    try {
      final updateService = ref.read(appUpdateServiceProvider);
      final update = await updateService.checkForUpdate(
        currentVersionOverride: _installedVersion,
      );

      if (!mounted) return;

      if (update != null && update.hasUpdate) {
        _showUpdateDialog(update);
      } else if (!silent) {
        final strings = AppStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(update == null ? strings.updateError : strings.updateUpToDate),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('CoupleHubScreen: update check failed: $e');
      if (!silent && mounted) {
        final strings = AppStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.updateError),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    final strings = AppStrings.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        double? downloadProgress;
        String? statusText;
        bool isDownloading = false;
        String? errorMessage;
        StreamSubscription<OtaEvent>? otaSub;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.system_update_rounded,
                    color: AppTheme.primaryRose,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.updateAvailableTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.updateAvailableBody(update.latestVersion),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (update.releaseNotes != null &&
                      update.releaseNotes!.trim().isNotEmpty) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          update.releaseNotes!.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isDownloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: downloadProgress,
                        backgroundColor: context.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryRose,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText ?? strings.updateChecking,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.errorRed,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!isDownloading) ...[
                  TextButton(
                    onPressed: () {
                      otaSub?.cancel();
                      Navigator.of(dialogCtx).pop();
                    },
                    child: Text(strings.updateLater),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryRose,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        isDownloading = true;
                        errorMessage = null;
                        statusText = strings.updateDownloading('0');
                        downloadProgress = 0.0;
                      });

                      try {
                        final service = ref.read(appUpdateServiceProvider);
                        otaSub = service
                            .startOtaUpdate(update.downloadUrl)
                            .listen(
                          (event) {
                            if (!mounted) return;
                            setDialogState(() {
                              if (event.status == OtaStatus.DOWNLOADING) {
                                final pct =
                                    double.tryParse(event.value ?? '0') ?? 0;
                                downloadProgress = pct / 100.0;
                                statusText =
                                    strings.updateDownloading(event.value ?? '0');
                              } else if (event.status == OtaStatus.INSTALLING) {
                                isDownloading = false;
                                statusText = strings.isPortuguese
                                    ? 'Iniciando instalador do sistema...'
                                    : 'Starting system installer...';
                                downloadProgress = 1.0;
                              } else if (event.status ==
                                  OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
                                isDownloading = false;
                                errorMessage = strings.isPortuguese
                                    ? 'Permissão necessária para instalar atualizações.'
                                    : 'Permission required to install updates.';
                              } else if (event.status ==
                                      OtaStatus.INTERNAL_ERROR ||
                                  event.status == OtaStatus.DOWNLOAD_ERROR ||
                                  event.status ==
                                      OtaStatus.INSTALLATION_ERROR) {
                                isDownloading = false;
                                errorMessage = strings.updateError;
                              }
                            });
                          },
                          onError: (err) {
                            if (!mounted) return;
                            setDialogState(() {
                              isDownloading = false;
                              errorMessage = strings.updateError;
                            });
                          },
                        );
                      } catch (e) {
                        setDialogState(() {
                          isDownloading = false;
                          errorMessage = strings.updateError;
                        });
                      }
                    },
                    child: Text(strings.updateNow),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupleId = widget.coupleId;
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
          cacheExtent: 1500,
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
            const SizedBox(height: 12),

            // Card 5: 🎟️ Cupons de Amor & Fidelidade (Krivo Feature)
            _HubFeatureCard(
              icon: Icons.confirmation_number_rounded,
              iconColor: AppTheme.primaryRose,
              iconBgColor: AppTheme.primaryRose.withOpacity(0.12),
              title: strings.hubLoyaltyTitle,
              subtitle: strings.hubLoyaltySub,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LoyaltyScreen(coupleId: coupleId),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 6: 🔥 Jogos de Intimidade & Desafios 18+ (Krivo Feature)
            _HubFeatureCard(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFD81B60),
              iconBgColor: const Color(0xFFD81B60).withOpacity(0.12),
              title: strings.hubAdultGamesTitle,
              subtitle: strings.hubAdultGamesSub,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdultGamesScreen(coupleId: coupleId),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 7: 🌸 Ciclo Menstrual & Cuidado do Casal (Krivo Feature)
            _HubFeatureCard(
              icon: Icons.spa_rounded,
              iconColor: const Color(0xFFEC407A),
              iconBgColor: const Color(0xFFEC407A).withOpacity(0.12),
              title: strings.hubCycleTitle,
              subtitle: strings.hubCycleSub,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CycleScreen(coupleId: coupleId),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 8: 🏆 Nossa Retrospectiva & Nível XP (Krivo Feature)
            _HubFeatureCard(
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFD97706),
              iconBgColor: const Color(0xFFD97706).withOpacity(0.12),
              title: strings.hubStatsTitle,
              subtitle: strings.hubStatsSub,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CoupleStatsScreen(coupleId: coupleId),
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

                  // Theme Mode Switcher
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            context.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: AppTheme.primaryRose,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            strings.theme,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
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
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // App Version & In-App Update Row
                  Row(
                    children: [
                      const Icon(
                        Icons.system_update_rounded,
                        color: AppTheme.primaryRose,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              strings.appVersionLabel,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'v$_installedVersion',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isCheckingUpdate)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      else
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(
                            strings.checkForUpdates,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _checkForUpdate(silent: false),
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
            tooltip: 'Copiar $label',
            onPressed: onCopy,
          ),
        ],
      ],
    );
  }
}
