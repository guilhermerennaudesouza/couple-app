import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/couple_model.dart';
import '../../auth/data/pairing_repository.dart';
import '../domain/memory_model.dart';
import '../data/memories_repository.dart';
import '../../time_capsule/domain/time_capsule_model.dart';
import '../../time_capsule/data/time_capsule_repository.dart';
import '../../wishlist/domain/wish_model.dart';

/// Screen presenting the couple's photo timeline album, future time capsules,
/// and collaborative shared wishlist.
class MemoriesScreen extends ConsumerStatefulWidget {
  final CoupleModel? initialCouple;
  final String? coupleId;
  final String? currentUid;

  const MemoriesScreen({
    super.key,
    this.initialCouple,
    this.coupleId,
    this.currentUid,
  });

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

/// Renders either a Base64-encoded compressed image (free Spark tier)
/// or a network HTTP URL image with responsive loading and error states.
Widget buildPhotoThumbnail(
  String photoUrl, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  if (photoUrl.startsWith('data:image') || photoUrl.startsWith('base64:')) {
    try {
      final base64Data = photoUrl.contains(',')
          ? photoUrl.substring(photoUrl.indexOf(',') + 1)
          : (photoUrl.startsWith('base64:') ? photoUrl.substring(7) : photoUrl);
      final bytes = base64Decode(base64Data);
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => Container(
          color: context.surfaceVariant,
          width: width,
          height: height,
          child: Center(
            child: Icon(Icons.broken_image_rounded, color: AppTheme.textSecondaryDark),
          ),
        ),
      );
    } catch (_) {
      return Container(
        color: AppTheme.surfaceVariantDark,
        width: width,
        height: height,
        child: Center(
          child: Icon(Icons.broken_image_rounded, color: AppTheme.textSecondaryDark),
        ),
      );
    }
  }

  return Image.network(
    photoUrl,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (context, error, stackTrace) => Container(
      color: context.surfaceVariant,
      width: width,
      height: height,
      child: Center(
        child: Icon(Icons.image_not_supported_rounded, color: AppTheme.textSecondaryDark),
      ),
    ),
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return Container(
        color: context.surfaceVariant,
        width: width,
        height: height,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryRose),
        ),
      );
    },
  );
}

/// Renders a full-screen interactive zoom photo from Base64 or network URL.
Widget buildFullscreenPhoto(String photoUrl) {
  if (photoUrl.startsWith('data:image') || photoUrl.startsWith('base64:')) {
    try {
      final base64Data = photoUrl.contains(',')
          ? photoUrl.substring(photoUrl.indexOf(',') + 1)
          : (photoUrl.startsWith('base64:') ? photoUrl.substring(7) : photoUrl);
      final bytes = base64Decode(base64Data);
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white, size: 64),
        ),
      );
    } catch (_) {
      return Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.white, size: 64),
      );
    }
  }

  return Image.network(
    photoUrl,
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) => Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.white, size: 64),
    ),
  );
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedWishlistCategory = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getEffectiveUid() {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'partner_uid';
  }

  String _getUserDisplayName(CoupleModel? couple, String uid) {
    if (couple != null) {
      final profile = couple.getMyProfile(uid);
      if (profile != null && profile.name.isNotEmpty) {
        return profile.name;
      }
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        user.uid == uid &&
        user.displayName != null &&
        user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    return 'Sweetheart';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUid = _getEffectiveUid();
    final activeCoupleId = widget.coupleId ??
        widget.initialCouple?.id ??
        ref.watch(currentCoupleIdProvider).valueOrNull ??
        '';

    if (activeCoupleId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Memories & Vault'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 64,
                  color: AppTheme.primaryRose.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Couple Space Connected',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please pair with your partner before accessing shared memories and time capsules.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondaryDark),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final coupleAsync = ref.watch(coupleStreamProvider(activeCoupleId));
    final currentCouple = coupleAsync.valueOrNull ?? widget.initialCouple;

    return Scaffold(
      appBar: AppBar(
        title: Text('Memories & Vault'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryRose,
          labelColor: AppTheme.primaryRose,
          unselectedLabelColor: context.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.photo_library_outlined, size: 20),
              text: 'Timeline',
            ),
            Tab(
              icon: Icon(Icons.lock_clock_outlined, size: 20),
              text: 'Time Capsules',
            ),
            Tab(
              icon: Icon(Icons.card_giftcard_outlined, size: 20),
              text: 'Wishlist',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMemoriesTab(context, activeCoupleId, effectiveUid, currentCouple),
          _buildTimeCapsulesTab(context, activeCoupleId, effectiveUid, currentCouple),
          _buildWishlistTab(context, activeCoupleId, effectiveUid, currentCouple),
        ],
      ),
      floatingActionButton: _buildFab(context, activeCoupleId, effectiveUid),
    );
  }

  Widget? _buildFab(BuildContext context, String coupleId, String effectiveUid) {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton.extended(
          heroTag: 'fab_memories',
          backgroundColor: AppTheme.primaryRose,
          foregroundColor: Colors.white,
          onPressed: () => _showAddMemorySheet(context, coupleId, effectiveUid),
          icon: const Icon(Icons.add_a_photo_rounded),
          label: const Text('Add Memory'),
        );
      case 1:
        return FloatingActionButton.extended(
          heroTag: 'fab_capsules',
          backgroundColor: AppTheme.primaryRose,
          foregroundColor: Colors.white,
          onPressed: () => _showSealCapsuleSheet(context, coupleId, effectiveUid),
          icon: const Icon(Icons.lock_clock_rounded),
          label: const Text('Seal Capsule'),
        );
      case 2:
        return FloatingActionButton.extended(
          heroTag: 'fab_wishlist',
          backgroundColor: AppTheme.primaryRose,
          foregroundColor: Colors.white,
          onPressed: () => _showAddWishSheet(context, coupleId, effectiveUid),
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('Add Wish'),
        );
      default:
        return null;
    }
  }

  // ===========================================================================
  // TAB 1: TIMELINE ALBUM (MEMORIES)
  // ===========================================================================

  Widget _buildMemoriesTab(
    BuildContext context,
    String coupleId,
    String effectiveUid,
    CoupleModel? couple,
  ) {
    final memoriesAsync = ref.watch(memoriesStreamProvider(coupleId));

    return memoriesAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
              const SizedBox(height: 12),
              Text(
                'Failed to load memories: $err',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondaryDark),
              ),
            ],
          ),
        ),
      ),
      data: (memories) {
        if (memories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.pastelPeach.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      size: 40,
                      color: AppTheme.primaryRose,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Memories Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture your favorite dates, trips, and milestone moments together.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondaryDark),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryRose,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                      ),
                    ),
                    onPressed: () => _showAddMemorySheet(context, coupleId, effectiveUid),
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: const Text('Add First Memory'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: memories.length,
          itemBuilder: (context, index) {
            final memory = memories[index];
            return _buildMemoryCard(context, memory, coupleId, effectiveUid, couple);
          },
        );
      },
    );
  }

  Widget _buildMemoryCard(
    BuildContext context,
    MemoryModel memory,
    String coupleId,
    String effectiveUid,
    CoupleModel? couple,
  ) {
    final formattedDate = DateFormat.yMMMMd().format(memory.date);
    final creatorName = _getUserDisplayName(couple, memory.createdBy);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date, Location tag & Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelPeach,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.primaryRose),
                      const SizedBox(width: 5),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryRoseDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (memory.location != null && memory.location!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.pastelLavender.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.tertiaryMauve),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                memory.location!,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                ],
                IconButton(
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textSecondaryDark),
                  onPressed: () => _confirmDeleteMemory(context, coupleId, memory),
                ),
              ],
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              memory.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ),

          // Photo Display / Carousel
          if (memory.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMemoryPhotoSection(context, memory.photoUrls),
          ],

          // Caption
          if (memory.caption.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outlineLight.withOpacity(0.5)),
                ),
                child: Text(
                  memory.caption,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
          ],

          // Footer: author
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 14, color: AppTheme.secondaryBlush),
                const SizedBox(width: 6),
                Text(
                  'Added by $creatorName',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryPhotoSection(BuildContext context, List<String> photos) {
    if (photos.length == 1) {
      return GestureDetector(
        onTap: () => _showPhotoViewer(context, photos, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: buildPhotoThumbnail(
                photos.first,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 220,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final photoUrl = photos[index];
          return GestureDetector(
            onTap: () => _showPhotoViewer(context, photos, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 200,
                child: buildPhotoThumbnail(
                  photoUrl,
                  fit: BoxFit.cover,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 2: TIME CAPSULES
  // ===========================================================================

  Widget _buildTimeCapsulesTab(
    BuildContext context,
    String coupleId,
    String effectiveUid,
    CoupleModel? couple,
  ) {
    final capsulesAsync = ref.watch(timeCapsulesStreamProvider(coupleId));

    return capsulesAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
              const SizedBox(height: 12),
              Text(
                'Failed to load time capsules: $err',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondaryDark),
              ),
            ],
          ),
        ),
      ),
      data: (capsules) {
        if (capsules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.pastelLavender.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_clock_rounded,
                      size: 40,
                      color: AppTheme.primaryRose,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Time Capsules Sealed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bury a secret love letter or throwback photos to be opened on a future anniversary or milestone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondaryDark),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryRose,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                      ),
                    ),
                    onPressed: () => _showSealCapsuleSheet(context, coupleId, effectiveUid),
                    icon: const Icon(Icons.lock_clock_rounded),
                    label: const Text('Seal First Capsule'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            // Motivational header banner
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.pastelPeach, AppTheme.pastelLavender],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_bottom_rounded, size: 28, color: AppTheme.primaryRose),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vault of Love Letters',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Letters and photos sealed tight until their unlock date arrives 🔒',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            ...capsules.map(
              (c) => _buildCapsuleCard(context, c, coupleId, effectiveUid, couple),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCapsuleCard(
    BuildContext context,
    TimeCapsuleModel capsule,
    String coupleId,
    String effectiveUid,
    CoupleModel? couple,
  ) {
    final isReadyToOpen = capsule.canOpen();
    final isOpened = capsule.isOpened;
    final formattedUnlockDate = DateFormat.yMMMMd().add_jm().format(capsule.unlockDate);
    final creatorName = _getUserDisplayName(couple, capsule.createdBy);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        side: BorderSide(
          color: isOpened
              ? AppTheme.goldAccent.withOpacity(0.5)
              : (isReadyToOpen
                  ? AppTheme.primaryRose
                  : AppTheme.outlineLight),
          width: isReadyToOpen && !isOpened ? 2 : 1,
        ),
      ),
      elevation: isOpened ? 2 : 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status badge & options
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpened
                        ? AppTheme.goldAccent.withOpacity(0.2)
                        : (isReadyToOpen
                            ? AppTheme.primaryRose.withOpacity(0.15)
                            : AppTheme.pastelLavender),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOpened
                            ? Icons.celebration_rounded
                            : (isReadyToOpen
                                ? Icons.lock_open_rounded
                                : Icons.lock_rounded),
                        size: 14,
                        color: isOpened
                            ? AppTheme.goldAccent
                            : (isReadyToOpen
                                ? AppTheme.primaryRose
                                : AppTheme.tertiaryMauve),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOpened
                            ? 'Unsealed'
                            : (isReadyToOpen ? 'Ready to Open! 🎉' : 'Locked 🔒'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOpened
                              ? const Color(0xFFB37400)
                              : (isReadyToOpen
                                  ? AppTheme.primaryRoseDark
                                  : context.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textSecondaryDark),
                  onPressed: () => _confirmDeleteCapsule(context, coupleId, capsule),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              capsule.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Date & countdown
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textSecondaryDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isOpened
                        ? 'Opened ${DateFormat.yMMMMd().format(capsule.openedAt ?? capsule.unlockDate)}'
                        : 'Unlock date: $formattedUnlockDate',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark),
                  ),
                ),
              ],
            ),

            if (!isOpened && !isReadyToOpen) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRose.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '⏳ Unlocks in ${_formatDuration(capsule.timeRemaining())}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryRose,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Content Area: Concealed vs Revealed
            if (!isOpened && !isReadyToOpen) ...[
              // Concealed state
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantLight.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.outlineLight.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.lock_rounded, size: 36, color: AppTheme.primaryRoseLight),
                    const SizedBox(height: 8),
                    Text(
                      'Secret words locked in the vault',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      capsule.photoUrls.isNotEmpty
                          ? 'Includes message & ${capsule.photoUrls.length} throwback photos'
                          : 'Sealed by $creatorName',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Patience my love! 🔒 This capsule unlocks on $formattedUnlockDate',
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  icon: Icon(Icons.lock_rounded, size: 16),
                  label: Text('Locked Until Scheduled Date'),
                ),
              ),
            ] else if (!isOpened && isReadyToOpen) ...[
              // Ready to open state
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.pastelPeach.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryRose.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cake_rounded, size: 40, color: AppTheme.primaryRose),
                    SizedBox(height: 8),
                    Text(
                      'The wait is over! 🎉',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryRoseDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap below to break the seal and reveal the secret letter!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryRose,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                    ),
                  ),
                  onPressed: () => _openCapsule(context, coupleId, capsule),
                  icon: Icon(Icons.lock_open_rounded),
                  label: Text('Break Seal & Open Capsule 🎉'),
                ),
              ),
            ] else ...[
              // Revealed / Opened state
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.goldAccent.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.format_quote_rounded, color: AppTheme.primaryRose, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          'Written by $creatorName',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      capsule.message,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (capsule.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildMemoryPhotoSection(context, capsule.photoUrls),
              ],
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.favorite, size: 13, color: AppTheme.secondaryBlush),
                const SizedBox(width: 5),
                Text(
                  'Created by $creatorName',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative || duration == Duration.zero) {
      return 'Unlocked now!';
    }
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '$days d $hours h';
    }
    if (hours > 0) {
      return '$hours h $minutes m';
    }
    return '$minutes m';
  }

  Future<void> _openCapsule(
    BuildContext context,
    String coupleId,
    TimeCapsuleModel capsule,
  ) async {
    try {
      await ref.read(timeCapsuleRepositoryProvider).openCapsule(coupleId, capsule.id);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.dialogBorderRadius),
          ),
          title: const Row(
            children: [
              Icon(Icons.celebration_rounded, color: AppTheme.goldAccent, size: 28),
              SizedBox(width: 8),
              Expanded(child: Text('Capsule Unsealed! 🎉')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You broke the seal on "${capsule.title}"!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  capsule.message,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryRose),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cherish Forever ✨'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open capsule: $e')),
      );
    }
  }

  // ===========================================================================
  // TAB 3: SHARED WISHLIST
  // ===========================================================================

  Widget _buildWishlistTab(
    BuildContext context,
    String coupleId,
    String effectiveUid,
    CoupleModel? couple,
  ) {
    final wishlistAsync = ref.watch(wishlistStreamProvider(coupleId));

    return wishlistAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
              const SizedBox(height: 12),
              Text(
                'Failed to load wishlist: $err',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondaryDark),
              ),
            ],
          ),
        ),
      ),
      data: (allWishes) {
        final filteredWishes = _selectedWishlistCategory == 'All'
            ? allWishes
            : allWishes.where((w) => w.category == _selectedWishlistCategory).toList();

        final purchasedCount = allWishes.where((w) => w.isPurchased).length;
        final totalCount = allWishes.length;

        return Column(
          children: [
            // Category Filter Chips
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip('All'),
                  ...WishModel.categories.map((c) => _buildCategoryChip(c)),
                ],
              ),
            ),

            // Statistics ribbon
            if (totalCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariantLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 16, color: AppTheme.primaryRose),
                      const SizedBox(width: 8),
                      Text(
                        '$purchasedCount of $totalCount fulfilled',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryDark,
                        ),
                      ),
                      const Spacer(),
                      if (purchasedCount > 0 && purchasedCount == totalCount)
                        Text(
                          'All fulfilled! 🎉',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // List of Wish Items
            Expanded(
              child: filteredWishes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppTheme.pastelPeach.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.card_giftcard_rounded,
                                size: 40,
                                color: AppTheme.primaryRose,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _selectedWishlistCategory == 'All'
                                  ? 'Wishlist is Empty'
                                  : 'No $_selectedWishlistCategory Wishes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add dream gifts, vacation ideas, or things you want to buy together.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondaryDark),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryRose,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                                ),
                              ),
                              onPressed: () => _showAddWishSheet(context, coupleId, effectiveUid),
                              icon: const Icon(Icons.add_shopping_cart_rounded),
                              label: const Text('Add Wish'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: filteredWishes.length,
                      itemBuilder: (context, index) {
                        final wish = filteredWishes[index];
                        return _buildWishCard(context, wish, coupleId, effectiveUid, couple);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChip(String label) {
    final isSelected = _selectedWishlistCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primaryRose,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : context.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        checkmarkColor: Colors.white,
        backgroundColor: AppTheme.surfaceVariantLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (val) {
          setState(() {
            _selectedWishlistCategory = label;
          });
        },
      ),
    );
  }

  Widget _buildWishCard(
    BuildContext context,
    WishModel wish,
    String coupleId,
    String effectiveUid,
    CoupleModel? couple,
  ) {
    final creatorName = _getUserDisplayName(couple, wish.createdBy);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Purchase Checkbox
                Checkbox(
                  value: wish.isPurchased,
                  activeColor: AppTheme.primaryRose,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) async {
                    try {
                      await ref.read(memoriesRepositoryProvider).toggleWishPurchased(
                            coupleId,
                            wish.id,
                            val ?? false,
                            purchasedBy: effectiveUid,
                          );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update wish: $e')),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Title & Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wish.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: wish.isPurchased ? TextDecoration.lineThrough : null,
                          color: wish.isPurchased
                              ? context.textSecondary
                              : context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.pastelLavender.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              wish.category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.tertiaryMauve,
                              ),
                            ),
                          ),
                          if (wish.estimatedPrice != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.pastelPeach,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '\$${wish.estimatedPrice!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryRoseDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Delete Menu
                IconButton(
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textSecondaryDark),
                  onPressed: () => _confirmDeleteWish(context, coupleId, wish),
                ),
              ],
            ),

            if (wish.description != null && wish.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  wish.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryDark,
                  ),
                ),
              ),
            ],

            // URL link button & purchaser badge
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 10),
              child: Row(
                children: [
                  if (wish.url != null && wish.url!.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: wish.url!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard! 📋'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRose.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link_rounded, size: 14, color: AppTheme.primaryRose),
                            SizedBox(width: 4),
                            Text(
                              'Copy Link',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryRose,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    wish.isPurchased ? 'Purchased 🎉' : 'Added by $creatorName',
                    style: TextStyle(
                      fontSize: 11,
                      color: wish.isPurchased ? AppTheme.successGreen : context.textSecondary,
                      fontWeight: wish.isPurchased ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM SHEETS & MODALS
  // ===========================================================================

  void _showAddMemorySheet(BuildContext context, String coupleId, String effectiveUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMemorySheet(
        coupleId: coupleId,
        effectiveUid: effectiveUid,
      ),
    );
  }

  void _showSealCapsuleSheet(BuildContext context, String coupleId, String effectiveUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SealCapsuleSheet(
        coupleId: coupleId,
        effectiveUid: effectiveUid,
      ),
    );
  }

  void _showAddWishSheet(BuildContext context, String coupleId, String effectiveUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddWishSheet(
        coupleId: coupleId,
        effectiveUid: effectiveUid,
      ),
    );
  }

  void _showPhotoViewer(BuildContext context, List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: photos.length,
                itemBuilder: (ctx, index) {
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 3.5,
                    child: Center(
                      child: buildFullscreenPhoto(photos[index]),
                    ),
                  );
                },
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteMemory(BuildContext context, String coupleId, MemoryModel memory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.dialogBorderRadius),
        ),
        title: const Text('Delete Memory?'),
        content: Text('Are you sure you want to remove "${memory.title}" from your shared timeline?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(memoriesRepositoryProvider).deleteMemory(coupleId, memory.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Memory deleted')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete memory: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCapsule(BuildContext context, String coupleId, TimeCapsuleModel capsule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.dialogBorderRadius),
        ),
        title: const Text('Delete Time Capsule?'),
        content: Text('Are you sure you want to delete "${capsule.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(timeCapsuleRepositoryProvider).deleteCapsule(coupleId, capsule.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Time capsule deleted')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete capsule: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWish(BuildContext context, String coupleId, WishModel wish) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.dialogBorderRadius),
        ),
        title: const Text('Delete Wish?'),
        content: Text('Are you sure you want to remove "${wish.title}" from the shared wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(memoriesRepositoryProvider).deleteWish(coupleId, wish.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wish removed from wishlist')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete wish: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ADD MEMORY BOTTOM SHEET
// =============================================================================

class _AddMemorySheet extends ConsumerStatefulWidget {
  final String coupleId;
  final String effectiveUid;

  const _AddMemorySheet({
    required this.coupleId,
    required this.effectiveUid,
  });

  @override
  ConsumerState<_AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends ConsumerState<_AddMemorySheet> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _urlInputController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  final List<String> _photoUrls = [];
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _locationController.dispose();
    _urlInputController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      // Compress and store as Base64 data URI directly in Firestore (100% free Spark tier)
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (mounted) {
        setState(() {
          _photoUrls.add(base64String);
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo processing failed: $e')),
        );
      }
    }
  }

  void _addPhotoFromUrl() {
    final url = _urlInputController.text.trim();
    if (url.isNotEmpty && Uri.tryParse(url)?.isAbsolute == true) {
      setState(() {
        _photoUrls.add(url);
        _urlInputController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL')),
      );
    }
  }

  Future<void> _saveMemory() async {
    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for photo upload to finish')),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for this memory')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final memory = MemoryModel(
        id: '',
        title: title,
        date: _selectedDate,
        caption: _captionController.text.trim(),
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        photoUrls: _photoUrls,
        createdBy: widget.effectiveUid,
      );

      await ref.read(memoriesRepositoryProvider).addMemory(widget.coupleId, memory);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory saved to timeline! ✨')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save memory: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.dialogBorderRadius)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppTheme.primaryRose),
                const SizedBox(width: 8),
                const Text(
                  'Add New Memory',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g., Sunset picnic at the park',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius)),
                prefixIcon: const Icon(Icons.title_rounded, color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 12),

            // Date Picker Row
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryRose),
              title: const Text('Memory Date'),
              subtitle: Text(DateFormat.yMMMMd().format(_selectedDate)),
              trailing: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null && mounted) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 8),

            // Location
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g., Central Park, NYC',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius)),
                prefixIcon: const Icon(Icons.location_on_rounded, color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 12),

            // Caption
            TextField(
              controller: _captionController,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                labelText: 'Caption / Story',
                hintText: 'What made this moment special?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius)),
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 16),

            // Photo Management
            const Text(
              'Photos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            if (_photoUrls.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoUrls.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: buildPhotoThumbnail(
                              _photoUrls[index],
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _photoUrls.removeAt(index));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadPhoto,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(_isUploading ? 'Uploading...' : 'Pick Photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Optional URL paste
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlInputController,
                    decoration: InputDecoration(
                      hintText: 'Or paste image URL',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_link_rounded, color: AppTheme.primaryRose),
                  onPressed: _addPhotoFromUrl,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryRose,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                ),
                onPressed: (_isSaving || _isUploading) ? null : _saveMemory,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Memory ✨', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SEAL TIME CAPSULE BOTTOM SHEET
// =============================================================================

class _SealCapsuleSheet extends ConsumerStatefulWidget {
  final String coupleId;
  final String effectiveUid;

  const _SealCapsuleSheet({
    required this.coupleId,
    required this.effectiveUid,
  });

  @override
  ConsumerState<_SealCapsuleSheet> createState() => _SealCapsuleSheetState();
}

class _SealCapsuleSheetState extends ConsumerState<_SealCapsuleSheet> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _urlInputController = TextEditingController();

  DateTime _unlockDate = DateTime.now().add(const Duration(days: 30));
  final List<String> _photoUrls = [];
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _urlInputController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      // Compress and store as Base64 data URI directly in Firestore (100% free Spark tier)
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (mounted) {
        setState(() {
          _photoUrls.add(base64String);
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo processing failed: $e')),
        );
      }
    }
  }

  void _addPhotoFromUrl() {
    final url = _urlInputController.text.trim();
    if (url.isNotEmpty && Uri.tryParse(url)?.isAbsolute == true) {
      setState(() {
        _photoUrls.add(url);
        _urlInputController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL')),
      );
    }
  }

  Future<void> _sealCapsule() async {
    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for photo upload to finish')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give this capsule a title')),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a secret letter or message to seal')),
      );
      return;
    }

    if (_unlockDate.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock date must be in the future!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final capsule = TimeCapsuleModel(
        id: '',
        title: title,
        unlockDate: _unlockDate,
        message: message,
        photoUrls: _photoUrls,
        createdBy: widget.effectiveUid,
      );

      await ref.read(timeCapsuleRepositoryProvider).sealCapsule(widget.coupleId, capsule);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Time capsule sealed until ${DateFormat.yMMMMd().format(_unlockDate)}! 🔒',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to seal capsule: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.dialogBorderRadius)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_clock_rounded, color: AppTheme.primaryRose),
                const SizedBox(width: 8),
                const Text(
                  'Seal a Time Capsule',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Capsule Title *',
                hintText: 'e.g., Open on our 3rd Anniversary',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius)),
                prefixIcon: const Icon(Icons.title_rounded, color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 12),

            // Unlock Date Picker Row
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm_rounded, color: AppTheme.primaryRose),
              title: const Text('Unlock Date & Time *'),
              subtitle: Text(DateFormat.yMMMMd().add_jm().format(_unlockDate)),
              trailing: OutlinedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _unlockDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (pickedDate != null && context.mounted) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_unlockDate),
                    );
                    if (pickedTime != null && mounted) {
                      setState(() {
                        _unlockDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 8),

            // Message / Love Letter
            TextField(
              controller: _messageController,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                labelText: 'Secret Letter / Message *',
                hintText: 'Write your promises, reflections, or secret words here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius)),
                prefixIcon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 16),

            // Sealed Photos
            const Text(
              'Attach Throwback Photos (optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            if (_photoUrls.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoUrls.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: buildPhotoThumbnail(
                              _photoUrls[index],
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _photoUrls.removeAt(index));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadPhoto,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(_isUploading ? 'Uploading...' : 'Pick Photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // URL option
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlInputController,
                    decoration: InputDecoration(
                      hintText: 'Or paste image URL',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_link_rounded, color: AppTheme.primaryRose),
                  onPressed: _addPhotoFromUrl,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Seal Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryRose,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                ),
                onPressed: (_isSaving || _isUploading) ? null : _sealCapsule,
                icon: const Icon(Icons.lock_outline_rounded),
                label: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Seal Capsule 🔒', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ADD WISH BOTTOM SHEET
// =============================================================================

class _AddWishSheet extends ConsumerStatefulWidget {
  final String coupleId;
  final String effectiveUid;

  const _AddWishSheet({
    required this.coupleId,
    required this.effectiveUid,
  });

  @override
  ConsumerState<_AddWishSheet> createState() => _AddWishSheetState();
}

class _AddWishSheetState extends ConsumerState<_AddWishSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _urlController = TextEditingController();

  String _category = WishModel.categoryGifts;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveWish() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a wish title')),
      );
      return;
    }

    final priceStr = _priceController.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final price = double.tryParse(priceStr);

    setState(() => _isSaving = true);

    try {
      final wish = WishModel(
        id: '',
        title: title,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        url: _urlController.text.trim().isNotEmpty ? _urlController.text.trim() : null,
        estimatedPrice: price,
        category: _category,
        createdBy: widget.effectiveUid,
      );

      await ref.read(memoriesRepositoryProvider).addWish(widget.coupleId, wish);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to shared wishlist! ✨')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add wish: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.dialogBorderRadius)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: AppTheme.primaryRose),
                const SizedBox(width: 8),
                const Text(
                  'Add to Wishlist',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Item / Wish Title *',
                hintText: 'e.g., Weekend trip to the mountains',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius)),
                prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 12),

            // Category Chips
            const Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: WishModel.categories.map((c) {
                final isSelected = _category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryRose,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : context.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _category = c);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Estimated Price
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Estimated Price (optional)',
                hintText: 'e.g., 79.99',
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius)),
                prefixIcon: const Icon(Icons.attach_money_rounded, color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 12),

            // Product / Link URL
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Website / Product Link (optional)',
                hintText: 'https://...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius)),
                prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes / Description (optional)',
                hintText: 'Size, color, details or why we want it',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.inputBorderRadius)),
                prefixIcon: const Icon(Icons.description_outlined, color: AppTheme.primaryRose),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryRose,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                ),
                onPressed: _isSaving ? null : _saveWish,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Add to Wishlist 🎁', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
