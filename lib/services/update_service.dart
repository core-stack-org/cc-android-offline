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

      final latestVersion = await _getLatestVersionFromPlayStore();

      if (latestVersion == null) {
        return false;
      }

      return _compareVersions(currentVersion, latestVersion);
    } catch (e) {
      print('Error checking for update: $e');
      return false;
    }
  }

  static Future<String?> _getLatestVersionFromPlayStore() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://play.google.com/store/apps/details?id=$playStorePackageId'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final html = response.body;
        final versionMatch = RegExp(
                r'Current Version</div><span class="htlgb"><div class="IQ1z0d"><span class="htlgb">([\d.]+)')
            .firstMatch(html);

        if (versionMatch != null) {
          return versionMatch.group(1);
        }
      }
    } catch (e) {
      print('Error fetching Play Store version: $e');
    }
    return null;
  }

  static bool _compareVersions(String currentVersion, String latestVersion) {
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
