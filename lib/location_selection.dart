import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'webview.dart';
import 'dart:convert';
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
  StateSetter? sheetSetState;
  bool isDownloading = false;
  bool isDownloadComplete = false;
  double baseMapProgress = 0.0;
  Map<String, double> vectorLayerProgress = {};
  Map<String, bool> layerCancelled = {};
  bool isAgreed = false;
  bool cancelBaseMapDownload = false;
  LocalServer? _localServer;
  late BaseMapDownloader baseMapDownloader;

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
    final selectedBlockData = blocks.firstWhere((b) => b["label"] == block);
    setState(() {
      selectedBlock = block;
      selectedBlockID = selectedBlockData["block_id"];
    });
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

  List<Map<String, String>> getLayers(String? district, String? block) {
    return LayersConfig.getLayers(district, block);
  }

  Future<void> downloadVectorLayers() async {
    final layers = getLayers(selectedDistrict, selectedBlock);
    print("Starting to download ${layers.length} vector layers");
    for (var layer in layers) {
      if (layerCancelled[layer['name']] == true) continue;
      setState(() {
        vectorLayerProgress[layer['name']!] = 0.0;
      });
      await downloadVectorLayer(layer['name']!, layer['geoserverPath']!);
    }

    // After downloading all layers, use OfflineAssetsManager to copy to persistent storage
    await OfflineAssetsManager.copyOfflineAssets(forceUpdate: true);
  }

  String formatLayerName(String layerName) {
    return layerName.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> downloadVectorLayer(
      String layerName, String geoserverPath) async {
    try {
      if (layerCancelled[layerName] == true) {
        setState(() {
          vectorLayerProgress[layerName] = -1.0;
        });
        sheetSetState?.call(() {}); // Update sheet state
        return;
      }

      final url =
          'https://geoserver.gramvaani.org:8443/geoserver/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=$geoserverPath&outputFormat=application/json';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        print('Response code came fine for $layerName');
        final directory = await getApplicationDocumentsDirectory();
        final formattedLayerName = formatLayerName(layerName);
        final file = File(
            '${directory.path}/assets/offline_data/vector_layers/$formattedLayerName.geojson');
        await file.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          vectorLayerProgress[layerName] = 1.0;
        });
        sheetSetState?.call(() {}); // Update sheet state
      } else {
        throw Exception(
            'Failed to download $layerName. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading $layerName: $e');
      setState(() {
        vectorLayerProgress[layerName] = -1.0;
      });
      sheetSetState?.call(() {}); // Update sheet state
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

    String url = "$serverUrl/maps?" +
        "geoserver_url=$serverUrl" +
        "&state_name=${container.state}" +
        "&dist_name=${container.district}" +
        "&block_name=${container.block}" +
        "&block_id=${selectedBlockID}" +
        "&isOffline=true";

    print('Navigating to URL: $url');

    try {
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
    StateSetter? sheetSetState; // Keep track of the sheet's setState

    // Update the BaseMapDownloader to use both setState callbacks
    baseMapDownloader = BaseMapDownloader(
      onProgressUpdate: (progress) {
        setState(() {
          baseMapProgress = progress;
        });
        sheetSetState?.call(() {}); // Update the sheet's state
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
            sheetSetState = setSheetState; // Store the sheet's setState
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.3,
              maxChildSize: 0.80,
              expand: false,
              builder: (_, controller) {
                return Container(
                  padding: const EdgeInsets.all(20),
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
                        "Container: ${container.name}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF592941),
                        ),
                      ),
                      const SizedBox(height: 25),
                      _buildLayerProgressItem("Base Map", baseMapProgress, () {
                        cancelLayerDownload("Base Map");
                        setSheetState(() {}); // Update sheet when cancelled
                      }),
                      ...getLayers(selectedDistrict, selectedBlock)
                          .map((layer) {
                        return _buildLayerProgressItem(layer['name']!,
                            vectorLayerProgress[layer['name']] ?? 0.0, () {
                          cancelLayerDownload(layer['name']!);
                          setSheetState(() {}); // Update sheet when cancelled
                        });
                      }),
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
                      if (isDownloadComplete) ...[
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 40,
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "You can now access this container from the Offline button",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF592941),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
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
                child: Text('Cancel'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: progress >= 0 ? progress : 0,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          minHeight: 10, // Make the progress bar more prominent
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDropdown(
                value: selectedState,
                hint: 'Select State',
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
                hint: 'Select District',
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
                hint: 'Select Block',
                items: blocks,
                onChanged: (String? value) {
                  setState(() {
                    selectedBlock = value;
                  });
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
            ],
          ),
        ),
      ),
    );
  }
}
