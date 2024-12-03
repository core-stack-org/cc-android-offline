import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class MapLocationSelector extends StatefulWidget {
  final String blockName;
  final String districtName;
  final String geoserverUrl;
  final Function(double, double) onLocationSelect;

  const MapLocationSelector({
    Key? key,
    required this.blockName,
    required this.districtName,
    required this.geoserverUrl,
    required this.onLocationSelect,
  }) : super(key: key);

  @override
  _MapLocationSelectorState createState() => _MapLocationSelectorState();
}

class _MapLocationSelectorState extends State<MapLocationSelector> {
  LatLng? selectedLocation;
  List<LatLng> boundaryPoints = [];
  List<LatLng> panchayatBoundary = [];
  bool isLoading = true;
  double _currentZoom = 13.0;
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    fetchPanchayatBoundary();
    fetchBoundaryPoints();
  }

  Future<void> fetchPanchayatBoundary() async {
    final url = Uri.parse(
        '${widget.geoserverUrl}/geoserver/panchayat_boundaries/ows?'
        'service=WFS&version=1.0.0&request=GetFeature&typeName=panchayat_boundaries:${widget.districtName.toLowerCase()}_${widget.blockName.toLowerCase()}'
        '&outputFormat=application/json');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final geojson = jsonDecode(response.body);

        if (geojson['features'] != null && geojson['features'].isNotEmpty) {
          // Extract coordinates from the first feature
          final List<dynamic> rings =
              geojson['features'][0]['geometry']['coordinates'];

          List<LatLng> boundaryPoints = [];

          for (var ring in rings) {
            for (var coord in ring) {
              final double lon = (coord[0] is int)
                  ? (coord[0] as int).toDouble()
                  : coord[0] as double;
              final double lat = (coord[1] is int)
                  ? (coord[1] as int).toDouble()
                  : coord[1] as double;
              boundaryPoints.add(LatLng(lat, lon));
            }
          }

          setState(() {
            panchayatBoundary = boundaryPoints;
          });

          // If boundary is loaded, zoom to it
          if (panchayatBoundary.isNotEmpty) {
            double minLat = panchayatBoundary[0].latitude;
            double maxLat = panchayatBoundary[0].latitude;
            double minLon = panchayatBoundary[0].longitude;
            double maxLon = panchayatBoundary[0].longitude;

            for (var point in panchayatBoundary) {
              minLat = math.min(minLat, point.latitude);
              maxLat = math.max(maxLat, point.latitude);
              minLon = math.min(minLon, point.longitude);
              maxLon = math.max(maxLon, point.longitude);
            }

            // Calculate center and zoom level
            final centerLat = (minLat + maxLat) / 2;
            final centerLon = (minLon + maxLon) / 2;

            // Move map to center of boundary
            mapController.move(
              LatLng(centerLat, centerLon),
              13.0, // You can adjust this zoom level
            );
          }
        }
      } else {
        print('Failed to fetch panchayat boundary: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching panchayat boundary: $e');
    }
  }

  Future<void> fetchBoundaryPoints() async {
    try {
      final url = '${widget.geoserverUrl}/geoserver/panchayat_boundaries/ows'
          '?service=WFS'
          '&version=1.0.0'
          '&request=GetFeature'
          '&typeName=panchayat_boundaries:${widget.districtName.toLowerCase()}_${widget.blockName.toLowerCase()}'
          '&outputFormat=application/json'
          '&screen=main';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final coordinates = data['features'][0]['geometry']['coordinates'][0];
          boundaryPoints = coordinates.map<LatLng>((coord) {
            return LatLng(coord[1], coord[0]);
          }).toList();

          // Center map on boundary
          if (boundaryPoints.isNotEmpty) {
            double minLat = double.infinity;
            double maxLat = -double.infinity;
            double minLng = double.infinity;
            double maxLng = -double.infinity;

            for (var point in boundaryPoints) {
              minLat = minLat < point.latitude ? minLat : point.latitude;
              maxLat = maxLat > point.latitude ? maxLat : point.latitude;
              minLng = minLng < point.longitude ? minLng : point.longitude;
              maxLng = maxLng > point.longitude ? maxLng : point.longitude;
            }

            final centerLat = (minLat + maxLat) / 2;
            final centerLng = (minLng + maxLng) / 2;
            mapController.move(LatLng(centerLat, centerLng), 12);
          }
        }
      }
    } catch (e) {
      print('Error fetching boundary data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _showLatLonDialog() async {
    final TextEditingController latController = TextEditingController();
    final TextEditingController lonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Coordinates'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: latController,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter latitude';
                    }
                    final lat = double.tryParse(value);
                    if (lat == null) {
                      return 'Please enter a valid number';
                    }
                    if (lat < -90 || lat > 90) {
                      return 'Latitude must be between -90 and 90';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: lonController,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter longitude';
                    }
                    final lon = double.tryParse(value);
                    if (lon == null) {
                      return 'Please enter a valid number';
                    }
                    if (lon < -180 || lon > 180) {
                      return 'Longitude must be between -180 and 180';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final lat = double.parse(latController.text);
                  final lon = double.parse(lonController.text);
                  setState(() {
                    selectedLocation = LatLng(lat, lon);
                  });
                  mapController.move(LatLng(lat, lon), _currentZoom);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Mark a Location',
            style: TextStyle(
              color: Colors.white,
            )),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'add_lat_lon') {
                _showLatLonDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'add_lat_lon',
                child: Text('Add Lat/Lon'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              onMapEvent: (MapEvent event) {
                if (event is MapEventMove) {
                  setState(() {
                    _currentZoom = event.camera.zoom;
                  });
                }
              },
              initialCenter: LatLng(20.5937, 78.9629),
              initialZoom: 5.0,
              onTap: (tapPosition, point) {
                setState(() {
                  selectedLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (panchayatBoundary.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: panchayatBoundary,
                      color: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (boundaryPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: boundaryPoints,
                      color: Colors.red.withOpacity(0.2),
                      borderColor: Colors.red,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Zoom controls
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final newZoom = _currentZoom + 1;
                          mapController.move(
                            selectedLocation ?? mapController.camera.center,
                            newZoom,
                          );
                          setState(() {
                            _currentZoom = newZoom;
                          });
                        },
                        tooltip: 'Zoom in',
                      ),
                      Container(
                        height: 1,
                        color: Colors.grey[300],
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          final newZoom = _currentZoom - 1;
                          mapController.move(
                            selectedLocation ?? mapController.camera.center,
                            newZoom,
                          );
                          setState(() {
                            _currentZoom = newZoom;
                          });
                        },
                        tooltip: 'Zoom out',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (selectedLocation != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 20,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Lat: ${selectedLocation!.latitude.toStringAsFixed(4)}, '
                        'Lon: ${selectedLocation!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onLocationSelect(
                          selectedLocation!.latitude,
                          selectedLocation!.longitude,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
