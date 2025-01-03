import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class OfflineAssetsManager {
  static const String WEBAPP_ASSET_PATH = 'assets/webapp';
  static const String CONTAINERS_DIR = 'containers';
  static const String WEBAPP_DIR = 'webapp';
  static const String VECTOR_LAYERS_DIR = 'vector_layers';
  static const String BASE_MAP_TILES_DIR = 'base_map_tiles';
  static const String RASTER_LAYERS_DIR = 'raster_layers';

  /// Copies all required offline assets to the persistent storage
  static Future<void> copyOfflineAssets() async {
    final directory = await getApplicationDocumentsDirectory();
    final persistentOfflineDataPath = path.join(directory.path, 'persistent_offline_data');
    
    // Create base directories
    await Directory(persistentOfflineDataPath).create(recursive: true);
    await Directory(path.join(persistentOfflineDataPath, CONTAINERS_DIR)).create(recursive: true);
    
    // Copy webapp files
    await _copyWebappFiles(persistentOfflineDataPath);
    
    print('Offline assets copied successfully to: $persistentOfflineDataPath');
  }

  /// Copies webapp files from assets to persistent storage
  static Future<void> _copyWebappFiles(String persistentOfflineDataPath) async {
    final webappDir = path.join(persistentOfflineDataPath, WEBAPP_DIR);
    await Directory(webappDir).create(recursive: true);

    // Create static directories
    await Directory(path.join(webappDir, 'static', 'js')).create(recursive: true);
    await Directory(path.join(webappDir, 'static', 'css')).create(recursive: true);

    // Copy index.html
    await _copyAsset(
      'assets/webapp/index.html',
      path.join(webappDir, 'index.html'),
    );

    // Copy JS files
    await _copyAsset(
      'assets/webapp/static/js/main.js',
      path.join(webappDir, 'static', 'js', 'main.js'),
    );

    // Copy CSS files
    await _copyAsset(
      'assets/webapp/static/css/main.css',
      path.join(webappDir, 'static', 'css', 'main.css'),
    );
  }

  /// Creates a new container directory with required subdirectories
  static Future<void> createContainer(String containerName) async {
    final directory = await getApplicationDocumentsDirectory();
    final containerPath = path.join(
      directory.path,
      'persistent_offline_data',
      CONTAINERS_DIR,
      containerName,
    );

    // Create container subdirectories
    await Directory(path.join(containerPath, VECTOR_LAYERS_DIR)).create(recursive: true);
    await Directory(path.join(containerPath, BASE_MAP_TILES_DIR)).create(recursive: true);
    await Directory(path.join(containerPath, RASTER_LAYERS_DIR)).create(recursive: true);

    print('Container created at: $containerPath');
  }

  /// Copies a single asset file to the persistent storage
  static Future<void> _copyAsset(String assetPath, String targetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await File(targetPath).writeAsBytes(bytes);
      print('Copied asset: $assetPath -> $targetPath');
    } catch (e) {
      print('Error copying asset $assetPath: $e');
      rethrow;
    }
  }

  /// Deletes a container and all its data
  static Future<void> deleteContainer(String containerName) async {
    final directory = await getApplicationDocumentsDirectory();
    final containerPath = path.join(
      directory.path,
      'persistent_offline_data',
      CONTAINERS_DIR,
      containerName,
    );

    try {
      final containerDir = Directory(containerPath);
      if (await containerDir.exists()) {
        await containerDir.delete(recursive: true);
        print('Container deleted: $containerPath');
      }
    } catch (e) {
      print('Error deleting container $containerName: $e');
      rethrow;
    }
  }
}
