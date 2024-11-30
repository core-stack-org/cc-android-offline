import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model class representing an offline container that stores downloaded map data
class OfflineContainer {
  final String name;
  final String state;
  final String district;
  final String block;
  final DateTime createdAt;
  final bool isDownloaded;
  final double latitude; // New field for location
  final double longitude; // New field for location

  OfflineContainer({
    required this.name,
    required this.state,
    required this.district,
    required this.block,
    required this.createdAt,
    this.isDownloaded = false,
    required this.latitude, // Optional location
    required this.longitude, // Optional location
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'state': state,
        'district': district,
        'block': block,
        'createdAt': createdAt.toIso8601String(),
        'isDownloaded': isDownloaded,
        'latitude': latitude, // Save location to JSON
        'longitude': longitude, // Save location to JSON
      };

  factory OfflineContainer.fromJson(Map<String, dynamic> json) =>
      OfflineContainer(
        name: json['name'],
        state: json['state'],
        district: json['district'],
        block: json['block'],
        createdAt: DateTime.parse(json['createdAt']),
        isDownloaded: json['isDownloaded'] ?? false,
        latitude: json['latitude']?.toDouble(), // Read location from JSON
        longitude: json['longitude']?.toDouble(), // Read location from JSON
      );
}

/// Manager class handling offline container operations and persistence
class ContainerManager {
  static const String _storageKey = 'offline_containers';

  /// Retrieves all saved containers
  static Future<List<OfflineContainer>> getContainers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? containersJson = prefs.getString(_storageKey);
    if (containersJson == null) return [];
    List<dynamic> jsonList = json.decode(containersJson);
    return jsonList.map((json) => OfflineContainer.fromJson(json)).toList();
  }

  /// Saves a new container
  /// Throws exception if container with same name exists
  static Future<void> saveContainer(OfflineContainer container) async {
    final prefs = await SharedPreferences.getInstance();
    List<OfflineContainer> containers = await getContainers();

    // Check for duplicate names
    if (containers.any((c) => c.name == container.name)) {
      throw Exception('A container with this name already exists');
    }

    containers.add(container);
    final String jsonString =
        json.encode(containers.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Updates the download status of a container
  static Future<void> updateContainerDownloadStatus(
      String name, bool isDownloaded) async {
    final prefs = await SharedPreferences.getInstance();
    List<OfflineContainer> containers = await getContainers();
    final index = containers.indexWhere((c) => c.name == name);
    if (index == -1) return;

    containers[index] = OfflineContainer(
      name: containers[index].name,
      state: containers[index].state,
      district: containers[index].district,
      block: containers[index].block,
      createdAt: containers[index].createdAt,
      isDownloaded: isDownloaded,
      latitude: containers[index].latitude, // Preserve location
      longitude: containers[index].longitude, // Preserve location
    );

    final String jsonString =
        json.encode(containers.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Deletes a container by name
  static Future<void> deleteContainer(String name) async {
    final prefs = await SharedPreferences.getInstance();
    List<OfflineContainer> containers = await getContainers();
    containers.removeWhere((c) => c.name == name);
    final String jsonString =
        json.encode(containers.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Gets a specific container by name
  static Future<OfflineContainer?> getContainer(String name) async {
    final containers = await getContainers();
    try {
      return containers.firstWhere((c) => c.name == name);
    } catch (e) {
      return null;
    }
  }
}
