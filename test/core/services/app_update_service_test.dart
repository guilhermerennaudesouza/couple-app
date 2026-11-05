import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:couple_app/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService Semver Comparison Tests', () {
    test('isVersionNewer correctly compares versions', () {
      expect(AppUpdateService.isVersionNewer('1.0.0', 'v1.0.1'), isTrue);
      expect(AppUpdateService.isVersionNewer('1.0.0+1', 'v1.0.1'), isTrue);
      expect(AppUpdateService.isVersionNewer('1.0.0', '1.1.0'), isTrue);
      expect(AppUpdateService.isVersionNewer('1.0.0', '2.0.0'), isTrue);

      expect(AppUpdateService.isVersionNewer('1.0.1', 'v1.0.1'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.0.1', '1.0.0'), isFalse);
      expect(AppUpdateService.isVersionNewer('2.0.0', 'v1.9.9'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.0.0+2', 'v1.0.0'), isFalse);
      expect(AppUpdateService.isVersionNewer('', 'v1.0.0'), isFalse);
      expect(AppUpdateService.isVersionNewer('invalid', 'v1.0.0'), isFalse);
    });
  });

  group('AppUpdateService GitHub Release Fetch Tests', () {
    test('checkForUpdate successfully parses GitHub release with APK asset', () async {
      final mockResponse = {
        'tag_name': 'v1.0.1',
        'name': 'v1.0.1 - Bug fixes & Improvements',
        'body': 'Release notes here',
        'assets': [
          {
            'name': 'CoupleApp-Release.apk',
            'browser_download_url': 'https://github.com/guilhermerennaudesouza/couple-app/releases/download/v1.0.1/CoupleApp-Release.apk',
            'size': 30804628,
          }
        ]
      };

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return http.Response(jsonEncode(mockResponse), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = AppUpdateService(client: client);
      final updateInfo = await service.checkForUpdate(
        currentVersionOverride: '1.0.0',
        repo: 'guilhermerennaudesouza/couple-app',
      );

      expect(updateInfo, isNotNull);
      expect(updateInfo!.hasUpdate, isTrue);
      expect(updateInfo.currentVersion, '1.0.0');
      expect(updateInfo.latestVersion, 'v1.0.1');
      expect(updateInfo.downloadUrl, contains('CoupleApp-Release.apk'));
      expect(updateInfo.releaseNotes, 'Release notes here');
    });

    test('checkForUpdate reports hasUpdate false when on latest or newer version', () async {
      final mockResponse = {
        'tag_name': 'v1.0.0',
        'body': 'Initial release',
        'assets': [
          {
            'name': 'CoupleApp-Release.apk',
            'browser_download_url': 'https://github.com/guilhermerennaudesouza/couple-app/releases/download/v1.0.0/CoupleApp-Release.apk',
          }
        ]
      };

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200, headers: {'content-type': 'application/json'});
      });

      final service = AppUpdateService(client: client);
      final updateInfo = await service.checkForUpdate(
        currentVersionOverride: '1.0.0',
      );

      expect(updateInfo, isNotNull);
      expect(updateInfo!.hasUpdate, isFalse);
    });

    test('checkForUpdate returns null on HTTP error or network failure gracefully', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = AppUpdateService(client: client);
      final updateInfo = await service.checkForUpdate(
        currentVersionOverride: '1.0.0',
      );

      expect(updateInfo, isNull);
    });
  });
}
