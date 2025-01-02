import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'webview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:nrmflutter/db/plans_db.dart';
import 'package:nrmflutter/db/location_db.dart';
import 'package:nrmflutter/utils/layers_config.dart';

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
  StateSetter? _sheetSetState; // Add this as a class field
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

  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> districts = [];
  List<Map<String, dynamic>> blocks = [];

  @override
  void initState() {
    super.initState();
    fetchLocationData();
    baseMapDownloader = BaseMapDownloader(
      onProgressUpdate: (progress) {
        setState(() {
          baseMapProgress = progress;
        });
        _sheetSetState?.call(() {}); // Update the sheet's state
      },
    );
  }

  List<Map<String, dynamic>> sortLocationData(List<Map<String, dynamic>> data) {
    // Sort states
    data.sort((a, b) => (a['label'] as String).compareTo(b['label'] as String));

    // Sort districts within each state
    for (var state in data) {
      List<Map<String, dynamic>> districts =
          List<Map<String, dynamic>>.from(state['district']);
      districts.sort(
          (a, b) => (a['label'] as String).compareTo(b['label'] as String));

      // Sort blocks within each district
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

  // MARK: Fetch and sync data
  Future<void> fetchLocationData() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        // Online mode
        final response = await http.get(Uri.parse(
            'https://geoserver.gramvaani.org/api/v1/proposed_blocks/'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Save to local database
          await LocationDatabase.instance
              .insertLocationData(List<Map<String, dynamic>>.from(data));

          // Sync the plan data
          await PlansDatabase.instance.syncPlans();

          setState(() {
            states = sortLocationData(List<Map<String, dynamic>>.from(data));
          });
        }
      } else {
        // Offline mode - fetch from local database
        final data = await LocationDatabase.instance.getLocationData();
        setState(() {
          states = sortLocationData(data);
        });
      }
    } catch (e) {
      print('Error fetching location data: $e');
      // Try to fetch from local database as fallback
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
      print("You have selected state: ${selectedState}");
      selectedStateID = selectedStateData["state_id"];
      selectedDistrict = null;
      selectedDistrictID = null;
      selectedBlock = null;
      selectedBlockID = null;
      districts =
          List<Map<String, dynamic>>.from(selectedStateData["district"]);
      // districts = List<Map<String, dynamic>>.from(
      //     states.firstWhere((s) => s["label"] == state)["district"]);
      print("UU ${districts}");
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
    });
  }

  void updateSelectedBlock(String block) {
    print("Updating selected block: $block");
    final selectedBlockData = blocks.firstWhere((b) => b["label"] == block);
    print("Found block data: $selectedBlockData");

    setState(() {
      selectedBlock = block;
      selectedBlockID = selectedBlockData["block_id"].toString();
      // Clear cached layers when block changes
      _cachedLayers = null;
      _isLoadingLayers = false;
    });
    print("Updated selectedBlockID to: $selectedBlockID");
  }

  // MARK: Navigate Online
  void submitLocation() {
    HapticFeedback.mediumImpact();
    String url =
        "https://nrm.gramvaanidev.org/maps?geoserver_url=https://geoserver.gramvaani.org:8443&app_name=commonsconnect&state_name=$selectedState&dist_name=$selectedDistrict&block_name=$selectedBlock&block_id=$selectedBlockID&iOffline=false";

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
      _cachedLayers = LayersConfig.getLayers(district, block,
          blockId: selectedBlockID);
      await _cachedLayers; // Wait for the future to complete
      _isLoadingLayers = false;
    }
    return _cachedLayers!;
  }

  Future<void> downloadVectorLayers() async {
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
        await downloadVectorLayer(layer['name']!, layer['geoserverPath']!);
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

  Future<void> downloadVectorLayer(String layerName, String geoserverPath) async {
    try {
      print("Starting download of vector layer: $layerName");
      if (layerCancelled[layerName] == true) {
        setState(() {
          vectorLayerProgress[layerName] = -1.0;
        });
        _sheetSetState?.call(() {});
        return;
      }

      final url = 'https://geoserver.gramvaani.org:8443/geoserver/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=$geoserverPath&outputFormat=application/json';
      print("Downloading from URL: $url");

      final request = await http.Client().send(http.Request('GET', Uri.parse(url)));
      
      if (request.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final formattedLayerName = formatLayerName(layerName);
        final filePath = '${directory.path}/assets/offline_data/vector_layers/$formattedLayerName.geojson';
        print("Saving layer to: $filePath");

        final file = File(filePath);
        await file.create(recursive: true);
        
        final totalBytes = request.contentLength ?? 0;
        var bytesWritten = 0;
        
        final sink = file.openWrite();
        
        // Use stream to handle the download
        await for (final chunk in request.stream) {
          sink.add(chunk);
          bytesWritten += chunk.length;
          
          if (totalBytes > 0) {
            final progress = bytesWritten / totalBytes;
            // Update UI less frequently (every 5% progress)
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
        print("Failed to download $layerName. Status code: ${request.statusCode}");
        throw Exception('Failed to download $layerName. Status code: ${request.statusCode}');
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
      // Download base maps and vector layers...

      // double centerLat = 24.1542;
      // double centerLon = 87.1204;
      print("-----------------------------cha cha-------------------------");
      print("Latitude: ${container.latitude}");
      print("Longitude: ${container.longitude}");

      double radiusKm = 3.0; // 3 km radius
      await baseMapDownloader.downloadBaseMap(
          container.latitude, container.longitude, radiusKm);
      await downloadVectorLayers();

      // Verify all required files exist
      if (await OfflineAssetsManager.verifyOfflineData()) {
        print("Offline data verified successfully");

        // Update container status
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
        throw Exception("Offline data verification failed");
      }
    } catch (e) {
      print("Error during layer download: $e");

      // Update container status to indicate failure
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

  // MARK: Copy layers to offline directory
  Future<void> copyLayersToOfflineDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final sourceDir = Directory('${directory.path}/assets/offline_data');
    final persistentOfflinePath =
        path.join(directory.path, 'persistent_offline_data');
    final destDir = Directory(persistentOfflinePath);

    // Ensure the destination directory exists
    await destDir.create(recursive: true);

    // Copy all files and subdirectories
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

  // MARK: Cancel layer download
  void cancelLayerDownload(String layerName) {
    setState(() {
      if (layerName == 'Base Map') {
        baseMapDownloader.cancelBaseMapDownload = true;
      } else {
        layerCancelled[layerName] = true;
      }
    });
  }

  // MARK: Agreement sheet
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
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                      ),
                      child: const Text(
                        "Download Layers",
                        style: TextStyle(
                          color: Colors.white,
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
      onContainerSelected: (container) {
        navigateToWebViewOffline(container); // Pass the container
      },
    );
  }

  // MARK: Navigate Offline
  Future<void> navigateToWebViewOffline(OfflineContainer container) async {
    print('Starting offline navigation process');

    final directory = await getApplicationDocumentsDirectory();
    final offlineDataDirectory = '${directory.path}/persistent_offline_data';
    print('Navigation offline data directory: $offlineDataDirectory');

    // Check if offline data exists
    if (!await Directory(offlineDataDirectory).exists()) {
      print('Error: Offline data not found. Please download the data first.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Offline data not found. Please download first.')),
        );
      }
      return;
    }

    _localServer = LocalServer(offlineDataDirectory);
    final serverUrl = await _localServer!.start();
    print('Local server started at: $serverUrl');

    try {
      // Fetch plans data first
      final plansResponse = await http.get(
        Uri.parse('$serverUrl/api/v1/get_plans/?block_id=$selectedBlockID'),
      );

      if (plansResponse.statusCode != 200) {
        print('Failed to fetch plans: ${plansResponse.statusCode}');
        return;
      }

      // Encode the plans data
      final encodedPlans = Uri.encodeComponent(plansResponse.body);

      print('Encoded plans data: $encodedPlans');

      String url = "$serverUrl/maps?" +
          "geoserver_url=$serverUrl" +
          "&state_name=${container.state}" +
          "&dist_name=${container.district}" +
          "&block_name=${container.block}" +
          "&block_id=${selectedBlockID}" +
          "&isOffline=true" +
          "&plans=$encodedPlans";

      print('Navigating to URL: $url');

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewApp(url: url),
        ),
      );
    } finally {
      _localServer?.stop();
      print('Returned from WebView, local server stopped');
    }
  }

  // Progress sheet
  void showDownloadProgressSheet(OfflineContainer container) {
    // Update the BaseMapDownloader to use both setState callbacks
    baseMapDownloader = BaseMapDownloader(
      onProgressUpdate: (progress) {
        setState(() {
          baseMapProgress = progress;
        });
        _sheetSetState?.call(() {}); // Update the sheet's state
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
            _sheetSetState = setSheetState; // Store the sheet's setState
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
                                  "Current Container",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF592941),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
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
                                      
                                      // Overall progress bar
                                      FutureBuilder<List<Map<String, String>>>(
                                        future: getLayers(selectedDistrict, selectedBlock),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            // Calculate overall progress
                                            double totalProgress = 0;
                                            int completedLayers = 0;
                                            int totalLayers = snapshot.data!.length + 1; 
                                            
                                            // Add base map progress
                                            if (baseMapProgress == 1.0) completedLayers++;
                                            totalProgress += baseMapProgress;
                                            
                                            // Add vector layers progress
                                            for (var layer in snapshot.data!) {
                                              double layerProgress = vectorLayerProgress[layer['name']] ?? 0.0;
                                              if (layerProgress == 1.0) completedLayers++;
                                              totalProgress += layerProgress;
                                            }
                                            
                                            // Calculate average progress
                                            double overallProgress = totalProgress / totalLayers;
                                            
                                            return Column(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: LinearProgressIndicator(
                                                    value: overallProgress,
                                                    backgroundColor: Colors.white.withAlpha(77),
                                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF592941)),
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
                                // Layer status list
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    border: Border.all(color:const Color(0xFFD6D5C9), width: 2),
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
                                            const Icon(Icons.check_circle, color: Colors.green)
                                          else if (baseMapProgress > 0 && baseMapProgress < 1)
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
                                        future: getLayers(selectedDistrict, selectedBlock),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            return Column(
                                              children: snapshot.data!.map((layer) {
                                                double layerProgress = vectorLayerProgress[layer['name']] ?? 0.0;
                                                return Padding(
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
                                                );
                                              }).toList(),
                                            );
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
                                    isDownloading
                                        ? "Download in Progress"
                                        : "Download Complete",
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
                                // Show completion popup
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
                                        'All layers have been downloaded successfully. You can now access this container offline.',
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

    // Start the download process after showing the sheet
    downloadAllLayers(container);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFFD6D5C9), width: 3.0),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.white,
          // Customize the dropdown menu theme
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
              onChanged(newValue);
            },
            items: items.map((Map<String, dynamic> map) {
              return DropdownMenuItem<String>(
                value: map["label"],
                child: Text(
                  map["label"],
                  style: const TextStyle(color: Color(0xFF592941)),
                ),
              );
            }).toList(),
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF592941)),
            // Customize the dropdown button
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSubmitEnabled = selectedState != null &&
        selectedDistrict != null &&
        selectedBlock != null;

    return Scaffold(
      backgroundColor:
          const Color.fromARGB(255, 255, 255, 255).withOpacity(1.0),
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: const Text('Select a location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => UseInfo.showInstructionsSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32.0),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Operate in online mode',
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
                  hint: 'Select a state',
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
                  hint: 'Select a district',
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
                  hint: 'Select a block',
                  items: blocks,
                  onChanged: (String? value) {
                    if (value != null) {
                      updateSelectedBlock(value);
                    }
                  },
                ),
                const SizedBox(height: 34.0),

                // checker
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: isSubmitEnabled ? submitLocation : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSubmitEnabled
                              ? const Color(0xFFD6D5C9)
                              : Colors.grey,
                          foregroundColor: const Color(0xFF592941),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child:
                            const Text('Submit', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32.0),

                const Divider(
                  height: 32.0,
                  thickness: 1,
                  indent: 40,
                  endIndent: 40,
                  color: Color(0xFFD6D5C9),
                ),

                const SizedBox(height: 16.0),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Operate in offline mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF592941),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Containers button
                SizedBox(
                  width: 320,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isSubmitEnabled
                        ? () {
                            ContainerSheets.showCreateContainer(
                              context: context,
                              selectedState: selectedState!,
                              selectedDistrict: selectedDistrict!,
                              selectedBlock: selectedBlock!,
                              onContainerCreated: (container) {
                                showAgreementSheet(container);
                              },
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSubmitEnabled ? const Color(0xFFD6D5C9) : Colors.grey,
                      foregroundColor: const Color(0xFF592941),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text('Create a container',
                        style: TextStyle(fontSize: 18)),
                  ),
                ),

                const SizedBox(height: 16.0), // Added spacing between buttons

                // Offline button
                SizedBox(
                  width: 320,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isSubmitEnabled
                        ? () {
                            ContainerSheets.showContainerList(
                              context: context,
                              onContainerSelected: (container) {
                                navigateToWebViewOffline(container);
                              },
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSubmitEnabled ? const Color(0xFFD6D5C9) : Colors.grey,
                      foregroundColor: const Color(0xFF592941),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text('Work offline*',
                        style: TextStyle(fontSize: 18)),
                  ),
                ),

                // Header text for Collections button
                const SizedBox(height: 20.0),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    "*BETA Offline mode works in remote areas without internet with limited features.",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color.fromARGB(255, 122, 122, 122),
                    ),
                  ),
                ),
                const SizedBox(height: 32.0),  // Replace Spacer with fixed height
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'version: 2.0.0',
                    style: TextStyle(
                      color: Color(0xFF592941),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
