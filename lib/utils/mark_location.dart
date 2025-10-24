import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:nrmflutter/utils/utility.dart';
//import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../l10n/app_localizations.dart';

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
  bool _isGettingLocation = false;

  List<({String name, List<LatLng> boundary, LatLng center})> villages = [];
  final TextEditingController _searchController = TextEditingController();
  List<({String name, List<LatLng> boundary, LatLng center})>
      _filteredVillages = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    fetchPanchayatBoundary();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredVillages = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _filteredVillages = villages
          .where((village) => village.name.toLowerCase().contains(query))
          .toList();
      _showSearchResults = true;
    });
  }

  void _selectVillage(
      ({String name, List<LatLng> boundary, LatLng center}) village) {
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLon = double.infinity;
    double maxLon = -double.infinity;

    for (var point in village.boundary) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }

    final latDiff = maxLat - minLat;
    final lonDiff = maxLon - minLon;
    final maxDiff = math.max(latDiff, lonDiff);

    double zoom = 13.0;
    if (maxDiff < 0.01) {
      zoom = 15.0;
    } else if (maxDiff < 0.05) {
      zoom = 14.0;
    } else if (maxDiff < 0.1) {
      zoom = 13.0;
    } else {
      zoom = 12.0;
    }

    mapController.move(village.center, zoom);

    setState(() {
      _showSearchResults = false;
      _searchController.clear();
    });
  }

  Future<void> fetchPanchayatBoundary() async {
    final formattedDistrict = formatNameForGeoServer(widget.districtName);
    final formattedBlock = formatNameForGeoServer(widget.blockName);

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
          List<({String name, List<LatLng> boundary, LatLng center})>
              villageList = [];

          for (var feature in geojson['features']) {
            final geometry = feature['geometry'];
            final geomType = geometry['type'];
            final coords = geometry['coordinates'];
            final properties = feature['properties'];
            final villageName =
                properties?['vill_name']?.toString() ?? 'Unknown';

            List<LatLng> currentPolygonPoints = [];

            if (geomType == 'Polygon') {
              for (var coord in coords[0]) {
                currentPolygonPoints
                    .add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
              }
              polygonsFromAllFeatures.add(currentPolygonPoints);
            } else if (geomType == 'MultiPolygon') {
              for (var polygon in coords) {
                List<LatLng> polygonPoints = [];
                for (var ring in polygon) {
                  for (var coord in ring) {
                    polygonPoints
                        .add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
                    currentPolygonPoints
                        .add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
                  }
                }
                polygonsFromAllFeatures.add(polygonPoints);
              }
            }

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

            if (pointCount > 0 && currentPolygonPoints.isNotEmpty) {
              final center =
                  LatLng(centerLat / pointCount, centerLon / pointCount);
              villageList.add((
                name: villageName,
                boundary: currentPolygonPoints,
                center: center,
              ));
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
            villages = villageList;
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
          title: Text(AppLocalizations.of(context)!.enterCoordinates),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: latController,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.latitude),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!.pleaseEnterLatitude;
                    }
                    final lat = double.tryParse(value);
                    if (lat == null) {
                      return AppLocalizations.of(context)!
                          .pleaseEnterValidNumber;
                    }
                    if (lat < -90 || lat > 90) {
                      return AppLocalizations.of(context)!
                          .latitudeMustBeBetween;
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: lonController,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.longitude),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!.pleaseEnterLongitude;
                    }
                    final lon = double.tryParse(value);
                    if (lon == null) {
                      return AppLocalizations.of(context)!
                          .pleaseEnterValidNumber;
                    }
                    if (lon < -180 || lon > 180) {
                      return AppLocalizations.of(context)!
                          .longitudeMustBeBetween;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(AppLocalizations.of(context)!.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context)!.done),
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

  /// Gets the user's current location and moves the map to that position
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.locationServicesDisabled)),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.locationPermissionsDenied)),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .locationPermissionsPermanentlyDenied)),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentLocation = LatLng(position.latitude, position.longitude);
      const newZoom = 15.0;

      // Animate map movement and update state afterward
      await mapController.move(currentLocation, newZoom);

      if (mounted) {
        setState(() {
          selectedLocation = currentLocation;
          _currentZoom = newZoom;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.movedToCurrentLocation)),
        );
      }
    } catch (e) {
      print('Error getting current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context)!.placeYourMarker,
          style: const TextStyle(
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
              PopupMenuItem<String>(
                value: 'add_lat_lon',
                child: Text(AppLocalizations.of(context)!.addLatLon),
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
          Positioned(
            left: 16,
            top: 16,
            right: 80,
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search village...',
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF592941)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Color(0xFF592941)),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (_showSearchResults && _filteredVillages.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 200),
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
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredVillages.length,
                        itemBuilder: (context, index) {
                          final village = _filteredVillages[index];
                          return ListTile(
                            title: Text(
                              village.name,
                              style: const TextStyle(
                                color: Color(0xFF592941),
                                fontSize: 14,
                              ),
                            ),
                            onTap: () => _selectVillage(village),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Zoom controls and layer button
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
                        tooltip: AppLocalizations.of(context)!.zoomIn,
                      ),
                      Container(
                        height: 1,
                        color: const Color(0xFF592941),
                      ),
                      IconButton(
                        icon:
                            Icon(Icons.remove, color: const Color(0xFF592941)),
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
                        tooltip: AppLocalizations.of(context)!.zoomOut,
                      ),
                    ],
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
                  child: IconButton(
                    icon: Icon(Icons.layers, color: const Color(0xFF592941)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text(
                                AppLocalizations.of(context)!.selectMapLayer),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: Text(AppLocalizations.of(context)!
                                      .defaultLayer),
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
                                  title: Text(AppLocalizations.of(context)!
                                      .openStreetMapLayer),
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
                    tooltip: AppLocalizations.of(context)!.changeMapLayer,
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
                  child: IconButton(
                    icon: _isGettingLocation
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF592941),
                              ),
                            ),
                          )
                        : Icon(Icons.my_location,
                            color: const Color(0xFF592941)),
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    tooltip: AppLocalizations.of(context)!.goToCurrentLocation,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${AppLocalizations.of(context)!.latitude}: ${selectedLocation!.latitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF592941),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppLocalizations.of(context)!.longitude}: ${selectedLocation!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF592941),
                            ),
                          ),
                        ],
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
                      child: Text(
                        AppLocalizations.of(context)!.confirm,
                        style: const TextStyle(
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
