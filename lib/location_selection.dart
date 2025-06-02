import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ui' as ui;

import 'webview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:nrmflutter/db/plans_db.dart';
import 'package:nrmflutter/db/location_db.dart';
import 'package:nrmflutter/utils/layers_config.dart';
import 'package:nrmflutter/utils/constants.dart';
import 'package:nrmflutter/utils/change_log.dart';

import './server/local_server.dart';
import './utils/offline_asset.dart';
import './utils/use_info.dart';
import './utils/download_base_map.dart';
import './container_flow/container_manager.dart';
import './container_flow/container_sheet.dart';

class LocationSelection extends StatefulWidget {
  const LocationSelection({super.key});

  @override
  _LocationSelectionState createState() => _LocationSelectionState();
}

class _LocationSelectionState extends State<LocationSelection> {
  String? selectedState;
  String? selectedDistrict;
  String? selectedBlock;
  String? selectedStateID;
  String? selectedDistrictID;
  String? selectedBlockID;
  StateSetter? _sheetSetState; 
  bool isDownloading = false;
  bool isDownloadComplete = false;
  double baseMapProgress = 0.0;
  Map<String, double> vectorLayerProgress = {};
  Map<String, bool> layerCancelled = {};
  bool isAgreed = false;
  bool cancelBaseMapDownload = false;
  LocalServer? _localServer;
  late BaseMapDownloader baseMapDownloader;
  Future<List<Map<String, String>>>? _cachedLayers;
  bool _isLoadingLayers = false;
  List<bool> _isSelected = [true, false]; 
  bool _isSubmitEnabled = false; 
  String _appVersion = '2.0.7'; 
  String _deviceInfo = 'Unknown'; 
  String _modeSelectionMessage = "You have selected ONLINE mode"; 

  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> districts = [];
  List<Map<String, dynamic>> blocks = [];

  @override
  void initState() {
    super.initState();
    _loadInfo(); 
    fetchLocationData();
    baseMapDownloader = BaseMapDownloader(
      onProgressUpdate: (progress) {
        setState(() {
          baseMapProgress = progress;
        });
        _sheetSetState?.call(() {}); 
      },
    );
  }

  List<Map<String, dynamic>> sortLocationData(List<Map<String, dynamic>> data) {
    data.sort((a, b) => (a['label'] as String).compareTo(b['label'] as String));

    for (var state in data) {
      List<Map<String, dynamic>> districts =
          List<Map<String, dynamic>>.from(state['district']);
      districts.sort(
          (a, b) => (a['label'] as String).compareTo(b['label'] as String));

      for (var district in districts) {
        List<Map<String, dynamic>> blocks =
            List<Map<String, dynamic>>.from(district['blocks']);
        blocks.sort(
            (a, b) => (a['label'] as String).compareTo(b['label'] as String));
        district['blocks'] = blocks;
      }

      state['district'] = districts;
    }

    return data;
  }

  Future<void> fetchLocationData() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        final response =
            await http.get(Uri.parse('${apiUrl}proposed_blocks/'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          await LocationDatabase.instance
              .insertLocationData(List<Map<String, dynamic>>.from(data));

          await PlansDatabase.instance.syncPlans();

          setState(() {
            states = sortLocationData(List<Map<String, dynamic>>.from(data));
          });
        }
      } else {
        final data = await LocationDatabase.instance.getLocationData();
        setState(() {
          states = sortLocationData(data);
        });
      }
    } catch (e) {
      print('Error fetching location data: $e');
      try {
        final data = await LocationDatabase.instance.getLocationData();
        setState(() {
          states = sortLocationData(data);
        });
      } catch (dbError) {
        print('Error fetching from local database: $dbError');
      }
    }
  }

  void updateDistricts(String state) {
    final selectedStateData = states.firstWhere((s) => s["label"] == state);
    setState(() {
      selectedState = state;
      selectedStateID = selectedStateData["state_id"];
      selectedDistrict = null;
      selectedDistrictID = null;
      selectedBlock = null;
      selectedBlockID = null;
      districts =
          List<Map<String, dynamic>>.from(selectedStateData["district"]);
      _isSubmitEnabled = selectedState != null && selectedDistrict != null && selectedBlock != null; 
    });
  }

  void updateBlocks(String district) {
    final selectedDistrictData =
        districts.firstWhere((d) => d["label"] == district);
    setState(() {
      selectedDistrict = district;
      selectedDistrictID = selectedDistrictData["district_id"];
      selectedBlock = null;
      selectedBlockID = null;
      blocks = List<Map<String, dynamic>>.from(selectedDistrictData["blocks"]);
      _isSubmitEnabled = selectedState != null && selectedDistrict != null && selectedBlock != null; 
    });
  }

  void updateSelectedBlock(String block) {
    final selectedBlockData = blocks.firstWhere((b) => b["label"] == block);
    setState(() {
      selectedBlock = block;
      selectedBlockID = selectedBlockData["block_id"].toString();
      _cachedLayers = null;
      _isLoadingLayers = false;
      _isSubmitEnabled = selectedState != null && selectedDistrict != null && selectedBlock != null; 
    });
  }

  void submitLocation() {
    HapticFeedback.mediumImpact();
    String url =
        "${ccUrl}?geoserver_url=${geoserverUrl.substring(0, geoserverUrl.length - 1)}&app_name=nrmApp&state_name=$selectedState&dist_name=$selectedDistrict&block_name=$selectedBlock&block_id=$selectedBlockID&isOffline=false";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewApp(url: url),
      ),
    );
  }

  Future<List<Map<String, String>>> getLayers(
      String? district, String? block) async {
    if (_cachedLayers == null && !_isLoadingLayers) {
      _isLoadingLayers = true;
      print(
          "LocationSelection.getLayers called with district: $district, block: $block, blockId: $selectedBlockID");
      _cachedLayers =
          LayersConfig.getLayers(district, block, blockId: selectedBlockID);
      await _cachedLayers; 
      _isLoadingLayers = false;
    }
    return _cachedLayers!;
  }

  Future<void> downloadVectorLayers(OfflineContainer container) async {
    print("Starting downloadVectorLayers");
    print("Selected block ID: $selectedBlockID");

    final layers = await getLayers(selectedDistrict, selectedBlock);
    print("Retrieved ${layers.length} layers to download");

    for (var layer in layers) {
      print(
          "Processing layer: ${layer['name']} with path: ${layer['geoserverPath']}");
      if (layerCancelled[layer['name']] == true) {
        print("Layer ${layer['name']} is cancelled, skipping");
        continue;
      }

      setState(() {
        vectorLayerProgress[layer['name']!] = 0.0;
      });

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
        setState(() {
          vectorLayerProgress[layerName] = -1.0;
        });
        _sheetSetState?.call(() {});
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
              setState(() {
                vectorLayerProgress[layerName] = progress;
              });
              _sheetSetState?.call(() {});
            }
          }
        }

        await sink.close();
        print("Successfully saved layer $layerName");

        setState(() {
          vectorLayerProgress[layerName] = 1.0;
        });
        _sheetSetState?.call(() {});
      } else {
        print(
            "Failed to download $layerName. Status code: ${request.statusCode}");
        throw Exception(
            'Failed to download $layerName. Status code: ${request.statusCode}');
      }
    } catch (e) {
      print('Error downloading $layerName: $e');
      setState(() {
        vectorLayerProgress[layerName] = -1.0;
      });
      _sheetSetState?.call(() {});
      rethrow;
    }
  }

  Future<void> downloadAllLayers(OfflineContainer container) async {
    print("Starting to download the layers for container: ${container.name}");
    setState(() {
      isDownloading = true;
      baseMapProgress = 0.0;
      vectorLayerProgress.clear();
      layerCancelled.clear();
      isDownloadComplete = false;
    });

    try {
      double centerLat = 24.1542;
      double centerLon = 87.1204;
      print("-----------------------------cha cha-------------------------");
      print("Latitude: ${container.latitude}");
      print("Longitude: ${container.longitude}");

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

        setState(() {
          isDownloading = false;
          isDownloadComplete = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Successfully downloaded data for container: ${container.name}'),
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

      setState(() {
        isDownloading = false;
        isDownloadComplete = false;
      });

      if (mounted) {
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

  Future<void> copyLayersToOfflineDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final sourceDir = Directory('${directory.path}/assets/offline_data');
    final persistentOfflinePath =
        path.join(directory.path, 'persistent_offline_data');
    final destDir = Directory(persistentOfflinePath);

    await destDir.create(recursive: true);

    await for (var entity in sourceDir.list(recursive: true)) {
      final relativePath = path.relative(entity.path, from: sourceDir.path);
      final newPath = path.join(destDir.path, relativePath);

      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
        print('Created directory: $newPath');
      }
    }

    print("Layers copied to persistent offline directory: ${destDir.path}");
  }

  void cancelLayerDownload(String layerName) {
    setState(() {
      if (layerName == 'Base Map') {
        baseMapDownloader.cancelBaseMapDownload = true;
      } else {
        layerCancelled[layerName] = true;
      }
    });
  }

  void showAgreementSheet(OfflineContainer container) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Access Application without Internet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF592941),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "To download the layers for offline connectivity, please tick off agree and press on download button. The layers will take around 300 MB of your phone storage.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF592941),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: isAgreed,
                        onChanged: (bool? value) {
                          setSheetState(() {
                            isAgreed = value!;
                          });
                        },
                      ),
                      const Text(
                        "Agree and Download Layers",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF592941),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: isAgreed
                          ? () {
                              Navigator.pop(context);
                              showDownloadProgressSheet(container);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD6D5C9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                      ),
                      child: const Text(
                        "Download Layers",
                        style: TextStyle(
                          color: Color(0xFF592941),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void showContainerList() {
    ContainerSheets.showContainerList(
      context: context,
      selectedState: selectedState ?? '',
      selectedDistrict: selectedDistrict ?? '',
      selectedBlock: selectedBlock ?? '',
      onContainerSelected: (container) {
        navigateToWebViewOffline(container); 
      },
    );
  }

  Future<void> navigateToWebViewOffline(OfflineContainer container) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final persistentOfflinePath =
          path.join(directory.path, 'persistent_offline_data');

      _localServer = LocalServer(persistentOfflinePath, container.name);
      final serverUrl = await _localServer!.start();

      final plansResponse = await http.get(
        Uri.parse('$serverUrl/api/v1/get_plans/?block_id=$selectedBlockID'),
      );

      if (plansResponse.statusCode != 200) {
        throw Exception('Failed to fetch plans: ${plansResponse.statusCode}');
      }

      final encodedPlans = Uri.encodeComponent(plansResponse.body);

      String url = "$serverUrl/maps?" +
          "geoserver_url=$serverUrl" +
          "&state_name=${container.state}" +
          "&dist_name=${container.district}" +
          "&block_name=${container.block}" +
          "&block_id=$selectedBlockID" +
          "&isOffline=true" +
          "&container_name=${container.name}" +
          "&plans=$encodedPlans";

      print('Offline URL: $url');

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewApp(url: url),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to offline web view: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading offline view: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showDownloadProgressSheet(OfflineContainer container) {
    baseMapDownloader = BaseMapDownloader(
      onProgressUpdate: (progress) {
        setState(() {
          baseMapProgress = progress;
        });
        _sheetSetState?.call(() {}); 
      },
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            _sheetSetState = setSheetState; 
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.3,
              maxChildSize: 0.80,
              expand: false,
              builder: (_, controller) {
                return Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              controller: controller,
                              children: [
                                const Text(
                                  "Downloading Layers",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF592941),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Please do not close this sheet while download is in progress.",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF592941),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFD6D5C9),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    container.name,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        future: getLayers(
                                            selectedDistrict, selectedBlock),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            double totalProgress = 0;
                                            int completedLayers = 0;
                                            int totalLayers = 0;
                                            
                                            totalProgress += baseMapProgress;
                                            if (baseMapProgress == 1.0) 
                                              completedLayers++;
                                            totalLayers++;  
                                            
                                            List<Map<String, String>> nonPlanLayers = 
                                                snapshot.data!.where((layer) => !_isPlanLayer(layer['name']!)).toList();
                                            
                                            for (var layer in nonPlanLayers) {
                                              double layerProgress = vectorLayerProgress[layer['name']] ?? 0.0;
                                              if (layerProgress == 1.0)
                                                completedLayers++;
                                              totalProgress += layerProgress;
                                              totalLayers++;
                                            }
                                            
                                            if (_getTotalPlanLayersCount(snapshot.data!) > 0) {
                                              double planLayersProgress = _calculatePlanLayersProgress(snapshot.data!);
                                              totalProgress += planLayersProgress;
                                              if (planLayersProgress == 1.0)
                                                completedLayers++;
                                              totalLayers++; 
                                            }
                                            
                                            double overallProgress = totalLayers > 0 
                                                ? totalProgress / totalLayers 
                                                : 0.0;

                                            return Column(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child:
                                                      LinearProgressIndicator(
                                                    value: overallProgress,
                                                    backgroundColor: Colors
                                                        .white
                                                        .withAlpha(77),
                                                    valueColor:
                                                        const AlwaysStoppedAnimation<
                                                                Color>(
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
                                    border: Border.all(
                                        color: const Color(0xFFD6D5C9),
                                        width: 5),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          Expanded(
                                            child: Text(
                                              "Base Map",
                                              style: const TextStyle(
                                                fontSize: 16,
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
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      FutureBuilder<List<Map<String, String>>>(
                                        future: getLayers(
                                            selectedDistrict, selectedBlock),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            List<Map<String, String>> nonPlanLayers = 
                                                snapshot.data!.where((layer) => !_isPlanLayer(layer['name']!)).toList();
                                            
                                            List<Widget> items = [];
                                            
                                            for (var layer in nonPlanLayers) {
                                              double layerProgress = vectorLayerProgress[layer['name']] ?? 0.0;
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
                                                        const Icon(Icons.check_circle, color: Colors.green)
                                                      else if (layerProgress > 0 && layerProgress < 1)
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
                                            
                                            if (_getTotalPlanLayersCount(snapshot.data!) > 0) {
                                              final planLayersProgress = _calculatePlanLayersProgress(snapshot.data!);
                                              final completedCount = _getCompletedPlanLayersCount(snapshot.data!);
                                              
                                              items.add(
                                                Container(
                                                  margin: const EdgeInsets.only(bottom: 10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFECEBE0),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, 
                                                    vertical: 8
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                                        const Icon(Icons.check_circle, color: Colors.green)
                                                      else if (planLayersProgress > 0 && planLayersProgress < 1)
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
                          ),
                          if (isDownloadComplete) ...[
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
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
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD6D5C9),
                                foregroundColor: const Color(0xFF592941),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                  horizontal: 40,
                                ),
                              ),
                              child: const Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    downloadAllLayers(container);
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
    return allLayers
        .where((layer) => _isPlanLayer(layer['name']!))
        .length;
  }

  Widget _buildLayerProgressItem(
      String layerName, double progress, VoidCallback onCancel) {
    Color progressColor = Colors.blue;
    if (progress == 1.0) {
      progressColor = Colors.green;
    } else if (progress == -1.0) {
      progressColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                layerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF592941),
                ),
              ),
            ),
            if (progress > 0 && progress < 1)
              ElevatedButton(
                onPressed: onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Cancel'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 10,
            child: LinearProgressIndicator(
              value: progress >= 0 ? progress : 0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFFD6D5C9), width: 3.0),
        boxShadow: value != null ? [
          BoxShadow(
            color: const Color(0xFF592941).withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ] : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.white,
          popupMenuTheme: PopupMenuThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(
              hint,
              style: const TextStyle(color: Color.fromARGB(255, 163, 163, 163)),
            ),
            onChanged: (String? newValue) {
              HapticFeedback.selectionClick();
              HapticFeedback.mediumImpact();
              
              onChanged(newValue);
            },
            menuMaxHeight: 300,
            icon: AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              turns: value != null ? 0.5 : 0,
              child: const Icon(Icons.arrow_drop_down, color: Color(0xFF592941)),
            ),
            items: items.map((Map<String, dynamic> map) {
              return DropdownMenuItem<String>(
                value: map["label"],
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween<double>(begin: 0.8, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Text(
                    map["label"],
                    style: const TextStyle(color: Color(0xFF592941)),
                  ),
                ),
              );
            }).toList(),
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {
    HapticFeedback.mediumImpact();
    bool isOnlineMode = _isSelected[0]; 

    if (selectedState == null || selectedDistrict == null || selectedBlock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select State, District, and Block.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (isOnlineMode) {
      submitLocation();
    } else { 
      ContainerSheets.showContainerList(
        context: context,
        selectedState: selectedState!,
        selectedDistrict: selectedDistrict!,
        selectedBlock: selectedBlock!,
        onContainerSelected: (container) {
          if (container.isDownloaded) {
            navigateToWebViewOffline(container);
          } else {
            showAgreementSheet(container);
          }
        },
      );
    }
  }

  Future<void> _loadInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;

      if (Platform.isAndroid) {
        final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
        final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        _deviceInfo = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt}), Model: ${androidInfo.model}, Manufacturer: ${androidInfo.manufacturer}';
      } else if (Platform.isIOS) {
        _deviceInfo = 'iOS Device (Details TBD)';
      }
    } catch (e) {
      print('Failed to load info: $e');
      _appVersion = 'Error';
      _deviceInfo = 'Error loading details';
    }
    if (mounted) {
      setState(() {}); 
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@core-stack.org',
      queryParameters: {
        'subject': 'Bug Report - App v$_appVersion',
        'body': '''
        Please describe the bug in detail below:
        ------------------------------------------
        [Your bug description here]
        ------------------------------------------

        Device Information (auto-filled):
        App Version: $_appVersion
        Device Details: $_deviceInfo
        State: ${selectedState ?? 'Not selected'}
        District: ${selectedDistrict ?? 'Not selected'}
        Block: ${selectedBlock ?? 'Not selected'}
        Mode: ${_isSelected[0] ? 'Online' : 'Offline'}
        '''.trim().replaceAll('        ', ''), 
      },
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open email client. Please send your report to support@core-stack.org'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      print('Could not launch $emailLaunchUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color customGrey = Color(0xFFD6D4C8);
    const Color darkTextColor = Colors.black87;

    return Scaffold(
      backgroundColor:
          const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 1.0),
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: const Text('Select a location'),
        leading: IconButton(
          icon: const Icon(Icons.history),
          onPressed: () => ChangeLog.showChangelogBottomSheet(context),
          tooltip: "What's New",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => UseInfo.showInstructionsSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Opacity(
              opacity: 0.7,
              child: Image.asset(
                'assets/farm.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.5,
                widthFactor: 1.0, 
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.transparent, 
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32.0),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select State, District and Tehsil from the dropdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF592941),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    _buildDropdown(
                      value: selectedState,
                      hint: 'Select a State',
                      items: states,
                      onChanged: (String? value) {
                        setState(() {
                          selectedState = value;
                          updateDistricts(value!);
                        });
                      },
                    ),
                    const SizedBox(height: 16.0),
                    _buildDropdown(
                      value: selectedDistrict,
                      hint: 'Select a District',
                      items: districts,
                      onChanged: (String? value) {
                        setState(() {
                          selectedDistrict = value;
                          updateBlocks(value!);
                        });
                      },
                    ),
                    const SizedBox(height: 16.0),
                    _buildDropdown(
                      value: selectedBlock,
                      hint: 'Select a Tehsil',
                      items: blocks,
                      onChanged: (String? value) {
                        if (value != null) {
                          updateSelectedBlock(value);
                        }
                      },
                    ),
                    const SizedBox(height: 35.0), 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: const Divider(
                        height: 1,
                        thickness: 1.5,
                        color: Color.fromARGB(255, 211, 211, 211),
                      ),
                    ),
                    const SizedBox(height: 15.0), 
                    Text(
                      _modeSelectionMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF592941)
                      ),
                    ),
                    const SizedBox(height: 15.0), 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _isSelected[0]
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: customGrey, 
                                  foregroundColor: Color(0xFF592941),
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: TextStyle(fontSize: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0), 
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    HapticFeedback.lightImpact();
                                    _isSelected = [true, false];
                                    _modeSelectionMessage = "You have selected ONLINE mode";
                                  });
                                },
                                child: const Text('Online mode'),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: customGrey, 
                                  side: BorderSide(color: customGrey, width: 1.5), 
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: TextStyle(fontSize: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0), 
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    HapticFeedback.lightImpact();
                                    _isSelected = [true, false];
                                    _modeSelectionMessage = "You have selected ONLINE mode";
                                  });
                                },
                                child: const Text('Online mode'),
                              ),

                        SizedBox(width: 16), 

                        _isSelected[1]
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: customGrey, 
                                  foregroundColor: Color(0xFF592941), 
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: TextStyle(fontSize: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0), 
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    HapticFeedback.lightImpact();
                                    _isSelected = [false, true];
                                    _modeSelectionMessage = "You have selected OFFLINE mode";
                                  });
                                },
                                child: const Text('Offline mode*'),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: customGrey, 
                                  side: BorderSide(color: customGrey, width: 1.5), 
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  textStyle: TextStyle(fontSize: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0), 
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    HapticFeedback.lightImpact();
                                    _isSelected = [false, true];
                                    _modeSelectionMessage = "You have selected OFFLINE mode";
                                  });
                                },
                                child: const Text('Offline mode*'),
                              ),
                      ],
                    ),

                    SizedBox(height: 20), 

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSubmitEnabled 
                              ? customGrey 
                              : Colors.grey.shade400, 
                          foregroundColor: _isSubmitEnabled 
                              ? const Color(0xFF592941) 
                              : Colors.white, 
                          minimumSize: const Size(200.0, 24),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0), 
                          ),
                        ),
                        onPressed: _isSubmitEnabled ? _handleSubmit : null,
                        child: const Text('SUBMIT'),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        "*BETA Offline mode works in remote areas without internet with limited features.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Color.fromARGB(255, 77, 77, 77),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32.0),
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'version: $_appVersion',
                        style: TextStyle(
                          color: Color(0xFF592941),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0, top: 4.0), 
                      child: InkWell(
                        onTap: _launchEmail, 
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          mainAxisSize: MainAxisSize.min, 
                          children: <Widget>[
                            Icon(
                              Icons.bug_report,
                              color: Color(0xFF592941),
                              size: 16, 
                            ),
                            const SizedBox(width: 8), 
                            Text(
                              'File a bug report',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF592941), 
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
