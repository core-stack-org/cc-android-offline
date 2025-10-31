import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:nrmflutter/container_flow/container_manager.dart';
import 'package:nrmflutter/utils/utility.dart';

import '../utils/s3_helper.dart';
import '../config/aws_config.dart';

class RasterLayerDownloader {
  final Function(String layerName, double progress) onProgressUpdate;
  final String geoserverUrl = 'https://geoserver.core-stack.org:8443/';
  Map<String, bool> layerCancelled = {};
  late S3Helper s3Helper;

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

    s3Helper = S3Helper(
      accessKey: AWSConfig.accessKey,
      secretKey: AWSConfig.secretKey,
      region: AWSConfig.region,
      bucketName: AWSConfig.bucketName,
    );

    final districtFormatted = formatNameForGeoServer(district ?? '');
    final blockFormatted = formatNameForGeoServer(block ?? '');

    print("Formatted district: $districtFormatted, block: $blockFormatted");

    final clartLayerName = 'clart_${districtFormatted}_${blockFormatted}';

    if (layerCancelled[clartLayerName] == true) {
      print("CLART download cancelled, skipping");
      onProgressUpdate(clartLayerName, -1.0);
      return;
    }

    //final clartUrl = '${geoserverUrl}geoserver/clart/wcs?service=WCS&version=2.0.1&request=GetCoverage&CoverageId=clart:${districtFormatted}_${blockFormatted}_clart&styles=testClart&format=geotiff&compression=LZW&tiling=false';

    onProgressUpdate(clartLayerName, 0.0);

    try {
      // await downloadImageLayer(
      //   layerName: clartLayerName,
      //   url: clartUrl,
      //   container: container,
      // );
      final clartTifContent = await s3Helper.downloadFileBytes('clart_theni_periyakulam_clart.tif');

      if (clartTifContent != null && clartTifContent.isNotEmpty) {
        // Save the downloaded file
        final directory = await getApplicationDocumentsDirectory();
        final formattedLayerName = formatLayerName(clartLayerName);

        final containerPath =
            '${directory.path}/persistent_offline_data/containers/${container.name}';

        final filePath = '$containerPath/image_layers/$formattedLayerName.tiff';
        print("Saving CLART layer to: $filePath");

        final file = File(filePath);
        await file.create(recursive: true);

        // Write the bytes to file
        await file.writeAsBytes(clartTifContent);

        final fileSize = await file.length();
        print("Successfully saved CLART layer: $clartLayerName");
        print("File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB");
        
        // Verify file was written correctly
        if (await file.exists()) {
          print("✅ File verification: CLART file exists at $filePath");
          onProgressUpdate(clartLayerName, 1.0);
        } else {
          print("❌ File verification failed: CLART file does not exist");
          onProgressUpdate(clartLayerName, -1.0);
        }
      } else {
        print("❌ Failed to download CLART from S3: received null or empty content");
        onProgressUpdate(clartLayerName, -1.0);
      }

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

  // PNG (WMS) alternative: render server-side styled PNG and save with bbox sidecar
  Future<void> downloadImageLayersAsPng({
    required OfflineContainer container,
    required String? district,
    required String? block,
  }) async {
    final districtFormatted = formatNameForGeoServer(district ?? '');
    final blockFormatted = formatNameForGeoServer(block ?? '');

    // CLART
    final clartLayerBase = '${districtFormatted}_${blockFormatted}_clart';
    final clartWorkspace = 'clart';
    final clartLayerQualified = '$clartWorkspace:$clartLayerBase';
    final clartOutName = 'clart_${districtFormatted}_${blockFormatted}';

    try {
      final clartBbox = await _fetchCoverageBBox(clartLayerQualified);
      if (clartBbox != null) {
        await _downloadStyledPng(
          container: container,
          layerOutName: clartOutName,
          qualifiedLayerName: clartLayerQualified,
          styleName: 'testClart',
          bbox4326: clartBbox,
          width: 2048,
          height: 2048,
        );
        onProgressUpdate(clartOutName, 1.0);
      } else {
        onProgressUpdate(clartOutName, -1.0);
      }
    } catch (e) {
      onProgressUpdate(clartOutName, -1.0);
    }

    // LULC years
    final yearDataLulc = [
      "17_18",
      "18_19",
      "19_20",
      "20_21",
      "21_22",
      "22_23",
      "23_24"
    ];

    for (final yearValue in yearDataLulc) {
      final lulcLayerBase = 'LULC_${yearValue}_${blockFormatted}_level_3';
      final lulcWorkspace = 'LULC_level_3';
      final lulcLayerQualified = '$lulcWorkspace:$lulcLayerBase';
      final lulcOutName = 'lulc_${yearValue}_${blockFormatted}';

      if (layerCancelled[lulcOutName] == true ||
          layerCancelled['lulc_$yearValue'] == true) {
        onProgressUpdate(lulcOutName, -1.0);
        continue;
      }

      try {
        final lulcBbox = await _fetchCoverageBBox(lulcLayerQualified);
        if (lulcBbox != null) {
          await _downloadStyledPng(
            container: container,
            layerOutName: lulcOutName,
            qualifiedLayerName: lulcLayerQualified,
            styleName: 'lulc_level_3_style',
            bbox4326: lulcBbox,
            width: 2048,
            height: 2048,
          );
          onProgressUpdate(lulcOutName, 1.0);
        } else {
          onProgressUpdate(lulcOutName, -1.0);
        }
      } catch (_) {
        onProgressUpdate(lulcOutName, -1.0);
      }
    }
  }

  Future<List<double>?> _fetchCoverageBBox(String qualifiedCoverageId) async {
    // WCS DescribeCoverage to get bbox (EPSG:4326)
    try {
      final uri = Uri.parse(
          '${geoserverUrl}geoserver/wcs?service=WCS&version=2.0.1&request=DescribeCoverage&coverageId=${Uri.encodeComponent(qualifiedCoverageId)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return null;
      final body = resp.body;

      // naive parse for lowerCorner/upperCorner
      final lowerMatch = RegExp(
              r'<gml:lowerCorner>\s*([\d\.-]+)\s+([\d\.-]+)\s*</gml:lowerCorner>')
          .firstMatch(body);
      final upperMatch = RegExp(
              r'<gml:upperCorner>\s*([\d\.-]+)\s+([\d\.-]+)\s*</gml:upperCorner>')
          .firstMatch(body);
      if (lowerMatch == null || upperMatch == null) return null;

      final coord1 = double.parse(lowerMatch.group(1)!);
      final coord2 = double.parse(lowerMatch.group(2)!);
      final coord3 = double.parse(upperMatch.group(1)!);
      final coord4 = double.parse(upperMatch.group(2)!);

      // GeoServer may return coordinates in lat,lon order (EPSG:4326 axis order)
      // We need lon,lat for WMS bbox. Check if we need to swap.
      // Longitude ranges: 85-87, Latitude ranges: 24-25 for this region
      // If first coordinate is < 50, it's likely latitude, so swap
      double minx, miny, maxx, maxy;
      if (coord1 < 50) {
        // Coordinates are in lat,lon order - swap them
        minx = coord2;
        miny = coord1;
        maxx = coord4;
        maxy = coord3;
        print('Swapped coordinates from lat,lon to lon,lat');
      } else {
        // Coordinates are already in lon,lat order
        minx = coord1;
        miny = coord2;
        maxx = coord3;
        maxy = coord4;
      }

      return [minx, miny, maxx, maxy];
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadStyledPng({
    required OfflineContainer container,
    required String layerOutName,
    required String qualifiedLayerName,
    required String styleName,
    required List<double> bbox4326,
    required int width,
    required int height,
  }) async {
    if (layerCancelled[layerOutName] == true) {
      onProgressUpdate(layerOutName, -1.0);
      return;
    }

    print('Downloading PNG for layer: $layerOutName');
    print(
        'BBox: ${bbox4326[0]}, ${bbox4326[1]}, ${bbox4326[2]}, ${bbox4326[3]}');

    final wmsUrl = Uri.parse('${geoserverUrl}geoserver/wms').replace(
      queryParameters: {
        'service': 'WMS',
        'version': '1.1.1',
        'request': 'GetMap',
        'layers': qualifiedLayerName,
        'styles': styleName,
        'srs': 'EPSG:4326',
        'bbox': '${bbox4326[0]},${bbox4326[1]},${bbox4326[2]},${bbox4326[3]}',
        'width': width.toString(),
        'height': height.toString(),
        'format': 'image/png',
        'transparent': 'false',
        'tiled': 'false',
      },
    );

    print('WMS URL: $wmsUrl');

    final client = http.Client();
    try {
      onProgressUpdate(layerOutName, 0.1);

      final resp = await client.get(wmsUrl).timeout(const Duration(minutes: 2));

      if (resp.statusCode != 200) {
        print('WMS GetMap failed with status: ${resp.statusCode}');
        print(
            'Response body: ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}');
        throw Exception('WMS GetMap failed: ${resp.statusCode}');
      }

      onProgressUpdate(layerOutName, 0.5);

      final directory = await getApplicationDocumentsDirectory();
      final formattedLayerName = formatLayerName(layerOutName);
      final containerPath =
          '${directory.path}/persistent_offline_data/containers/${container.name}';
      final imageLayersDir = '$containerPath/image_layers';
      final pngPath = '$imageLayersDir/$formattedLayerName.png';
      final jsonPath = '$imageLayersDir/$formattedLayerName.json';

      await Directory(imageLayersDir).create(recursive: true);

      final pngFile = File(pngPath);
      await pngFile.writeAsBytes(resp.bodyBytes);

      print('PNG saved to: $pngPath (${resp.bodyBytes.length} bytes)');

      onProgressUpdate(layerOutName, 0.8);

      // Ensure bbox is in correct lon,lat order for OpenLayers
      // bbox4326 should already be [minLon, minLat, maxLon, maxLat] after the swap
      final sidecar = {
        'layerName': layerOutName,
        'qualifiedLayerName': qualifiedLayerName,
        'bbox': bbox4326,
        'crs': 'EPSG:4326',
        'width': width,
        'height': height,
        'style': styleName,
        'imageExtent': bbox4326,
        'projection': 'EPSG:4326',
        'format': 'png',
        'downloadedAt': DateTime.now().toIso8601String(),
      };

      final jsonFile = File(jsonPath);
      await jsonFile.writeAsString(json.encode(sidecar));

      print('Metadata saved to: $jsonPath');
      onProgressUpdate(layerOutName, 1.0);
    } catch (e) {
      print('Error downloading PNG layer $layerOutName: $e');
      onProgressUpdate(layerOutName, -1.0);
      rethrow;
    } finally {
      client.close();
    }
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
