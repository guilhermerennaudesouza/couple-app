import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/core/utils/photo_budget_utils.dart';

/// Shared couple avatar widget supporting:
/// - Base64 Data URIs (`data:image/...;base64,...` or `base64:...`) decoded via LRU cache
/// - Standard HTTP/HTTPS image URLs with graceful error fallback to initials
/// - Stylized initials circle when no valid photo is available or image load fails
class PartnerAvatarWidget extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;
  final Color? accentColor;
  final bool showBorder;

  const PartnerAvatarWidget({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 22,
    this.accentColor,
    this.showBorder = false,
  });

  static String extractInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '♥';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  Widget _buildInitials(Color color, String initials) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: color,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: (radius * 0.72).clamp(11.0, 26.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.primaryRose;
    final raw = avatarUrl?.trim() ?? '';
    final initials = extractInitials(name);
    final diameter = radius * 2;

    ImageProvider? backgroundImage;
    Widget? imageWidget;
    if (raw.startsWith('data:image/') || raw.startsWith('base64:')) {
      final Uint8List? bytes = PhotoBudgetUtils.decodeCachedBase64(raw);
      if (bytes != null && bytes.isNotEmpty) {
        backgroundImage = MemoryImage(bytes);
        imageWidget = Image.memory(
          bytes,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitials(color, initials),
        );
      }
    } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
      backgroundImage = NetworkImage(raw);
      imageWidget = Image.network(
        raw,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitials(color, initials),
      );
    }

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: color,
      backgroundImage: backgroundImage,
      onBackgroundImageError: backgroundImage != null ? (_, __) {} : null,
      child: imageWidget != null
          ? ClipOval(child: imageWidget)
          : Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: (radius * 0.72).clamp(11.0, 26.0),
              ),
            ),
    );

    if (!showBorder) return avatar;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: avatar,
    );
  }
}
