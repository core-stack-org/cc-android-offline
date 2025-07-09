import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nrmflutter/container_flow/container_manager.dart';
import 'package:nrmflutter/container_flow/container_sheet.dart';
import 'package:nrmflutter/utils/constants.dart';
import 'package:nrmflutter/utils/download_base_map.dart';
import 'package:nrmflutter/utils/layers_config.dart';
import 'package:nrmflutter/utils/offline_asset.dart';
import 'package:path_provider/path_provider.dart';

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
  Map<String, bool> layerCancelled = {};
  late BaseMapDownloader baseMapDownloader;
  Future<List<Map<String, String>>>? _cachedLayers;
  bool _isLoadingLayers = false;

  @override
  void initState() {
    super.initState();
    baseMapDownloader = BaseMapDownloader(
      onProgressUpdate: (progress) {
        if (mounted) {
          setState(() {
            baseMapProgress = progress;
          });
        }
      },
    );
    downloadAllLayers(widget.container);
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
      }
    }

    print("Copying assets to persistent storage");
    await OfflineAssetsManager.copyOfflineAssets(forceUpdate: true);
    print("Finished downloadVectorLayers");
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
      });
    }

    try {
      double radiusKm = 3.0;
      await baseMapDownloader.downloadBaseMap(
          container.latitude, container.longitude, radiusKm, container.name);
      await downloadVectorLayers(container);

      final directory = await getApplicationDocumentsDirectory();
      final containerDir = Directory(
          '${directory.path}/persistent_offline_data/containers/${container.name}');
      final vectorLayersDir = Directory('${containerDir.path}/vector_layers');
      final baseMapTilesDir = Directory('${containerDir.path}/base_map_tiles');

      if (await vectorLayersDir.exists() && await baseMapTilesDir.exists()) {
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
      } else {
        throw Exception(
            "Offline data verification failed - missing directories.");
      }
    } catch (e) {
      print("Error during layer download: $e");

      await ContainerManager.updateContainerDownloadStatus(
          container.name, false);

      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloadComplete = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
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
        leading: (isDownloading && !isDownloadComplete)
            ? Center(
                child: TextButton(
                  onPressed: _cancelAllDownloads,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.red, width: 1.5),
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
              onPressed: isDownloadComplete
                  ? () {
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
                    }
                  : null,
              style: TextButton.styleFrom(
                foregroundColor:
                    isDownloadComplete ? Colors.white : Colors.grey.shade700,
                backgroundColor:
                    isDownloadComplete ? Colors.blue : Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text('Done'),
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
                      int completedLayers = 0;
                      int totalLayers = 0;

                      if (baseMapProgress >= 0) {
                        totalProgress += baseMapProgress;
                      }
                      if (baseMapProgress == 1.0) completedLayers++;
                      totalLayers++;

                      List<Map<String, String>> nonPlanLayers = snapshot.data!
                          .where((layer) => !_isPlanLayer(layer['name']!))
                          .toList();

                      for (var layer in nonPlanLayers) {
                        double layerProgress =
                            vectorLayerProgress[layer['name']] ?? 0.0;
                        if (layerProgress >= 0) {
                          totalProgress += layerProgress;
                          if (layerProgress == 1.0) completedLayers++;
                        }
                        totalLayers++;
                      }

                      if (_getTotalPlanLayersCount(snapshot.data!) > 0) {
                        double planLayersProgress =
                            _calculatePlanLayersProgress(snapshot.data!);
                        totalProgress += planLayersProgress;
                        if (planLayersProgress == 1.0) completedLayers++;
                        totalLayers++;
                      }

                      double overallProgress =
                          totalLayers > 0 ? totalProgress / totalLayers : 0.0;

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
              border: Border.all(color: const Color(0xFFD6D5C9), width: 5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Layer Status",
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF592941),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Base Map",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF592941),
                        ),
                      ),
                    ),
                    if (baseMapProgress == 1.0)
                      const Icon(Icons.check_circle, color: Colors.green)
                    else if (baseMapProgress > 0 && baseMapProgress < 1)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    else if (baseMapProgress < 0)
                      const Icon(Icons.error, color: Colors.red)
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, String>>>(
                  future:
                      getLayers(widget.selectedDistrict, widget.selectedBlock),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      List<Map<String, String>> nonPlanLayers = snapshot.data!
                          .where((layer) => !_isPlanLayer(layer['name']!))
                          .toList();

                      List<Widget> items = [];

                      for (var layer in nonPlanLayers) {
                        double layerProgress =
                            vectorLayerProgress[layer['name']] ?? 0.0;
                        items.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    layer['name']!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF592941),
                                    ),
                                  ),
                                ),
                                if (layerProgress == 1.0)
                                  const Icon(Icons.check_circle,
                                      color: Colors.green)
                                else if (layerProgress > 0 && layerProgress < 1)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else if (layerProgress < 0)
                                  const Icon(Icons.error, color: Colors.red)
                              ],
                            ),
                          ),
                        );
                      }

                      if (_getTotalPlanLayersCount(snapshot.data!) > 0) {
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
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
