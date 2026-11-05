import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Information about an application update retrieved from GitHub Releases.
class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String? releaseNotes;
  final bool hasUpdate;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.hasUpdate,
    this.releaseNotes,
  });

  @override
  String toString() =>
      'AppUpdateInfo(current: $currentVersion, latest: $latestVersion, hasUpdate: $hasUpdate, url: $downloadUrl)';
}

/// Service that checks for GitHub Releases updates and triggers OTA APK installs.
class AppUpdateService {
  static const String defaultRepo = 'guilhermerennaudesouza/couple-app';

  final http.Client _client;

  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// Compares [currentVersion] and [latestTag] using Semantic Versioning (SemVer).
  ///
  /// Returns `true` only if [latestTag] is strictly greater than [currentVersion].
  static bool isVersionNewer(String currentVersion, String latestTag) {
    try {
      final currentParts = _parseSemver(currentVersion);
      final latestParts = _parseSemver(latestTag);

      if (currentParts == null || latestParts == null) return false;

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static List<int>? _parseSemver(String versionStr) {
    if (versionStr.trim().isEmpty) return null;

    // Remove leading 'v' or 'V'
    String clean = versionStr.trim();
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1);
    }

    // Remove build metadata e.g. "+1" or "-beta"
    if (clean.contains('+')) {
      clean = clean.split('+').first;
    }
    if (clean.contains('-')) {
      clean = clean.split('-').first;
    }

    final segments = clean.split('.');
    if (segments.isEmpty) return null;

    final List<int> parts = [];
    for (int i = 0; i < 3; i++) {
      if (i < segments.length) {
        final parsed = int.tryParse(segments[i]);
        if (parsed == null) return null;
        parts.add(parsed);
      } else {
        parts.add(0);
      }
    }
    return parts;
  }

  /// Checks the latest GitHub release for [repo].
  ///
  /// Returns [AppUpdateInfo] if a release was found, or `null` if the check failed.
  Future<AppUpdateInfo?> checkForUpdate({
    String? currentVersionOverride,
    String repo = defaultRepo,
  }) async {
    try {
      String currentVer = currentVersionOverride ?? '';
      if (currentVer.isEmpty) {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVer = packageInfo.version;
      }

      final url = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'CoupleApp-OTA-Updater',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('AppUpdateService: GitHub returned ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final body = json['body'] as String?;
      final assets = json['assets'] as List<dynamic>? ?? [];

      String downloadUrl = '';
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          final browserUrl = asset['browser_download_url'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = browserUrl;
            // Prefer arm64 or release apk if multiple
            if (name.contains('arm64') || name.contains('release')) {
              break;
            }
          }
        }
      }

      if (downloadUrl.isEmpty && tagName.isNotEmpty) {
        downloadUrl =
            'https://github.com/$repo/releases/download/$tagName/CoupleApp-Release.apk';
      }

      final hasUpdate = isVersionNewer(currentVer, tagName);

      return AppUpdateInfo(
        currentVersion: currentVer,
        latestVersion: tagName,
        downloadUrl: downloadUrl,
        hasUpdate: hasUpdate,
        releaseNotes: body,
      );
    } catch (e) {
      debugPrint('AppUpdateService.checkForUpdate error: $e');
      return null;
    }
  }

  /// Initiates OTA APK download and triggers the native package installer.
  Stream<OtaEvent> startOtaUpdate(String downloadUrl) {
    return OtaUpdate().execute(
      downloadUrl,
      destinationFilename: 'CoupleApp-Update.apk',
    );
  }
}

/// Riverpod provider for [AppUpdateService]
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});
