import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'container_manager.dart';
import './../utils/mark_location.dart';

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
                      "Create New Container",
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
                              geoserverUrl:
                                  "https://geoserver.gramvaani.org:8443",
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
                        backgroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        locationSelected
                            ? 'Location: ${selectedLat?.toStringAsFixed(4)}, ${selectedLon?.toStringAsFixed(4)}'
                            : 'Step 1: Select Location',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Step 2: Container Name (disabled until location is selected)
                    TextField(
                      controller: containerNameController,
                      enabled: locationSelected,
                      decoration: InputDecoration(
                        labelText: 'Step 2: Name your container',
                        border: const OutlineInputBorder(),
                        enabled: locationSelected,
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
                                        content: Text(
                                            'Please enter a container name')),
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
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                        ),
                        child: const Text(
                          "Create Container",
                          style: TextStyle(
                            color: Colors.white,
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
    required Function(OfflineContainer) onContainerSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return FutureBuilder<List<OfflineContainer>>(
          future: ContainerManager.getContainers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final containers = snapshot.data!;

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Select Container",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF592941),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (containers.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.inbox, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  "No containers available",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    "Create a new container and download data for offline use",
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: controller,
                            itemCount: containers.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final container = containers[index];
                              return // Inside the ListView.separated builder in showContainerList:
                                  ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
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
                                    const SizedBox(height: 4),
                                    Text(
                                      '${container.state} > ${container.district} > ${container.block}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        bool confirm = await showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Delete Container'),
                                                content: Text(
                                                    'This will delete all offline data for ${container.name}. Continue?'),
                                                actions: [
                                                  TextButton(
                                                    child: const Text('Cancel'),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, false),
                                                  ),
                                                  TextButton(
                                                    child: const Text('Delete'),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, true),
                                                  ),
                                                ],
                                              ),
                                            ) ??
                                            false;

                                        if (confirm && context.mounted) {
                                          await _deleteContainerAndData(
                                              container.name);
                                          Navigator.pop(context);
                                          // Show confirmation snackbar
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Container ${container.name} deleted'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    if (container.isDownloaded)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            onContainerSelected(container);
                                          },
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        child: const Icon(
                                          Icons.download_outlined,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  static Future<void> _deleteContainerAndData(String containerName) async {
    final directory = await getApplicationDocumentsDirectory();

    // Paths to clean up
    final paths = [
      '${directory.path}/assets/offline_data/base_map_tiles',
      '${directory.path}/assets/offline_data/vector_layers',
      '${directory.path}/persistent_offline_data/base_map_tiles',
      '${directory.path}/persistent_offline_data/vector_layers',
    ];

    // Delete the directories
    for (String path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    // Delete container from storage
    await ContainerManager.deleteContainer(containerName);
  }
}
