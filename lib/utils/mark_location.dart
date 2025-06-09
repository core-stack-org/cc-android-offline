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
  List<List<LatLng>> allPolygons = [];
  List<({LatLng point, String name})> villageMarkers = [];
  bool isLoading = true;
  double _currentZoom = 11.0;
  final MapController mapController = MapController();
  bool _isSatelliteView = false;

  @override
  void initState() {
    super.initState();
    fetchPanchayatBoundary();
  }

  /// Formats district/block names for GeoServer layer naming convention
  String _formatNameForGeoServer(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'[-\s]+'), '_')
        .trim();
  }

  Future<void> fetchPanchayatBoundary() async {
    final formattedDistrict = _formatNameForGeoServer(widget.districtName);
    final formattedBlock = _formatNameForGeoServer(widget.blockName);
    
    final url = Uri.parse(
        '${widget.geoserverUrl}geoserver/panchayat_boundaries/ows?'
        'service=WFS&version=1.0.0&request=GetFeature&typeName=panchayat_boundaries:${formattedDistrict}_${formattedBlock}'
        '&outputFormat=application/json');

    print("geoserver url: $url");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final geojson = jsonDecode(response.body);

        if (geojson['features'] != null && geojson['features'].isNotEmpty) {
          List<List<LatLng>> polygonsFromAllFeatures = [];

          for (var feature in geojson['features']) {
            final geometry = feature['geometry'];
            final geomType = geometry['type'];
            final coords = geometry['coordinates'];

            if (geomType == 'Polygon') {
              List<LatLng> polygonPoints = [];
              for (var coord in coords[0]) {
                polygonPoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
              }
              polygonsFromAllFeatures.add(polygonPoints);
            } else if (geomType == 'MultiPolygon') {
              for (var polygon in coords) {
                List<LatLng> polygonPoints = [];
                for (var ring in polygon) {
                  for (var coord in ring) {
                    polygonPoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
                  }
                }
                polygonsFromAllFeatures.add(polygonPoints);
              }
            }

            // Calculate center point for the village name
            double centerLat = 0;
            double centerLon = 0;
            int pointCount = 0;

            if (geomType == 'Polygon') {
              for (var coord in coords[0]) {
                centerLat += coord[1].toDouble();
                centerLon += coord[0].toDouble();
                pointCount++;
              }
            } else if (geomType == 'MultiPolygon') {
              for (var polygon in coords) {
                for (var ring in polygon) {
                  for (var coord in ring) {
                    centerLat += coord[1].toDouble();
                    centerLon += coord[0].toDouble();
                    pointCount++;
                  }
                }
              }
            }
          }

          // Calculate bounding box for all polygons
          double minLat = double.infinity;
          double maxLat = -double.infinity;
          double minLon = double.infinity;
          double maxLon = -double.infinity;

          for (var polygonPoints in polygonsFromAllFeatures) {
            for (var point in polygonPoints) {
              minLat = math.min(minLat, point.latitude);
              maxLat = math.max(maxLat, point.latitude);
              minLon = math.min(minLon, point.longitude);
              maxLon = math.max(maxLon, point.longitude);
            }
          }

          setState(() {
            allPolygons = polygonsFromAllFeatures;
            isLoading = false;
          });

          // Move map to show all polygons
          if (allPolygons.isNotEmpty) {
            final centerLat = (minLat + maxLat) / 2;
            final centerLon = (minLon + maxLon) / 2;
            mapController.move(LatLng(centerLat, centerLon), 13.0);
          }
        } else {
          print('No features found in the response.');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        print('Failed to fetch panchayat boundary: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching panchayat boundary: $e');
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
        title: const Text(
          'Place your marker',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
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
                urlTemplate: _isSatelliteView 
                  ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                  : 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
              ),
              if (allPolygons.isNotEmpty)
                PolygonLayer(
                  polygons: allPolygons.map((polygonPoints) {
                    return Polygon(
                      points: polygonPoints,
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),
              if (_currentZoom >= 13)
                MarkerLayer(
                  markers: villageMarkers
                      .map((marker) => Marker(
                            point: marker.point,
                            width: 150,
                            height: 30,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                marker.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ))
                      .toList(),
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
                    color: const Color(0xFFD6D5C9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD6D5C9),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.layers, color: const Color(0xFF592941)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Select Map Layer'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text('Default'),
                                  leading: Radio<bool>(
                                    value: false,
                                    groupValue: _isSatelliteView,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _isSatelliteView = value!;
                                      });
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                                ListTile(
                                  title: const Text('OpenStreetMap'),
                                  leading: Radio<bool>(
                                    value: true,
                                    groupValue: _isSatelliteView,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _isSatelliteView = value!;
                                      });
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    tooltip: 'Change map layer',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D5C9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD6D5C9),
                      width: 2,
                    ),
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
                        icon: Icon(Icons.add, color: const Color(0xFF592941)),
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
                        color: const Color(0xFF592941),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove, color: const Color(0xFF592941)),
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
                        border: Border.all(
                          width: 2,
                          color: const Color(0xFFD6D5C9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Lat: ${selectedLocation!.latitude.toStringAsFixed(4)}, '
                        'Lon: ${selectedLocation!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF592941),
                        ),
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
                        backgroundColor: const Color(0xFFD6D5C9),
                        foregroundColor: const Color(0xFF592941),
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
