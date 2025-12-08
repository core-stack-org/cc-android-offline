import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class UpdateService {
  static const String playStorePackageId = 'com.corestack.commonsconnect';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$playStorePackageId';
  static const String playStoreIntentUrl =
      'market://details?id=$playStorePackageId';

  static Future<bool> checkForUpdate() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = packageInfo.buildNumber;

      final playStoreData = await _getLatestVersionAndBuildFromPlayStore();

      if (playStoreData == null) {
        return false;
      }

      return _compareVersions(
        currentVersion, 
        playStoreData['version']!, 
        currentBuildNumber,
        playStoreData['build']
      );
    } catch (e) {
      print('Error checking for update: $e');
      return false;
    }
  }

  static Future<Map<String, String>?> _getLatestVersionAndBuildFromPlayStore() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://play.google.com/store/apps/details?id=$playStorePackageId&hl=en&gl=US'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final html = response.body;

        final versionPatterns = [
          RegExp(r'\[\[\["(\d+\.\d+\.?\d*)"\]\]'),
          RegExp(r'"softwareVersion":"(\d+\.\d+\.?\d*)"'),
          RegExp(r',\[\[null,"(\d+\.\d+\.?\d*)"\]\]'),
          RegExp(r'Current Version.*?(\d+\.\d+\.?\d*)'),
        ];

        String? version;
        for (final pattern in versionPatterns) {
          final match = pattern.firstMatch(html);
          if (match != null && match.group(1) != null) {
            final v = match.group(1)!;
            if (_isValidVersion(v)) {
              version = v;
              break;
            }
          }
        }

        final buildPatterns = [
          RegExp(r'versionCode["\s:]+(\d+)'),
          RegExp(r'"installationSize":"[^"]*","numDownloads":"[^"]*","versionCode":"(\d+)"'),
        ];

        String? buildNumber;
        for (final pattern in buildPatterns) {
          final match = pattern.firstMatch(html);
          if (match != null && match.group(1) != null) {
            buildNumber = match.group(1);
            break;
          }
        }

        if (version != null) {
          return {
            'version': version,
            'build': buildNumber ?? '0',
          };
        }
      }
    } catch (e) {
      print('Error fetching Play Store version: $e');
    }
    return null;
  }

  static bool _isValidVersion(String version) {
    final parts = version.split('.');
    if (parts.isEmpty || parts.length > 4) return false;
    for (final part in parts) {
      if (int.tryParse(part) == null) return false;
    }
    return true;
  }

  static bool _compareVersions(
    String currentVersion, 
    String latestVersion, 
    String currentBuildNumber,
    String? latestBuildNumber
  ) {
    final currentParts =
        currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts =
        latestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (int i = 0; i < maxLength; i++) {
      final current = i < currentParts.length ? currentParts[i] : 0;
      final latest = i < latestParts.length ? latestParts[i] : 0;

      if (latest > current) {
        return true;
      } else if (latest < current) {
        return false;
      }
    }

    if (latestBuildNumber != null) {
      final currentBuild = int.tryParse(currentBuildNumber) ?? 0;
      final latestBuild = int.tryParse(latestBuildNumber) ?? 0;
      
      if (latestBuild > currentBuild) {
        return true;
      }
    }

    return false;
  }

  static Future<void> openPlayStore() async {
    try {
      final uri = Platform.isAndroid
          ? Uri.parse(playStoreIntentUrl)
          : Uri.parse(playStoreUrl);

      if (Platform.isAndroid) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(Uri.parse(playStoreUrl),
              mode: LaunchMode.externalApplication);
        }
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening Play Store: $e');
    }
  }
}
