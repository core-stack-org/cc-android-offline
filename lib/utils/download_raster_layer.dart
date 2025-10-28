import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:nrmflutter/container_flow/container_manager.dart';
import 'package:nrmflutter/utils/utility.dart';

class RasterLayerDownloader {
  final Function(String layerName, double progress) onProgressUpdate;
  final String geoserverUrl = 'https://geoserver.core-stack.org:8443/';
  Map<String, bool> layerCancelled = {};

  RasterLayerDownloader({required this.onProgressUpdate});

  String formatLayerName(String layerName) {
    return layerName.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> downloadImageLayers({
    required OfflineContainer container,
    required String? district,
    required String? block,
  }) async {
    print("Starting downloadImageLayers");

    final districtFormatted = formatNameForGeoServer(district ?? '');
    final blockFormatted = formatNameForGeoServer(block ?? '');

    print("Formatted district: $districtFormatted, block: $blockFormatted");

    final clartLayerName = 'clart_${districtFormatted}_${blockFormatted}';

    if (layerCancelled[clartLayerName] == true) {
      print("CLART download cancelled, skipping");
      onProgressUpdate(clartLayerName, -1.0);
      return;
    }

    final clartUrl =
        '${geoserverUrl}geoserver/clart/wcs?service=WCS&version=2.0.1&request=GetCoverage&CoverageId=clart:${districtFormatted}_${blockFormatted}_clart&styles=testClart&format=geotiff&compression=LZW&tiling=false';

    onProgressUpdate(clartLayerName, 0.0);

    try {
      await downloadImageLayer(
        layerName: clartLayerName,
        url: clartUrl,
        container: container,
      );
      print("Successfully downloaded CLART layer: $clartLayerName");
    } catch (e) {
      print("Error downloading CLART layer: $e");
      onProgressUpdate(clartLayerName, -1.0);
    }

    final yearDataLulc = [
      "17_18",
      "18_19",
      "19_20",
      "20_21",
      "21_22",
      "22_23",
      "23_24"
    ];

    for (var yearValue in yearDataLulc) {
      final lulcLayerName = 'lulc_${yearValue}_${blockFormatted}';

      if (layerCancelled[lulcLayerName] == true ||
          layerCancelled['lulc_$yearValue'] == true) {
        print("LULC layer for year $yearValue is cancelled, skipping");
        onProgressUpdate(lulcLayerName, -1.0);
        continue;
      }

      final lulcUrl =
          '${geoserverUrl}geoserver/LULC_level_3/wcs?service=WCS&version=2.0.1&request=GetCoverage&CoverageId=LULC_level_3:LULC_${yearValue}_${blockFormatted}_level_3&styles=lulc_level_3_style&format=geotiff&compression=LZW&tiling=false';

      onProgressUpdate(lulcLayerName, 0.0);

      try {
        await downloadImageLayer(
          layerName: lulcLayerName,
          url: lulcUrl,
          container: container,
        );
        print("Successfully downloaded LULC layer: $lulcLayerName");
      } catch (e) {
        print("Error downloading LULC layer $lulcLayerName: $e");
        onProgressUpdate(lulcLayerName, -1.0);
      }
    }

    print("Finished downloadImageLayers");
  }

  Future<void> downloadImageLayer({
    required String layerName,
    required String url,
    required OfflineContainer container,
  }) async {
    File? file;
    IOSink? sink;

    try {
      print(
          "Starting download of image layer: $layerName for container: ${container.name}");
      print("URL: $url");

      if (layerCancelled[layerName] == true) {
        onProgressUpdate(layerName, -1.0);
        return;
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));

      final response = await client.send(request).timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          client.close();
          throw Exception('Download timeout after 10 minutes');
        },
      );

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final formattedLayerName = formatLayerName(layerName);

        final containerPath =
            '${directory.path}/persistent_offline_data/containers/${container.name}';

        final filePath = '$containerPath/image_layers/$formattedLayerName.tiff';
        print("Saving image layer to: $filePath");

        file = File(filePath);
        await file.create(recursive: true);

        final totalBytes = response.contentLength ?? 0;
        var bytesWritten = 0;
        var lastProgressUpdate = 0;

        sink = file.openWrite();

        await for (final chunk in response.stream) {
          if (layerCancelled[layerName] == true) {
            print("Download cancelled for $layerName, cleaning up");
            try {
              await sink.close();
              if (await file.exists()) {
                await file.delete();
              }
            } catch (cleanupError) {
              print("Error during cleanup: $cleanupError");
            }
            onProgressUpdate(layerName, -1.0);
            client.close();
            return;
          }

          sink.add(chunk);
          bytesWritten += chunk.length;

          if (totalBytes > 0) {
            final progress = bytesWritten / totalBytes;
            final progressPercent = (progress * 100).round();

            if (progressPercent != lastProgressUpdate &&
                progressPercent % 5 == 0) {
              onProgressUpdate(layerName, progress);
              lastProgressUpdate = progressPercent;
            }
          }
        }

        await sink.close();
        client.close();
        print("Successfully saved image layer $layerName");
        onProgressUpdate(layerName, 1.0);
      } else {
        print(
            "Failed to download $layerName. Status code: ${response.statusCode}");
        throw Exception(
            'Failed to download $layerName. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading image layer $layerName: $e');

      try {
        if (sink != null) {
          await sink.close();
        }
        if (file != null && await file.exists()) {
          await file.delete();
          print("Cleaned up incomplete file for $layerName");
        }
      } catch (cleanupError) {
        print("Error during cleanup: $cleanupError");
      }

      onProgressUpdate(layerName, -1.0);
      rethrow;
    }
  }

  void cancelDownload(String layerName) {
    layerCancelled[layerName] = true;
  }

  void cancelAllDownloads() {
    layerCancelled.forEach((key, value) {
      layerCancelled[key] = true;
    });
  }
}
