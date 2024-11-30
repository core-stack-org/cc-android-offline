import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;

class OfflineAssetsManager {
  static const String _persistentFolderName = 'persistent_offline_data';

  static Future<String> get _persistentOfflinePath async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, _persistentFolderName);
  }

  static Future<bool> offlineDataExists() async {
    final directory = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${directory.path}/assets/offline_data');
    final persistentOfflineDir = Directory(await _persistentOfflinePath);
    return await offlineDir.exists() && await persistentOfflineDir.exists();
  }

  static Future<void> copyOfflineAssets({bool forceUpdate = false}) async {
    final directory = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${directory.path}/assets/offline_data');
    final persistentOfflineDir = Directory(await _persistentOfflinePath);

    if (await offlineDataExists() && !forceUpdate) {
      print('Offline data already exists in both locations. Skipping copy.');
      await _listDirectoryContents(offlineDir);
      await _listDirectoryContents(persistentOfflineDir);
      return;
    }

    // Copy webapp from assets to device storage
    await copyWebappFromAssets();

    await persistentOfflineDir.create(recursive: true);

    // Copy specific directories to persistent offline directory
    await _copySpecificDirectories(offlineDir.path, persistentOfflineDir.path);
    print(
        'Specific directories copied to persistent location: ${persistentOfflineDir.path}');

    await _listDirectoryContents(offlineDir);
    await _listDirectoryContents(persistentOfflineDir);

    if (await verifyOfflineData()) {
      print('Offline data verified successfully.');
    } else {
      print('Offline data verification failed. Some files may be missing.');
    }
  }

  static Future<void> _copyDirectory(String source, String destination) async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      print('Assets in manifest: ${manifestMap.keys.length}');

      int copiedFiles = 0;
      for (final asset in manifestMap.keys) {
        if (asset.startsWith(source)) {
          try {
            final fileData = await rootBundle.load(asset);
            final fileBytes = fileData.buffer.asUint8List();
            final relativePath = asset.substring(source.length + 1);
            final filePath = path.join(destination, relativePath);
            final file = File(filePath);
            await file.create(recursive: true);
            await file.writeAsBytes(fileBytes);
            print('Copied: $asset to $filePath');
            copiedFiles++;
          } catch (e) {
            print('Error copying asset $asset: $e');
          }
        }
      }
      print('Total files copied: $copiedFiles');
    } catch (e) {
      print('Error reading asset manifest: $e');
    }
  }

  static Future<void> _copySpecificDirectories(
      String source, String destination) async {
    final directories = ['base_map_tiles', 'vector_layers', 'webapp'];

    for (final dir in directories) {
      final sourceDir = Directory(path.join(source, dir));
      final destDir = Directory(path.join(destination, dir));

      if (await sourceDir.exists()) {
        await destDir.create(recursive: true);
        await for (final entity in sourceDir.list(recursive: true)) {
          if (entity is File) {
            final relativePath =
                path.relative(entity.path, from: sourceDir.path);
            final destPath = path.join(destDir.path, relativePath);
            final destFile = File(destPath);
            if (!await destFile.exists()) {
              await entity.copy(destPath);
              print('Copied file: ${entity.path} to $destPath');
            } else {
              print('File already exists, skipping: $destPath');
            }
          } else if (entity is Directory) {
            final relativePath =
                path.relative(entity.path, from: sourceDir.path);
            final newDir = Directory(path.join(destDir.path, relativePath));
            await newDir.create(recursive: true);
            print('Created directory: ${newDir.path}');
          }
        }
        print('Copied $dir to persistent location');
      } else {
        print('Source directory $dir does not exist');
      }
    }
  }

  static Future<void> copyWebappFromAssets() async {
    final directory = await getApplicationDocumentsDirectory();
    final offlineDir =
        Directory('${directory.path}/assets/offline_data/webapp');
    await offlineDir.create(recursive: true);

    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      for (final asset in manifestMap.keys) {
        if (asset.startsWith('assets/offline_data/webapp/')) {
          final fileData = await rootBundle.load(asset);
          final fileBytes = fileData.buffer.asUint8List();
          final filePath = path.join(directory.path, asset);
          final file = File(filePath);
          await file.create(recursive: true);
          await file.writeAsBytes(fileBytes);
          print('Copied webapp asset: $asset to $filePath');
        }
      }
    } catch (e) {
      print('Error copying webapp from assets: $e');
    }
  }

  static Future<void> _listDirectoryContents(Directory dir) async {
    print('Listing contents of directory: ${dir.path}');
    try {
      await for (var entity in dir.list(recursive: true)) {
        print(entity.path);
      }
    } catch (e) {
      print('Error listing directory contents: $e');
    }
  }

  // static Future<bool> verifyOfflineData() async {
  //   final directory = await getApplicationDocumentsDirectory();
  //   final offlineDir = Directory('${directory.path}/assets/offline_data');
  //   final persistentOfflineDir = Directory(await _persistentOfflinePath);

  //   List<String> requiredFiles = [
  //     // 'vector_layers/admin_boundaries.geojson',
  //     // 'vector_layers/nrega_assets.geojson',
  //     // 'webapp/index.html',
  //     // 'webapp/static/js/main.js',
  //     // 'webapp/static/css/main.css',
  //     // Add other required files from your React build
  //   ];

  //   for (String file in requiredFiles) {
  //     if (!await File(path.join(offlineDir.path, file)).exists() ||
  //         !await File(path.join(persistentOfflineDir.path, file)).exists()) {
  //       print('Missing required file: $file');
  //       return false;
  //     }
  //   }

  //   // Verify base map tiles in both locations
  //   for (var dir in [offlineDir, persistentOfflineDir]) {
  //     final baseMapTilesDir = Directory(path.join(dir.path, 'base_map_tiles'));
  //     if (!await baseMapTilesDir.exists()) {
  //       print('Base map tiles directory is missing in ${dir.path}');
  //       return false;
  //     }

  //     if (!await File(path.join(baseMapTilesDir.path, '17/0/0.png')).exists()) {
  //       print('Sample base map tile is missing in ${dir.path}');
  //       return false;
  //     }
  //   }

  //   return true;
  // }

  static Future<bool> verifyOfflineData() async {
    final directory = await getApplicationDocumentsDirectory();
    final persistentOfflineDir = Directory(await _persistentOfflinePath);

    // Required folders to check
    final requiredFolders = ['base_map_tiles', 'vector_layers'];

    try {
      // Check if the root persistent offline directory exists
      if (!await persistentOfflineDir.exists()) {
        print('Persistent offline directory does not exist');
        return false;
      }

      // Check each required folder
      for (String folder in requiredFolders) {
        final folderPath = path.join(persistentOfflineDir.path, folder);
        final folderDir = Directory(folderPath);

        if (!await folderDir.exists()) {
          print('Required folder missing: $folder');
          return false;
        }

        // Check if the folder has any contents
        final contents = await folderDir.list().toList();
        if (contents.isEmpty) {
          print('Required folder is empty: $folder');
          return false;
        }

        print('Verified folder exists with contents: $folder');
      }

      print('All required folders verified successfully');
      return true;
    } catch (e) {
      print('Error during offline data verification: $e');
      return false;
    }
  }

  static Future<void> clearOfflineData() async {
    final directory = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${directory.path}/assets/offline_data');
    final persistentOfflineDir = Directory(await _persistentOfflinePath);

    if (await offlineDir.exists()) {
      await offlineDir.delete(recursive: true);
      print('Regular offline data cleared.');
    }

    if (await persistentOfflineDir.exists()) {
      await persistentOfflineDir.delete(recursive: true);
      print('Persistent offline data cleared.');
    }

    if (!await offlineDir.exists() && !await persistentOfflineDir.exists()) {
      print('All offline data cleared.');
    } else {
      print('Error clearing offline data.');
    }
  }
}
