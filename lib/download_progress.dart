import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nrmflutter/container_flow/container_manager.dart';
//import 'package:nrmflutter/container_flow/container_sheet.dart';
import 'package:nrmflutter/utils/constants.dart';
import 'package:nrmflutter/utils/download_base_map.dart';
import 'package:nrmflutter/utils/download_raster_layer.dart';
import 'package:nrmflutter/utils/layers_config.dart';
import 'package:nrmflutter/utils/offline_asset.dart';
import 'package:nrmflutter/utils/utility.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import './utils/s3_helper.dart';
import './config/aws_config.dart';

class DownloadProgressPage extends StatefulWidget {
  final OfflineContainer container;
  final String? selectedDistrict;
  final String? selectedBlock;
  final String? selectedBlockID;

  const DownloadProgressPage({
    super.key,
    required this.container,
    this.selectedDistrict,
    this.selectedBlock,
    this.selectedBlockID,
  });

  @override
  _DownloadProgressPageState createState() => _DownloadProgressPageState();
}

class _DownloadProgressPageState extends State<DownloadProgressPage> {
  bool isDownloading = false;
  bool isDownloadComplete = false;
  double baseMapProgress = 0.0;
  Map<String, double> vectorLayerProgress = {};
  Map<String, double> imageLayerProgress = {};
  Map<String, bool> layerCancelled = {};
  late BaseMapDownloader baseMapDownloader;
  late RasterLayerDownloader rasterLayerDownloader;
  Future<List<Map<String, String>>>? _cachedLayers;
  bool _isLoadingLayers = false;

  Map<String, double> s3JsonProgress = {};
  Map<String, double> webappProgress = {};
  late S3Helper s3Helper;

  bool isBaseMapExpanded = false;
  bool isAdminBoundariesExpanded = false;
  bool isPlanLayersExpanded = false;
  bool isImageLayersExpanded = false;
  bool isFormDataExpanded = false;
  bool isWebAppExpanded = false;

  Map<String, String> downloadErrors = {};
  bool hasAnyFailures = false;

  bool isRetrying = false;

  @override
  void initState() {
    super.initState();

    s3Helper = S3Helper(
      accessKey: AWSConfig.accessKey,
      secretKey: AWSConfig.secretKey,
      region: AWSConfig.region,
      bucketName: AWSConfig.bucketName,
    );

    baseMapDownloader = BaseMapDownloader(
      onProgressUpdate: (progress) {
        if (mounted) {
          setState(() {
            baseMapProgress = progress;
          });
        }
      },
    );

    rasterLayerDownloader = RasterLayerDownloader(
      onProgressUpdate: (layerName, progress) {
        if (mounted) {
          setState(() {
            imageLayerProgress[layerName] = progress;
          });
        }
      },
    );

    downloadAllLayers(widget.container);
  }

  // *c Downloads webapp static files from S3 and replaces existing files
  Future<void> downloadWebappFiles() async {
    print("Starting downloadWebappFiles from S3");

    final directory = await getApplicationDocumentsDirectory();
    final webappDir =
        Directory('${directory.path}/persistent_offline_data/webapp');

    try {
      print("Downloading webapp manifest...");

      if (mounted) {
        setState(() {
          webappProgress['webapp_manifest'] = 0.1;
        });
      }

      final manifestContent =
          await s3Helper.downloadFile('webapp-manifest.json');
      final manifestData = json.decode(manifestContent);
      final List<String> files = List<String>.from(manifestData['files']);

      print("Found ${files.length} webapp files in manifest");

      if (mounted) {
        setState(() {
          webappProgress['webapp_manifest'] = 0.5;
          webappProgress.clear();
          webappProgress['webapp_manifest'] = 0.5;
          for (final fileKey in files) {
            webappProgress[fileKey] = 0.0;
          }
        });
      }

      if (await webappDir.exists()) {
        print("Clearing old webapp files...");
        await webappDir.delete(recursive: true);
      }

      print(webappDir);
      await webappDir.create(recursive: true);

      if (mounted) {
        setState(() {
          webappProgress['webapp_manifest'] = 1.0;
        });
      }

      List<String> failedWebappFiles = [];

      for (final fileKey in files) {
        if (layerCancelled[fileKey] == true) continue;

        try {
          await downloadWebappFile(
            s3ObjectKey: fileKey,
            localFilePath: fileKey,
            webappDir: webappDir,
          );
          print("Downloaded: $fileKey");
        } catch (e) {
          print("Error downloading $fileKey: $e");
          downloadErrors[fileKey] = e.toString();
          hasAnyFailures = true;
          failedWebappFiles.add(fileKey);
        }
      }

      if (failedWebappFiles.isNotEmpty) {
        throw Exception(
            'Failed to download ${failedWebappFiles.length} webapp file(s): ${failedWebappFiles.join(", ")}');
      }

      print("Finished downloadWebappFiles");
    } catch (e) {
      print("Error in downloadWebappFiles: $e");
      if (mounted) {
        setState(() {
          webappProgress['webapp_manifest'] = -1.0;
        });
      }
      rethrow;
    }
  }

  // * Downloads a single webapp file from S3
  Future<void> downloadWebappFile({
    required String s3ObjectKey,
    required String localFilePath,
    required Directory webappDir,
  }) async {
    try {
      print("Starting download of webapp file: $s3ObjectKey");

      if (layerCancelled[localFilePath] == true) {
        if (mounted) {
          setState(() {
            webappProgress[localFilePath] = -1.0;
          });
        }
        return;
      }

      // Update progress to show download started
      if (mounted) {
        setState(() {
          webappProgress[localFilePath] = 0.1;
        });
      }

      // Determine if file is binary or text
      final isBinary = localFilePath.endsWith('.png') ||
          localFilePath.endsWith('.jpg') ||
          localFilePath.endsWith('.jpeg') ||
          localFilePath.endsWith('.gif') ||
          localFilePath.endsWith('.ico') ||
          localFilePath.endsWith('.woff') ||
          localFilePath.endsWith('.woff2') ||
          localFilePath.endsWith('.ttf');

      // Download from S3
      print("Downloading from S3: s3://${AWSConfig.bucketName}/$s3ObjectKey");

      final filePath = path.join(webappDir.path, localFilePath);
      final file = File(filePath);

      await file.parent.create(recursive: true);

      if (isBinary) {
        final fileBytes = await s3Helper.downloadFileBytes(s3ObjectKey);

        if (mounted) {
          setState(() {
            webappProgress[localFilePath] = 0.8;
          });
        }

        await file.writeAsBytes(fileBytes);
      } else {
        final fileContent = await s3Helper.downloadFile(s3ObjectKey);

        if (mounted) {
          setState(() {
            webappProgress[localFilePath] = 0.8;
          });
        }

        await file.writeAsString(fileContent);
      }

      print("Successfully saved webapp file: $localFilePath");

      // Update progress to complete
      if (mounted) {
        setState(() {
          webappProgress[localFilePath] = 1.0;
        });
      }
    } catch (e) {
      print('Error downloading webapp file $localFilePath: $e');
      if (mounted) {
        setState(() {
          webappProgress[localFilePath] = -1.0;
        });
      }
      rethrow;
    }
  }

  // * Downloads JSON file from S3 and saves it to container directory
  Future<void> downloadS3Json(
      {required String s3ObjectKey,
      required String localFileName,
      required OfflineContainer container}) async {
    try {
      print(
          "Starting download of S3 JSON: $s3ObjectKey for container: ${container.name}");

      if (layerCancelled[localFileName] == true) {
        if (mounted) {
          setState(() {
            s3JsonProgress[localFileName] = -1.0;
          });
        }
        return;
      }

      // Update progress to show download started
      if (mounted) {
        setState(() {
          s3JsonProgress[localFileName] = 0.1;
        });
      }

      // Download from S3
      final jsonContent = await s3Helper.downloadFile(s3ObjectKey);

      // Update progress to show download complete, now saving
      if (mounted) {
        setState(() {
          s3JsonProgress[localFileName] = 0.8;
        });
      }

      final directory = await getApplicationDocumentsDirectory();

      final containerPath =
          '${directory.path}/persistent_offline_data/containers/${container.name}';

      final filePath = '$containerPath/s3_data/$localFileName';
      print("Saving S3 JSON to: $filePath");

      // Create file and save content
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsString(jsonContent);

      print("Successfully saved S3 JSON: $localFileName");

      if (mounted) {
        setState(() {
          s3JsonProgress[localFileName] = 1.0;
        });
      }
    } catch (e) {
      print('Error downloading S3 JSON $localFileName: $e');
      if (mounted) {
        setState(() {
          s3JsonProgress[localFileName] = -1.0;
        });
      }
      rethrow;
    }
  }

  // * Downloads multiple JSON files from S3
  Future<void> downloadS3JsonFiles(OfflineContainer container) async {
    print("Starting downloadS3JsonFiles");

    final s3Files = {
      'add_settlements.json': 'add_settlements.json',
      'add_well.json': 'add_well.json',
      'cropping_pattern.json': 'cropping_pattern.json',
      'feedback_Agri.json': 'feedback_Agri.json',
      'feedback_Groundwater.json': 'feedback_Groundwater.json',
      'feedback_surfacewaterbodies.json': 'feedback_surfacewaterbodies.json',
      'irrigation_work.json': 'irrigation_work.json',
      'livelihood.json': 'livelihood.json',
      'maintenance_irr.json': 'maintenance_irr.json',
      'maintenance_recharge_st.json': 'maintenance_recharge_st.json',
      'maintenance_rs_swb.json': 'maintenance_rs_swb.json',
      'maintenance_water_structures.json': 'maintenance_water_structures.json',
      'recharge_structure.json': 'recharge_structure.json',
      'water_structure.json': 'water_structure.json'
    };

    List<String> failedFiles = [];

    for (var entry in s3Files.entries) {
      final s3ObjectKey = entry.key;
      final localFileName = entry.value;

      print("Processing S3 file: $s3ObjectKey -> $localFileName");

      if (layerCancelled[localFileName] == true) {
        print("S3 file $localFileName is cancelled, skipping");
        continue;
      }

      try {
        await downloadS3Json(
          s3ObjectKey: s3ObjectKey,
          localFileName: localFileName,
          container: container,
        );
        print("Successfully downloaded S3 JSON: $localFileName");
      } catch (e) {
        print("Error downloading S3 JSON $localFileName: $e");
        downloadErrors[localFileName] = e.toString();
        hasAnyFailures = true;
        failedFiles.add(localFileName);
      }
    }

    if (failedFiles.isNotEmpty) {
      throw Exception(
          'Failed to download ${failedFiles.length} S3 JSON file(s): ${failedFiles.join(", ")}');
    }

    print("Finished downloadS3JsonFiles");
  }

  Future<List<Map<String, String>>> getLayers(
      String? district, String? block) async {
    if (_cachedLayers == null && !_isLoadingLayers) {
      _isLoadingLayers = true;
      print(
          "DownloadProgressPage.getLayers called with district: $district, block: $block, blockId: ${widget.selectedBlockID}");
      _cachedLayers = LayersConfig.getLayers(district, block,
          blockId: widget.selectedBlockID);
      await _cachedLayers;
      _isLoadingLayers = false;
    }
    return _cachedLayers!;
  }

  Future<void> downloadVectorLayers(OfflineContainer container) async {
    print("Starting downloadVectorLayers");
    print("Selected block ID: ${widget.selectedBlockID}");

    final layers =
        await getLayers(widget.selectedDistrict, widget.selectedBlock);
    print("Retrieved ${layers.length} layers to download");

    List<String> failedLayers = [];

    for (var layer in layers) {
      print(
          "Processing layer: ${layer['name']} with path: ${layer['geoserverPath']}");
      if (layerCancelled[layer['name']] == true) {
        print("Layer ${layer['name']} is cancelled, skipping");
        continue;
      }

      if (mounted) {
        setState(() {
          vectorLayerProgress[layer['name']!] = 0.0;
        });
      }

      try {
        await downloadVectorLayer(
            layer['name']!, layer['geoserverPath']!, container);
        print("Successfully downloaded layer: ${layer['name']}");
      } catch (e) {
        print("Error downloading layer ${layer['name']}: $e");
        downloadErrors[layer['name']!] = e.toString();
        hasAnyFailures = true;
        failedLayers.add(layer['name']!);
      }
    }

    print("Copying assets to persistent storage");
    await OfflineAssetsManager.copyOfflineAssets(forceUpdate: true);
    print("Finished downloadVectorLayers");

    if (failedLayers.isNotEmpty) {
      throw Exception(
          'Failed to download ${failedLayers.length} vector layer(s): ${failedLayers.join(", ")}');
    }
  }

  String formatLayerName(String layerName) {
    return layerName.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> downloadVectorLayer(String layerName, String geoserverPath,
      OfflineContainer container) async {
    try {
      print(
          "Starting download of vector layer: $layerName for container: ${container.name}");
      if (layerCancelled[layerName] == true) {
        if (mounted) {
          setState(() {
            vectorLayerProgress[layerName] = -1.0;
          });
        }
        return;
      }

      final url =
          '${geoserverUrl}geoserver/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=$geoserverPath&outputFormat=application/json';
      print("Downloading from URL: $url");

      final request =
          await http.Client().send(http.Request('GET', Uri.parse(url)));

      if (request.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final formattedLayerName = formatLayerName(layerName);

        final containerPath =
            '${directory.path}/persistent_offline_data/containers/${container.name}';

        final filePath =
            '$containerPath/vector_layers/$formattedLayerName.geojson';
        print("Saving layer to: $filePath");

        final file = File(filePath);
        await file.create(recursive: true);

        final totalBytes = request.contentLength ?? 0;
        var bytesWritten = 0;

        final sink = file.openWrite();

        await for (final chunk in request.stream) {
          sink.add(chunk);
          bytesWritten += chunk.length;

          if (totalBytes > 0) {
            final progress = bytesWritten / totalBytes;
            if ((progress * 100).round() % 5 == 0) {
              if (mounted) {
                setState(() {
                  vectorLayerProgress[layerName] = progress;
                });
              }
            }
          }
        }

        await sink.close();
        print("Successfully saved layer $layerName");

        if (mounted) {
          setState(() {
            vectorLayerProgress[layerName] = 1.0;
          });
        }
      } else {
        print(
            "Failed to download $layerName. Status code: ${request.statusCode}");
        throw Exception(
            'Failed to download $layerName. Status code: ${request.statusCode}');
      }
    } catch (e) {
      print('Error downloading $layerName: $e');
      if (mounted) {
        setState(() {
          vectorLayerProgress[layerName] = -1.0;
        });
      }
      rethrow;
    }
  }

  Future<void> downloadAllLayers(OfflineContainer container) async {
    print("Starting to download the layers for container: ${container.name}");
    if (mounted) {
      setState(() {
        isDownloading = true;
        baseMapProgress = 0.0;
        vectorLayerProgress.clear();
        layerCancelled.clear();
        isDownloadComplete = false;
        downloadErrors.clear();
        hasAnyFailures = false;

        imageLayerProgress.clear();
        final districtFormatted =
            formatNameForGeoServer(widget.selectedDistrict ?? '');
        final blockFormatted =
            formatNameForGeoServer(widget.selectedBlock ?? '');

        imageLayerProgress['clart_${districtFormatted}_${blockFormatted}'] =
            0.0;
        final yearDataLulc = [
          "17_18",
          "18_19",
          "19_20",
          "20_21",
          "21_22",
          "22_23",
          "23_24"
        ];
        for (var year in yearDataLulc) {
          imageLayerProgress['lulc_${year}_${blockFormatted}'] = 0.0;
        }

        s3JsonProgress.clear();
        final s3Files = [
          'add_settlements.json',
          'add_well.json',
          'cropping_pattern.json',
          'feedback_Agri.json',
          'feedback_Groundwater.json',
          'feedback_surfacewaterbodies.json',
          'irrigation_work.json',
          'livelihood.json',
          'maintenance_irr.json',
          'maintenance_recharge_st.json',
          'maintenance_rs_swb.json',
          'maintenance_water_structures.json',
          'recharge_structure.json',
          'water_structure.json'
        ];
        for (var file in s3Files) {
          s3JsonProgress[file] = 0.0;
        }

        webappProgress.clear();
        webappProgress['webapp_manifest'] = 0.0;
      });
    }

    try {
      double radiusKm = 3.0;
      await baseMapDownloader.downloadBaseMap(
          container.latitude, container.longitude, radiusKm, container.name);

      if (!isDownloading) {
        throw Exception("Download cancelled by user");
      }

      await downloadVectorLayers(container);

      if (!isDownloading) {
        throw Exception("Download cancelled by user");
      }

      await rasterLayerDownloader.downloadImageLayers(
        container: container,
        district: widget.selectedDistrict,
        block: widget.selectedBlock,
      );

      if (!isDownloading) {
        throw Exception("Download cancelled by user");
      }

      await downloadS3JsonFiles(container);

      if (!isDownloading) {
        throw Exception("Download cancelled by user");
      }

      await downloadWebappFiles();

      if (!isDownloading) {
        throw Exception("Download cancelled by user");
      }

      final directory = await getApplicationDocumentsDirectory();
      final containerDir = Directory(
          '${directory.path}/persistent_offline_data/containers/${container.name}');
      final vectorLayersDir = Directory('${containerDir.path}/vector_layers');
      final imageLayersDir = Directory('${containerDir.path}/image_layers');
      final baseMapTilesDir = Directory('${containerDir.path}/base_map_tiles');
      final s3DataDir = Directory('${containerDir.path}/s3_data');

      final webappDir =
          Directory('${directory.path}/persistent_offline_data/webapp');

      print("Verifying directory existence...");
      if (!await vectorLayersDir.exists()) {
        throw Exception("Vector layers directory does not exist");
      }
      if (!await imageLayersDir.exists()) {
        throw Exception("Image layers directory does not exist");
      }
      if (!await baseMapTilesDir.exists()) {
        throw Exception("Base map tiles directory does not exist");
      }
      if (!await s3DataDir.exists()) {
        throw Exception("S3 data directory does not exist");
      }
      if (!await webappDir.exists()) {
        throw Exception("Webapp directory does not exist");
      }

      print("Verifying all downloads are complete...");
      if (!_verifyAllDownloadsComplete()) {
        throw Exception(
            "Download verification failed - not all items completed successfully");
      }

      if (hasAnyFailures) {
        throw Exception(
            "Download completed with failures: ${downloadErrors.keys.join(", ")}");
      }

      print("Offline data verified successfully");

      await ContainerManager.updateContainerDownloadStatus(
          container.name, true);
      print("Container ${container.name} marked as downloaded");

      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloadComplete = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully downloaded data for the region: ${container.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error during layer download: $e");

      final isCancelled = e.toString().contains("cancelled by user");

      await ContainerManager.updateContainerDownloadStatus(
          container.name, false);

      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloadComplete = false;
        });

        if (!isCancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download data: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      if (!isCancelled) {
        rethrow;
      }
    }
  }

  void cancelLayerDownload(String layerName) {
    if (mounted) {
      setState(() {
        if (layerName == 'Base Map') {
          baseMapDownloader.cancelBaseMapDownload = true;
        } else {
          layerCancelled[layerName] = true;
        }
      });
    }
  }

  Future<void> retryBaseMap() async {
    if (isRetrying) return;

    setState(() {
      isRetrying = true;
      baseMapProgress = 0.0;
      downloadErrors.remove('base_map');
      hasAnyFailures = false;
    });

    try {
      double radiusKm = 3.0;
      baseMapDownloader.cancelBaseMapDownload = false;
      await baseMapDownloader.downloadBaseMap(widget.container.latitude,
          widget.container.longitude, radiusKm, widget.container.name);

      if (mounted) {
        setState(() {
          isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Base map downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error retrying base map: $e");
      if (mounted) {
        setState(() {
          isRetrying = false;
          baseMapProgress = -1.0;
          downloadErrors['base_map'] = e.toString();
          hasAnyFailures = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry base map: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> retryVectorLayers() async {
    if (isRetrying) return;

    setState(() {
      isRetrying = true;
    });

    try {
      final layers =
          await getLayers(widget.selectedDistrict, widget.selectedBlock);

      List<Map<String, String>> nonPlanLayers =
          layers.where((layer) => !_isPlanLayer(layer['name']!)).toList();

      List<Map<String, String>> failedLayers = nonPlanLayers
          .where((layer) =>
              (vectorLayerProgress[layer['name']] ?? 0.0) < 0 ||
              downloadErrors.containsKey(layer['name']))
          .toList();

      if (failedLayers.isEmpty) {
        failedLayers = nonPlanLayers;
      }

      for (var layer in failedLayers) {
        if (mounted) {
          setState(() {
            vectorLayerProgress[layer['name']!] = 0.0;
            downloadErrors.remove(layer['name']);
          });
        }

        try {
          await downloadVectorLayer(
              layer['name']!, layer['geoserverPath']!, widget.container);
        } catch (e) {
          print("Error retrying vector layer ${layer['name']}: $e");
        }
      }

      if (mounted) {
        setState(() {
          isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vector layers retry completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error retrying vector layers: $e");
      if (mounted) {
        setState(() {
          isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry vector layers: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> retryPlanLayers() async {
    if (isRetrying) return;

    setState(() {
      isRetrying = true;
    });

    try {
      final layers =
          await getLayers(widget.selectedDistrict, widget.selectedBlock);

      List<Map<String, String>> planLayers =
          layers.where((layer) => _isPlanLayer(layer['name']!)).toList();

      List<Map<String, String>> failedLayers = planLayers
          .where((layer) =>
              (vectorLayerProgress[layer['name']] ?? 0.0) < 0 ||
              downloadErrors.containsKey(layer['name']))
          .toList();

      if (failedLayers.isEmpty) {
        failedLayers = planLayers;
      }

      for (var layer in failedLayers) {
        if (mounted) {
          setState(() {
            vectorLayerProgress[layer['name']!] = 0.0;
            downloadErrors.remove(layer['name']);
          });
        }

        try {
          await downloadVectorLayer(
              layer['name']!, layer['geoserverPath']!, widget.container);
        } catch (e) {
          print("Error retrying plan layer ${layer['name']}: $e");
        }
      }

      if (mounted) {
        setState(() {
          isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan layers retry completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error retrying plan layers: $e");
      if (mounted) {
        setState(() {
          isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry plan layers: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> retryFormData() async {
    if (isRetrying) return;

    setState(() {
      isRetrying = true;
    });

    try {
      List<String> failedFiles = s3JsonProgress.entries
          .where((entry) =>
              entry.value < 0 || downloadErrors.containsKey(entry.key))
          .map((entry) => entry.key)
          .toList();

      if (failedFiles.isEmpty) {
        failedFiles = s3JsonProgress.keys.toList();
      }

      final s3Files = {
        'add_settlements.json': 'add_settlements.json',
        'add_well.json': 'add_well.json',
        'cropping_pattern.json': 'cropping_pattern.json',
        'feedback_Agri.json': 'feedback_Agri.json',
        'feedback_Groundwater.json': 'feedback_Groundwater.json',
        'feedback_surfacewaterbodies.json': 'feedback_surfacewaterbodies.json',
        'irrigation_work.json': 'irrigation_work.json',
        'livelihood.json': 'livelihood.json',
        'maintenance_irr.json': 'maintenance_irr.json',
        'maintenance_recharge_st.json': 'maintenance_recharge_st.json',
        'maintenance_rs_swb.json': 'maintenance_rs_swb.json',
        'maintenance_water_structures.json':
            'maintenance_water_structures.json',
        'recharge_structure.json': 'recharge_structure.json',
        'water_structure.json': 'water_structure.json'
      };

      for (var fileName in failedFiles) {
        if (s3Files.containsKey(fileName)) {
          if (mounted) {
            setState(() {
              s3JsonProgress[fileName] = 0.0;
              downloadErrors.remove(fileName);
            });
          }

          try {
            await downloadS3Json(
              s3ObjectKey: fileName,
              localFileName: fileName,
              container: widget.container,
            );
          } catch (e) {
            print("Error retrying S3 JSON $fileName: $e");
          }
        }
      }

      if (mounted) {
        setState(() {
          isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form data retry completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error retrying form data: $e");
      if (mounted) {
        setState(() {
          isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry form data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> retryImageLayers() async {
    if (isRetrying) return;

    setState(() {
      isRetrying = true;
    });

    try {
      List<String> failedLayers = imageLayerProgress.entries
          .where((entry) =>
              entry.value < 0 ||
              (entry.value >= 0 &&
                  entry.value < 1.0 &&
                  downloadErrors.containsKey(entry.key)))
          .map((entry) => entry.key)
          .toList();

      for (var layerName in failedLayers) {
        if (mounted) {
          setState(() {
            imageLayerProgress[layerName] = 0.0;
            downloadErrors.remove(layerName);
            rasterLayerDownloader.layerCancelled[layerName] = false;
          });
        }
      }

      if (failedLayers.isEmpty) {
        await rasterLayerDownloader.downloadImageLayers(
          container: widget.container,
          district: widget.selectedDistrict,
          block: widget.selectedBlock,
        );
      } else {
        await rasterLayerDownloader.downloadImageLayers(
          container: widget.container,
          district: widget.selectedDistrict,
          block: widget.selectedBlock,
        );
      }

      bool anyFailed = imageLayerProgress.values.any((v) => v < 0);

      if (mounted) {
        setState(() {
          isRetrying = false;
          if (anyFailed) {
            hasAnyFailures = true;
          }
        });

        if (!anyFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image layers downloaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Some image layers failed. Check individual statuses.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print("Error retrying image layers: $e");
      if (mounted) {
        setState(() {
          isRetrying = false;
          hasAnyFailures = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry image layers: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> retryWebApp() async {
    if (isRetrying) return;

    setState(() {
      isRetrying = true;
    });

    try {
      List<String> failedFiles = webappProgress.entries
          .where((entry) =>
              entry.value < 0 || downloadErrors.containsKey(entry.key))
          .map((entry) => entry.key)
          .toList();

      if (failedFiles.isEmpty || failedFiles.contains('webapp_manifest')) {
        await downloadWebappFiles();
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final webappDir =
            Directory('${directory.path}/persistent_offline_data/webapp');

        for (var fileName in failedFiles) {
          if (fileName != 'webapp_manifest') {
            if (mounted) {
              setState(() {
                webappProgress[fileName] = 0.0;
                downloadErrors.remove(fileName);
              });
            }

            try {
              await downloadWebappFile(
                s3ObjectKey: fileName,
                localFilePath: fileName,
                webappDir: webappDir,
              );
            } catch (e) {
              print("Error retrying webapp file $fileName: $e");
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web app files retry completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error retrying web app: $e");
      if (mounted) {
        setState(() {
          isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry web app: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelAllDownloads() async {
    if (!isDownloading || isDownloadComplete) return;

    if (mounted) {
      setState(() {
        isDownloading = false;
        baseMapDownloader.cancelBaseMapDownload = true;
      });

      try {
        final layers =
            await getLayers(widget.selectedDistrict, widget.selectedBlock);
        for (var layer in layers) {
          if (mounted) {
            setState(() {
              layerCancelled[layer['name']!] = true;
            });
          }
        }
      } catch (e) {
        print("Error getting layers for cancellation: $e");
      }

      final s3Files = [
        'add_settlements.json',
        'add_well.json',
        'cropping_pattern.json',
        'feedback_Agri.json',
        'feedback_Groundwater.json',
        'feedback_surfacewaterbodies.json',
        'irrigation_work.json',
        'livelihood.json',
        'maintenance_irr.json',
        'maintenance_recharge_st.json',
        'maintenance_rs_swb.json',
        'maintenance_water_structures.json',
        'recharge_structure.json',
        'water_structure.json'
      ];

      for (var file in s3Files) {
        if (mounted) {
          setState(() {
            layerCancelled[file] = true;
          });
        }
      }

      for (var fileKey in webappProgress.keys) {
        if (mounted) {
          setState(() {
            layerCancelled[fileKey] = true;
          });
        }
      }

      for (var layerKey in imageLayerProgress.keys) {
        if (mounted) {
          setState(() {
            layerCancelled[layerKey] = true;
            rasterLayerDownloader.cancelDownload(layerKey);
          });
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  bool _verifyAllDownloadsComplete() {
    if (baseMapProgress != 1.0) {
      print("Base map not complete: $baseMapProgress");
      return false;
    }

    for (var entry in vectorLayerProgress.entries) {
      if (entry.value != 1.0) {
        print("Vector layer ${entry.key} not complete: ${entry.value}");
        return false;
      }
    }

    for (var entry in s3JsonProgress.entries) {
      if (entry.value != 1.0) {
        print("S3 JSON file ${entry.key} not complete: ${entry.value}");
        return false;
      }
    }

    for (var entry in webappProgress.entries) {
      if (entry.value != 1.0) {
        print("Webapp file ${entry.key} not complete: ${entry.value}");
        return false;
      }
    }

    if (imageLayerProgress.isNotEmpty) {
      for (var entry in imageLayerProgress.entries) {
        if (entry.value != 1.0) {
          print("Image layer ${entry.key} not complete: ${entry.value}");
          return false;
        }
      }
    }

    print("All downloads verified as complete");
    return true;
  }

  bool _isPlanLayer(String layerName) {
    final planLayerPrefixes = [
      'settlement_',
      'well_',
      'waterbody_',
      'main_swb_',
      'plan_agri_',
      'plan_gw_',
      'livelihood_'
    ];

    return planLayerPrefixes.any((prefix) => layerName.startsWith(prefix));
  }

  double _calculatePlanLayersProgress(List<Map<String, String>> allLayers) {
    final planLayers = allLayers.where((layer) => _isPlanLayer(layer['name']!));
    if (planLayers.isEmpty) return 0.0;

    double totalProgress = 0.0;
    int count = 0;

    for (var layer in planLayers) {
      double progress = vectorLayerProgress[layer['name']] ?? 0.0;
      if (progress >= 0) {
        totalProgress += progress;
        count++;
      }
    }

    return count > 0 ? totalProgress / count : 0.0;
  }

  int _getCompletedPlanLayersCount(List<Map<String, String>> allLayers) {
    return allLayers
        .where((layer) =>
            _isPlanLayer(layer['name']!) &&
            (vectorLayerProgress[layer['name']] ?? 0.0) == 1.0)
        .length;
  }

  int _getTotalPlanLayersCount(List<Map<String, String>> allLayers) {
    return allLayers.where((layer) => _isPlanLayer(layer['name']!)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Downloading Layers', style: TextStyle(fontSize: 18.0)),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leadingWidth: 100,
        leading: !isDownloadComplete
            ? Center(
                child: TextButton(
                  onPressed: isRetrying ? null : _cancelAllDownloads,
                  style: TextButton.styleFrom(
                    backgroundColor: isRetrying ? Colors.grey : Colors.red,
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: isRetrying ? Colors.grey : Colors.red,
                        width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: (isDownloadComplete || (!isDownloading && !isRetrying))
                  ? () {
                      if (isDownloadComplete &&
                          _verifyAllDownloadsComplete() &&
                          !hasAnyFailures) {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              title: const Text(
                                'Download Complete',
                                style: TextStyle(
                                  color: Color(0xFF592941),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: const Text(
                                'All layers have been downloaded successfully. You can now access this region offline.',
                                style: TextStyle(
                                  color: Color(0xFF592941),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'OK',
                                    style: TextStyle(
                                      color: Color(0xFF592941),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      } else if (hasAnyFailures ||
                          !_verifyAllDownloadsComplete()) {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              title: const Text(
                                'Download Incomplete',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: const Text(
                                'Some layers failed to download. You can retry failed layers or exit. The container will not be marked as complete.',
                                style: TextStyle(
                                  color: Color(0xFF592941),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      color: Color(0xFF592941),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'Exit Anyway',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  : null,
              style: TextButton.styleFrom(
                foregroundColor:
                    (isDownloadComplete || (!isDownloading && !isRetrying))
                        ? Colors.white
                        : Colors.grey.shade700,
                backgroundColor:
                    (isDownloadComplete || (!isDownloading && !isRetrying))
                        ? (hasAnyFailures ? Colors.orange : Colors.blue)
                        : Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(hasAnyFailures ? 'Exit' : 'Done'),
            ),
          )
        ],
      ),
      body: buildDownloadProgressContent(),
    );
  }

  Widget buildDownloadProgressContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text(
            "Please do not close this page while download is in progress.",
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF592941),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFD6D5C9),
              border: Border.all(color: const Color(0xFF592941), width: 1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              widget.container.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF592941),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFD6D5C9),
              border: Border.all(color: const Color(0xFF592941), width: 1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Downloading Layers",
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF592941),
                  ),
                ),
                const SizedBox(height: 15),
                FutureBuilder<List<Map<String, String>>>(
                  future:
                      getLayers(widget.selectedDistrict, widget.selectedBlock),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      double totalProgress = 0;
                      int totalSections = 0;

                      // Base map progress (1 section)
                      if (baseMapProgress >= 0) {
                        totalProgress += baseMapProgress;
                      }
                      totalSections++;

                      // Non-plan vector layers progress (1 section)
                      List<Map<String, String>> nonPlanLayers = snapshot.data!
                          .where((layer) => !_isPlanLayer(layer['name']!))
                          .toList();

                      if (nonPlanLayers.isNotEmpty) {
                        double vectorProgress = 0;
                        int vectorCount = 0;
                        for (var layer in nonPlanLayers) {
                          double layerProgress =
                              vectorLayerProgress[layer['name']] ?? 0.0;
                          if (layerProgress >= 0) {
                            vectorProgress += layerProgress;
                          }
                          vectorCount++;
                        }
                        totalProgress += (vectorCount > 0
                            ? vectorProgress / vectorCount
                            : 0.0);
                        totalSections++;
                      }

                      // Plan layers progress (1 section)
                      if (_getTotalPlanLayersCount(snapshot.data!) > 0) {
                        double planLayersProgress =
                            _calculatePlanLayersProgress(snapshot.data!);
                        totalProgress += planLayersProgress;
                        totalSections++;
                      }

                      // Image/Raster layers progress (1 section)
                      if (imageLayerProgress.isNotEmpty) {
                        double imageProgress = 0;
                        int imageCount = 0;
                        imageLayerProgress.forEach((fileName, progress) {
                          if (progress >= 0) {
                            imageProgress += progress;
                          }
                          imageCount++;
                        });
                        totalProgress +=
                            (imageCount > 0 ? imageProgress / imageCount : 0.0);
                        totalSections++;
                      }

                      // S3 JSON files progress (1 section)
                      if (s3JsonProgress.isNotEmpty) {
                        double s3Progress = 0;
                        int s3Count = 0;
                        s3JsonProgress.forEach((fileName, progress) {
                          if (progress >= 0) {
                            s3Progress += progress;
                          }
                          s3Count++;
                        });
                        totalProgress +=
                            (s3Count > 0 ? s3Progress / s3Count : 0.0);
                        totalSections++;
                      }

                      // Webapp files progress (1 section)
                      if (webappProgress.isNotEmpty) {
                        double webappProgressTotal = 0;
                        int webappCount = 0;
                        webappProgress.forEach((fileName, progress) {
                          if (progress >= 0) {
                            webappProgressTotal += progress;
                          }
                          webappCount++;
                        });
                        totalProgress += (webappCount > 0
                            ? webappProgressTotal / webappCount
                            : 0.0);
                        totalSections++;
                      }

                      double overallProgress = totalSections > 0
                          ? totalProgress / totalSections
                          : 0.0;

                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: overallProgress,
                              backgroundColor: Colors.white.withAlpha(77),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF592941)),
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "${(overallProgress * 100).toStringAsFixed(1)}%",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF592941),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF592941), width: 1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Download Status",
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF592941),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEBE0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            isBaseMapExpanded = !isBaseMapExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                isBaseMapExpanded
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                                color: const Color(0xFF592941),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "Base Map",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF592941),
                                  ),
                                ),
                              ),
                              if (baseMapProgress == 1.0)
                                const Icon(Icons.check_circle,
                                    color: Colors.green)
                              else if (baseMapProgress > 0 &&
                                  baseMapProgress < 1)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else if (baseMapProgress < 0)
                                Row(
                                  children: [
                                    const Icon(Icons.error, color: Colors.red),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed:
                                          isRetrying ? null : retryBaseMap,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Retry'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor:
                                            const Color(0xFF592941),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                FutureBuilder<List<Map<String, String>>>(
                  future:
                      getLayers(widget.selectedDistrict, widget.selectedBlock),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      List<Map<String, String>> nonPlanLayers = snapshot.data!
                          .where((layer) => !_isPlanLayer(layer['name']!))
                          .toList();

                      List<Widget> items = [];

                      if (nonPlanLayers.isNotEmpty) {
                        int nonPlanCompletedCount = nonPlanLayers
                            .where((layer) =>
                                (vectorLayerProgress[layer['name']] ?? 0.0) ==
                                1.0)
                            .length;

                        items.add(
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEBE0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      isAdminBoundariesExpanded =
                                          !isAdminBoundariesExpanded;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isAdminBoundariesExpanded
                                              ? Icons.expand_more
                                              : Icons.chevron_right,
                                          color: const Color(0xFF592941),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Vector Layers",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                              Text(
                                                "$nonPlanCompletedCount of ${nonPlanLayers.length} completed",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (nonPlanCompletedCount ==
                                                nonPlanLayers.length &&
                                            nonPlanLayers.isNotEmpty)
                                          const Icon(Icons.check_circle,
                                              color: Colors.green)
                                        else if (nonPlanCompletedCount > 0)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else if (nonPlanLayers.any((layer) =>
                                            (vectorLayerProgress[
                                                    layer['name']] ??
                                                0.0) <
                                            0))
                                          Row(
                                            children: [
                                              const Icon(Icons.error,
                                                  color: Colors.red),
                                              const SizedBox(width: 8),
                                              TextButton.icon(
                                                onPressed: isRetrying
                                                    ? null
                                                    : retryVectorLayers,
                                                icon: const Icon(Icons.refresh,
                                                    size: 16),
                                                label: const Text('Retry'),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor:
                                                      const Color(0xFF592941),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                                if (isAdminBoundariesExpanded) ...[
                                  const SizedBox(height: 8),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    child: Divider(
                                      color: Color(0xFFD6D5C9),
                                      thickness: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 12, right: 12, bottom: 8),
                                    child: Column(
                                      children: nonPlanLayers.map((layer) {
                                        final layerName = layer['name']!;
                                        final layerProgress =
                                            vectorLayerProgress[layerName] ??
                                                0.0;

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.layers,
                                                size: 16,
                                                color: Color(0xFF592941),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  layerName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF592941),
                                                  ),
                                                ),
                                              ),
                                              if (layerProgress == 1.0)
                                                const Icon(Icons.check_circle,
                                                    color: Colors.green,
                                                    size: 18)
                                              else if (layerProgress > 0 &&
                                                  layerProgress < 1)
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              else if (layerProgress < 0)
                                                const Icon(Icons.error,
                                                    color: Colors.red, size: 18)
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      if (_getTotalPlanLayersCount(snapshot.data!) > 0) {
                        List<Map<String, String>> planLayers = snapshot.data!
                            .where((layer) => _isPlanLayer(layer['name']!))
                            .toList();

                        final planLayersProgress =
                            _calculatePlanLayersProgress(snapshot.data!);
                        final completedCount =
                            _getCompletedPlanLayersCount(snapshot.data!);

                        items.add(
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEBE0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      isPlanLayersExpanded =
                                          !isPlanLayersExpanded;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isPlanLayersExpanded
                                              ? Icons.expand_more
                                              : Icons.chevron_right,
                                          color: const Color(0xFF592941),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Plan Layers",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                              Text(
                                                "$completedCount of ${_getTotalPlanLayersCount(snapshot.data!)} completed",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (planLayersProgress == 1.0)
                                          const Icon(Icons.check_circle,
                                              color: Colors.green)
                                        else if (planLayersProgress > 0 &&
                                            planLayersProgress < 1)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else if (planLayers.any((layer) =>
                                            (vectorLayerProgress[
                                                    layer['name']] ??
                                                0.0) <
                                            0))
                                          Row(
                                            children: [
                                              const Icon(Icons.error,
                                                  color: Colors.red),
                                              const SizedBox(width: 8),
                                              TextButton.icon(
                                                onPressed: isRetrying
                                                    ? null
                                                    : retryPlanLayers,
                                                icon: const Icon(Icons.refresh,
                                                    size: 16),
                                                label: const Text('Retry'),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor:
                                                      const Color(0xFF592941),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                                if (isPlanLayersExpanded) ...[
                                  const SizedBox(height: 8),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    child: Divider(
                                      color: Color(0xFFD6D5C9),
                                      thickness: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 12, right: 12, bottom: 8),
                                    child: Column(
                                      children: planLayers.map((layer) {
                                        final layerName = layer['name']!;
                                        final layerProgress =
                                            vectorLayerProgress[layerName] ??
                                                0.0;

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.assignment,
                                                size: 16,
                                                color: Color(0xFF592941),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  layerName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF592941),
                                                  ),
                                                ),
                                              ),
                                              if (layerProgress == 1.0)
                                                const Icon(Icons.check_circle,
                                                    color: Colors.green,
                                                    size: 18)
                                              else if (layerProgress > 0 &&
                                                  layerProgress < 1)
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              else if (layerProgress < 0)
                                                const Icon(Icons.error,
                                                    color: Colors.red, size: 18)
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }
                      // * RASTER LAYERS SECTION
                      if (imageLayerProgress.isNotEmpty) {
                        int imageCompletedCount = imageLayerProgress.values
                            .where((progress) => progress == 1.0)
                            .length;

                        items.add(
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEBE0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      isImageLayersExpanded =
                                          !isImageLayersExpanded;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isImageLayersExpanded
                                              ? Icons.expand_more
                                              : Icons.chevron_right,
                                          color: const Color(0xFF592941),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Raster Layers (GeoTIFF)",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                              Text(
                                                "$imageCompletedCount of ${imageLayerProgress.length} completed",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (imageCompletedCount ==
                                                imageLayerProgress.length &&
                                            imageLayerProgress.isNotEmpty)
                                          const Icon(Icons.check_circle,
                                              color: Colors.green)
                                        else if (imageCompletedCount > 0)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else if (imageLayerProgress.values
                                            .any((progress) => progress < 0))
                                          Row(
                                            children: [
                                              const Icon(Icons.error,
                                                  color: Colors.red),
                                              const SizedBox(width: 8),
                                              TextButton.icon(
                                                onPressed: isRetrying
                                                    ? null
                                                    : retryImageLayers,
                                                icon: const Icon(Icons.refresh,
                                                    size: 16),
                                                label: const Text('Retry'),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor:
                                                      const Color(0xFF592941),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                                if (isImageLayersExpanded) ...[
                                  const SizedBox(height: 8),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    child: Divider(
                                      color: Color(0xFFD6D5C9),
                                      thickness: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 12, right: 12, bottom: 8),
                                    child: Column(
                                      children: imageLayerProgress.entries
                                          .map((entry) {
                                        final fileName = entry.key;
                                        final progress = entry.value;

                                        // Format display name
                                        String displayName = fileName;
                                        if (fileName.startsWith('clart_')) {
                                          displayName = 'CLART Layer';
                                        } else if (fileName
                                            .startsWith('lulc_')) {
                                          final year = fileName.split('_')[1];
                                          displayName = 'LULC 20$year';
                                        }

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.satellite_alt,
                                                size: 16,
                                                color: Color(0xFF592941),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  displayName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF592941),
                                                  ),
                                                ),
                                              ),
                                              if (progress == 1.0)
                                                const Icon(Icons.check_circle,
                                                    color: Colors.green,
                                                    size: 18)
                                              else if (progress > 0 &&
                                                  progress < 1)
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              else if (progress < 0)
                                                const Icon(Icons.error,
                                                    color: Colors.red, size: 18)
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      // * S3 JSON FILES SECTION
                      if (s3JsonProgress.isNotEmpty) {
                        int s3CompletedCount = s3JsonProgress.values
                            .where((progress) => progress == 1.0)
                            .length;

                        items.add(
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEBE0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      isFormDataExpanded = !isFormDataExpanded;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isFormDataExpanded
                                              ? Icons.expand_more
                                              : Icons.chevron_right,
                                          color: const Color(0xFF592941),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Form Data Files",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                              Text(
                                                "$s3CompletedCount of ${s3JsonProgress.length} completed",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (s3CompletedCount ==
                                                s3JsonProgress.length &&
                                            s3JsonProgress.isNotEmpty)
                                          const Icon(Icons.check_circle,
                                              color: Colors.green)
                                        else if (s3CompletedCount > 0)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else if (s3JsonProgress.values
                                            .any((progress) => progress < 0))
                                          Row(
                                            children: [
                                              const Icon(Icons.error,
                                                  color: Colors.red),
                                              const SizedBox(width: 8),
                                              TextButton.icon(
                                                onPressed: isRetrying
                                                    ? null
                                                    : retryFormData,
                                                icon: const Icon(Icons.refresh,
                                                    size: 16),
                                                label: const Text('Retry'),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor:
                                                      const Color(0xFF592941),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                                if (isFormDataExpanded) ...[
                                  const SizedBox(height: 8),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    child: Divider(
                                      color: Color(0xFFD6D5C9),
                                      thickness: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 12, right: 12, bottom: 8),
                                    child: Column(
                                      children:
                                          s3JsonProgress.entries.map((entry) {
                                        final fileName = entry.key;
                                        final progress = entry.value;

                                        // Format display name nicely
                                        String displayName = fileName
                                            .replaceAll('add_', '')
                                            .replaceAll('.json', '')
                                            .replaceAll('_', ' ');
                                        displayName = displayName
                                            .split(' ')
                                            .map((word) => word.isEmpty
                                                ? ''
                                                : word[0].toUpperCase() +
                                                    word.substring(1))
                                            .join(' ');

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.description,
                                                size: 16,
                                                color: Color(0xFF592941),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  displayName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF592941),
                                                  ),
                                                ),
                                              ),
                                              if (progress == 1.0)
                                                const Icon(Icons.check_circle,
                                                    color: Colors.green,
                                                    size: 18)
                                              else if (progress > 0 &&
                                                  progress < 1)
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              else if (progress < 0)
                                                const Icon(Icons.error,
                                                    color: Colors.red, size: 18)
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      //* WEBAPP FILES SECTION
                      if (webappProgress.isNotEmpty) {
                        int webappCompletedCount = webappProgress.values
                            .where((progress) => progress == 1.0)
                            .length;

                        items.add(
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEBE0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      isWebAppExpanded = !isWebAppExpanded;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isWebAppExpanded
                                              ? Icons.expand_more
                                              : Icons.chevron_right,
                                          color: const Color(0xFF592941),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Web App Files",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                              Text(
                                                "$webappCompletedCount of ${webappProgress.length} completed",
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF592941),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (webappCompletedCount ==
                                                webappProgress.length &&
                                            webappProgress.isNotEmpty)
                                          const Icon(Icons.check_circle,
                                              color: Colors.green)
                                        else if (webappCompletedCount > 0)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else if (webappProgress.values
                                            .any((progress) => progress < 0))
                                          Row(
                                            children: [
                                              const Icon(Icons.error,
                                                  color: Colors.red),
                                              const SizedBox(width: 8),
                                              TextButton.icon(
                                                onPressed: isRetrying
                                                    ? null
                                                    : retryWebApp,
                                                icon: const Icon(Icons.refresh,
                                                    size: 16),
                                                label: const Text('Retry'),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor:
                                                      const Color(0xFF592941),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                                if (isWebAppExpanded) ...[
                                  const SizedBox(height: 8),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    child: Divider(
                                      color: Color(0xFFD6D5C9),
                                      thickness: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 12, right: 12, bottom: 8),
                                    child: Column(
                                      children:
                                          webappProgress.entries.map((entry) {
                                        final fileName = entry.key;
                                        final progress = entry.value;

                                        // Format display name
                                        String displayName =
                                            fileName.split('/').last;
                                        if (displayName.length > 30) {
                                          displayName =
                                              displayName.substring(0, 27) +
                                                  '...';
                                        }

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 8),
                                              Icon(
                                                fileName.endsWith('.html')
                                                    ? Icons.html
                                                    : fileName.endsWith('.js')
                                                        ? Icons.javascript
                                                        : fileName.endsWith(
                                                                '.css')
                                                            ? Icons.style
                                                            : fileName.endsWith(
                                                                    '.svg')
                                                                ? Icons.image
                                                                : Icons
                                                                    .insert_drive_file,
                                                size: 16,
                                                color: const Color(0xFF592941),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  displayName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF592941),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (progress == 1.0)
                                                const Icon(Icons.check_circle,
                                                    color: Colors.green,
                                                    size: 18)
                                              else if (progress > 0 &&
                                                  progress < 1)
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              else if (progress < 0)
                                                const Icon(Icons.error,
                                                    color: Colors.red, size: 18)
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(children: items);
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              isDownloading ? "---" : "Download Complete",
              style: const TextStyle(
                color: Color(0xFF592941),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
