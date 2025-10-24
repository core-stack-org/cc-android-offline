import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:nrmflutter/utils/constants.dart';

class BaseMapDownloader {
  bool cancelBaseMapDownload = false;
  final Function(double) onProgressUpdate;

  BaseMapDownloader({required this.onProgressUpdate});

  Future<void> saveTileInfo(
      String basePath, int zoom, int minX, int maxX, int minY, int maxY) async {
    final tileInfo = {
      'minX': minX,
      'maxX': maxX,
      'minY': minY,
      'maxY': maxY,
      'zoom': zoom,
      'downloadDate': DateTime.now().toUtc().toIso8601String(),
    };

    final file = File('$basePath/$zoom/tileInfo.json');
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(tileInfo));
    print('Saved tileInfo.json for zoom level $zoom');
  }

  Future<void> downloadBaseMap(double centerLat, double centerLon,
      double radiusKm, String containerName) async {
    try {
      cancelBaseMapDownload = false;
      int minZoom = 17, maxZoom = 17;

      // Calculate bounding box
      double earthRadius = 6371; // Earth's radius in kilometers
      double latDelta = (radiusKm / earthRadius) * (180 / math.pi);
      double lonDelta = (radiusKm / earthRadius) *
          (180 / math.pi) /
          math.cos(centerLat * math.pi / 180);

      double minLat = centerLat - latDelta;
      double maxLat = centerLat + latDelta;
      double minLon = centerLon - lonDelta;
      double maxLon = centerLon + lonDelta;

      int totalTiles = 0;
      int downloadedTiles = 0;

      for (int z = minZoom; z <= maxZoom; z++) {
        int minX = lon2tile(minLon, z);
        int maxX = lon2tile(maxLon, z);
        int minY = lat2tile(maxLat, z);
        int maxY = lat2tile(minLat, z);
        totalTiles += (maxX - minX + 1) * (maxY - minY + 1);
      }

      print("Total base map tiles to download: $totalTiles");

      final directory = await getApplicationDocumentsDirectory();
      final containerDir = Directory(
          '${directory.path}/persistent_offline_data/containers/$containerName');
      final offlineDir = Directory('${containerDir.path}/base_map_tiles');

      await offlineDir.create(recursive: true);

      for (int z = minZoom; z <= maxZoom; z++) {
        print("Starting download for zoom level $z");
        int minX = lon2tile(minLon, z);
        int maxX = lon2tile(maxLon, z);
        int minY = lat2tile(maxLat, z);
        int maxY = lat2tile(minLat, z);

        // Save tile info before downloading tiles
        await saveTileInfo(offlineDir.path, z, minX, maxX, minY, maxY);

        for (int x = minX; x <= maxX; x++) {
          for (int y = minY; y <= maxY; y++) {
            if (cancelBaseMapDownload) {
              onProgressUpdate(-1.0); // Indicates cancellation
              return;
            }
            await downloadTile(x, y, z, offlineDir.path);
            downloadedTiles++;
            onProgressUpdate(downloadedTiles / totalTiles);
          }
        }
        print("Finished downloading tiles for zoom level $z");
      }

      onProgressUpdate(1.0);
      print("Base map download completed");
    } catch (e) {
      print('Error downloading base map tiles: $e');
      onProgressUpdate(-1.0); // Indicates error
    }
  }

  Future<void> downloadTile(int x, int y, int z, String basePath) async {
    const int maxRetries = 3;
    const Duration timeout = Duration(seconds: 90);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        String url = baseMapTileUrl
            .replaceAll('{x}', x.toString())
            .replaceAll('{y}', y.toString())
            .replaceAll('{z}', z.toString());

        var response = await http.get(Uri.parse(url)).timeout(timeout);

        if (response.statusCode == 200) {
          final file = File('$basePath/$z/$x/$y.png');
          await file.create(recursive: true);
          await file.writeAsBytes(response.bodyBytes);

          if ((x + y + z) % 100 == 0) {
            print("Downloaded tile: x=$x, y=$y, z=$z");
          }
          return; // Success
        } else if (response.statusCode == 429) {
          // Rate limited - wait before retry
          await Future.delayed(Duration(seconds: math.pow(2, attempt).toInt()));
        } else {
          print(
              "Failed to download tile: x=$x, y=$y, z=$z. Status: ${response.statusCode}");
        }
      } catch (e) {
        print(
            "Error downloading tile (attempt ${attempt + 1}/$maxRetries): x=$x, y=$y, z=$z - $e");
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: math.pow(2, attempt).toInt()));
        }
      }
    }

    throw Exception(
        'Failed to download tile after $maxRetries attempts: x=$x, y=$y, z=$z');
  }

  int lon2tile(double lon, int z) {
    return ((lon + 180) / 360 * (1 << z)).floor();
  }

  int lat2tile(double lat, int z) {
    return ((1 -
                math.log(math.tan(lat * math.pi / 180) +
                        1 / math.cos(lat * math.pi / 180)) /
                    math.pi) /
            2 *
            (1 << z))
        .floor();
  }

  void cancelDownload() {
    cancelBaseMapDownload = true;
  }
}
