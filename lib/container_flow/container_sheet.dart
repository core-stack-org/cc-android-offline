import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nrmflutter/utils/constants.dart';
import 'package:nrmflutter/db/location_db.dart';
import 'package:nrmflutter/utils/layers_config.dart';
import 'package:http/http.dart' as http;

import 'dart:io';
import 'container_manager.dart';
import './../utils/mark_location.dart';
import './../download_progress.dart';

class ContainerSheets {
  /// Shows bottom sheet for creating a new container
  static void showCreateContainer({
    required BuildContext context,
    required String selectedState,
    required String selectedDistrict,
    required String selectedBlock,
    required Function(OfflineContainer) onContainerCreated,
  }) {
    final containerNameController = TextEditingController();
    double? selectedLat;
    double? selectedLon;
    bool locationSelected = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Create a new region",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF592941),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Step 1: Location Selection
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapLocationSelector(
                              blockName: selectedBlock,
                              districtName: selectedDistrict,
                              geoserverUrl: geoserverUrl,
                              onLocationSelect: (lat, lon) {
                                setState(() {
                                  selectedLat = lat;
                                  selectedLon = lon;
                                  locationSelected = true;
                                });
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD6D5C9),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          locationSelected
                              ? 'Latitude: ${selectedLat?.toStringAsFixed(4)}, Longitude: ${selectedLon?.toStringAsFixed(4)}'
                              : 'Mark a location on the map',
                          style: const TextStyle(
                            color: Color(0xFF592941),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Step 2: Container Name (disabled until location is selected)
                    Container(
                      decoration: BoxDecoration(
                        color: locationSelected
                            ? const Color(0xFFD6D5C9)
                            : const Color(0xFFddd8e0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: containerNameController,
                        enabled: locationSelected,
                        style: TextStyle(
                          color: const Color(0xFF592941),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Name your region',
                          hintStyle: TextStyle(
                            color: const Color(0xFF592941),
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          enabled: locationSelected,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: locationSelected &&
                                containerNameController.text.isNotEmpty
                            ? () async {
                                if (containerNameController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Please enter a region name')),
                                  );
                                  return;
                                }

                                try {
                                  final container = OfflineContainer(
                                    name: containerNameController.text,
                                    state: selectedState,
                                    district: selectedDistrict,
                                    block: selectedBlock,
                                    createdAt: DateTime.now(),
                                    latitude: selectedLat!,
                                    longitude: selectedLon!,
                                  );

                                  await ContainerManager.saveContainer(
                                      container);
                                  Navigator.pop(context);
                                  onContainerCreated(container);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD6D5C9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                        ),
                        child: const Text(
                          "Create Region",
                          style: TextStyle(
                            color: Color(0xFF592941),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shows bottom sheet for selecting an existing container
  static void showContainerList({
    required BuildContext context,
    required String selectedState,
    required String selectedDistrict,
    required String selectedBlock,
    required Function(OfflineContainer) onContainerSelected,
  }) {
    String? selectedContainerId;
    String? _refreshingContainerName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Select a region',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF592941),
                      ),
                    ),
                  ],
                ),
              ),
              if (_refreshingContainerName != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: LinearProgressIndicator(
                    color: Colors.blue,
                    backgroundColor: Colors.blue.withOpacity(0.2),
                  ),
                ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: FutureBuilder<List<OfflineContainer>>(
                    future: ContainerManager.getContainers(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final containers = snapshot.data!;

                      if (containers.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Looks like there are no regions created yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 129, 129, 129),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Please create one region',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Sort containers by creation date, newest first
                      containers
                          .sort((a, b) => b.createdAt.compareTo(a.createdAt));

                      final selectedContainer = containers.firstWhere(
                        (container) => container.name == selectedContainerId,
                        orElse: () => containers.first,
                      );

                      return ListView.builder(
                        itemCount: containers.length,
                        itemBuilder: (context, index) {
                          final container = containers[index];
                          final isSelected =
                              container.name == selectedContainerId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFDBEFF2)
                                  : Colors.white,
                              border: Border.all(
                                  color: const Color(0xFF8DCBD5), width: 1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: () {
                                setState(() {
                                  selectedContainerId = container.name;
                                });
                              },
                              trailing: PopupMenuButton<String>(
                                color: Colors.black.withAlpha(215),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                onSelected: (value) async {
                                  if (value == 'redownload') {
                                    _handleRedownload(context, container);
                                  } else if (value == 'refresh') {
                                    setState(() {
                                      _refreshingContainerName = container.name;
                                    });
                                    await _refreshPlanLayers(
                                        context, container);
                                    if (context.mounted) {
                                      setState(() {
                                        _refreshingContainerName = null;
                                      });
                                    }
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'redownload',
                                    child: Text(
                                      'Redownload all the layers',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'refresh',
                                    child: Text(
                                      'Refresh mapping/plan layers',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                container.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    '${container.state} > ${container.district} > ${container.block}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    container.isDownloaded
                                        ? 'Ready for offline use'
                                        : 'Not yet downloaded',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: container.isDownloaded
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedContainerId != null)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFe63946),
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Color(0xFFe63946), width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                bool confirm = await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Container'),
                                        content: Text(
                                            'This will delete all offline data for ${selectedContainerId}. Continue?'),
                                        actions: [
                                          TextButton(
                                            child: const Text('Cancel'),
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                          ),
                                          TextButton(
                                            child: const Text('Delete'),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;

                                if (confirm && context.mounted) {
                                  await _deleteContainerAndData(
                                      selectedContainerId!);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Region $selectedContainerId deleted'),
                                      backgroundColor: const Color(0xFFFF4D6D),
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD6D5C9),
                                foregroundColor: const Color(0xFF592941),
                                side: const BorderSide(
                                    color: Color(0xFFD6D5C9), width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                final container =
                                    await ContainerManager.getContainer(
                                        selectedContainerId!);
                                if (container != null && context.mounted) {
                                  Navigator.pop(context);
                                  onContainerSelected(container);
                                }
                              },
                              child: const Text(
                                'Navigate',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF592941),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (selectedContainerId != null) const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD6D5C9),
                          foregroundColor: const Color(0xFF592941),
                          side: const BorderSide(
                              color: Color(0xFFD6D5C9), width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          ContainerSheets.showCreateContainer(
                            context: context,
                            selectedState: selectedState!,
                            selectedDistrict: selectedDistrict!,
                            selectedBlock: selectedBlock!,
                            onContainerCreated: (container) {
                              onContainerSelected(container);
                            },
                          );
                        },
                        child: const Text(
                          'Create a region',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF592941),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _handleRedownload(
      BuildContext context, OfflineContainer container) async {
    final blockId =
        await _getBlockId(container.state, container.district, container.block);
    if (blockId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not find block information to re-download.')));
      }
      return;
    }

    if (context.mounted) {
      Navigator.pop(context); // close sheet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DownloadProgressPage(
            container: container,
            selectedDistrict: container.district,
            selectedBlock: container.block,
            selectedBlockID: blockId,
          ),
        ),
      );
    }
  }

  static Future<void> _handleRefresh(
      BuildContext context, OfflineContainer container) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Refreshing plan data for ${container.name}...')));
    await _refreshPlanLayers(context, container);
  }

  static Future<void> _refreshPlanLayers(
      BuildContext context, OfflineContainer container) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Refreshing plan data for ${container.name}...')));
    final blockId =
        await _getBlockId(container.state, container.district, container.block);
    if (blockId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not find block information to refresh.')));
      }
      return;
    }

    try {
      final allLayers = await LayersConfig.getLayers(
          container.district, container.block,
          blockId: blockId);

      const planLayerPrefixes = [
        'settlement_',
        'well_',
        'waterbody_',
        'main_swb_',
        'plan_agri_',
        'plan_gw_',
        'livelihood_'
      ];
      final planLayers = allLayers
          .where((layer) => planLayerPrefixes
              .any((prefix) => layer['name']!.startsWith(prefix)))
          .toList();

      if (planLayers.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No plan layers to refresh.')));
        }
        return;
      }

      for (var layer in planLayers) {
        await _downloadVectorLayer(
            layer['name']!, layer['geoserverPath']!, container);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Successfully refreshed plan data for ${container.name}'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  static Future<String?> _getBlockId(
      String stateName, String districtName, String blockName) async {
    final List<Map<String, dynamic>> states =
        await LocationDatabase.instance.getLocationData();
    for (var state in states) {
      if (state['label'] == stateName) {
        final List<Map<String, dynamic>> districts =
            List<Map<String, dynamic>>.from(state['district']);
        for (var district in districts) {
          if (district['label'] == districtName) {
            final List<Map<String, dynamic>> blocks =
                List<Map<String, dynamic>>.from(district['blocks']);
            for (var block in blocks) {
              if (block['label'] == blockName) {
                return block['block_id'].toString();
              }
            }
          }
        }
      }
    }
    return null;
  }

  static String _formatLayerName(String layerName) {
    return layerName.toLowerCase().replaceAll(' ', '_');
  }

  static Future<void> _downloadVectorLayer(String layerName,
      String geoserverPath, OfflineContainer container) async {
    try {
      print(
          "Starting download of vector layer: $layerName for container: ${container.name}");

      final url =
          '${geoserverUrl}geoserver/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=$geoserverPath&outputFormat=application/json';
      print("Downloading from URL: $url");

      final request =
          await http.Client().send(http.Request('GET', Uri.parse(url)));

      if (request.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final formattedLayerName = _formatLayerName(layerName);

        final containerPath =
            '${directory.path}/persistent_offline_data/containers/${container.name}';

        final filePath =
            '$containerPath/vector_layers/$formattedLayerName.geojson';
        print("Saving layer to: $filePath");

        final file = File(filePath);
        await file.create(recursive: true);

        final sink = file.openWrite();

        await for (final chunk in request.stream) {
          sink.add(chunk);
        }

        await sink.close();
        print("Successfully saved layer $layerName");
      } else {
        print(
            "Failed to download $layerName. Status code: ${request.statusCode}");
        throw Exception(
            'Failed to download $layerName. Status code: ${request.statusCode}');
      }
    } catch (e) {
      print('Error downloading $layerName: $e');
      rethrow;
    }
  }

  static Future<void> _deleteContainerAndData(String containerName) async {
    final directory = await getApplicationDocumentsDirectory();

    // Container-specific path
    final containerPath =
        '${directory.path}/persistent_offline_data/containers/$containerName';
    final containerDir = Directory(containerPath);

    // Delete the container directory if it exists
    if (await containerDir.exists()) {
      await containerDir.delete(recursive: true);
    }

    // Delete container from storage
    await ContainerManager.deleteContainer(containerName);
  }
}
