import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CacheService {
  Future<bool> clearWebViewCache() async {
    try {
      await InAppWebViewController.clearAllCache();

      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        final cacheFiles = cacheDir.listSync();
        for (var file in cacheFiles) {
          try {
            if (file is File) {
              await file.delete();
            } else if (file is Directory) {
              await file.delete(recursive: true);
            }
          } catch (e) {
            print('Error deleting cache file: $e');
          }
        }
      }

      return true;
    } catch (e) {
      print('Error clearing cache: $e');
      return false;
    }
  }

  Future<bool> clearCookies() async {
    try {
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();
      return true;
    } catch (e) {
      print('Error clearing cookies: $e');
      return false;
    }
  }

  Future<bool> clearAllWebViewData() async {
    try {
      final cacheCleared = await clearWebViewCache();
      final cookiesCleared = await clearCookies();
      return cacheCleared && cookiesCleared;
    } catch (e) {
      print('Error clearing all webview data: $e');
      return false;
    }
  }
}
