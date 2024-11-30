import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapLocationSelector extends StatefulWidget {
  final String blockName;
  final String districtName;
  final String geoserverUrl;
  final Function(double lat, double lon) onLocationSelect;

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
  final MapController mapController = MapController();
  LatLng? selectedLocation;
  List<LatLng> boundaryPoints = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBoundaryData();
  }

  Future<void> _fetchBoundaryData() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Select Location'),
        actions: [
          TextButton(
            onPressed: selectedLocation != null
                ? () {
                    widget.onLocationSelect(
                      selectedLocation!.latitude,
                      selectedLocation!.longitude,
                    );
                    Navigator.pop(context);
                  }
                : null,
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(20.5937, 78.9629), // Center of India
              initialZoom: 5.0,
              onTap: (tapPosition, point) {
                setState(() {
                  selectedLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.example.app',
              ),
              if (boundaryPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: boundaryPoints,
                      color: Colors.blue.withOpacity(0.2),
                      borderStrokeWidth: 2,
                      borderColor: Colors.blue,
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
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (selectedLocation != null)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Selected Location: ${selectedLocation!.latitude.toStringAsFixed(4)}, '
                    '${selectedLocation!.longitude.toStringAsFixed(4)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
