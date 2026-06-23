import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nrmflutter/utils/toast.dart';

class BaseMap extends StatefulWidget {
  final MapController? controller;
  final List<Polygon> polygons;
  final List<Marker> markers;
  final List<TileLayer> overlayTileLayers;
  final void Function(TapPosition, LatLng)? onTap;
  final void Function(LatLng position)? onUserPositionChanged;
  final LatLng initialCenter;
  final double initialZoom;

  const BaseMap({
    super.key,
    this.controller,
    this.polygons = const [],
    this.markers = const [],
    this.overlayTileLayers = const [],
    this.onTap,
    this.onUserPositionChanged,
    this.initialCenter = const LatLng(20.5937, 78.9629),
    this.initialZoom = 5.0,
  });

  @override
  State<BaseMap> createState() => _BaseMapState();
}

class _BaseMapState extends State<BaseMap> {
  bool _isSatelliteView = true;
  bool _isLocating = false;
  LatLng? _userPosition;
  double _accuracy = 0;

  Future<void> _locateMe() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) showTopToast(context, 'Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) showTopToast(context, 'Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) showTopToast(context, 'Location permission permanently denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;

      final pos = LatLng(position.latitude, position.longitude);
      setState(() {
        _userPosition = pos;
        _accuracy = position.accuracy;
      });
      widget.controller?.move(pos, 15.0);
      widget.onUserPositionChanged?.call(pos);
    } catch (e) {
      if (mounted) showTopToast(context, 'Could not get location');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: 2.0,
            maxZoom: 18.0,
            onTap: widget.onTap,
          ),
          children: [
            TileLayer(
              urlTemplate: _isSatelliteView
                  ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            ...widget.overlayTileLayers,
            // User accuracy radius
            if (_userPosition != null)
              CircleLayer(circles: [
                CircleMarker(
                  point: _userPosition!,
                  radius: _accuracy.clamp(10, 500),
                  useRadiusInMeter: true,
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderColor: Colors.blue.withValues(alpha: 0.35),
                  borderStrokeWidth: 1.5,
                ),
              ]),
            if (widget.polygons.isNotEmpty)
              PolygonLayer(polygons: widget.polygons),
            if (widget.markers.isNotEmpty)
              MarkerLayer(markers: widget.markers),
            // Blue dot for user position (rendered on top)
            if (_userPosition != null)
              MarkerLayer(markers: [
                Marker(
                  point: _userPosition!,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 120,
          child: _MapControls(
            isSatelliteView: _isSatelliteView,
            isLocating: _isLocating,
            controller: widget.controller,
            onLocateMe: _locateMe,
            onToggleLayer: () =>
                setState(() => _isSatelliteView = !_isSatelliteView),
          ),
        ),
      ],
    );
  }
}

class _MapControls extends StatelessWidget {
  final bool isSatelliteView;
  final bool isLocating;
  final MapController? controller;
  final VoidCallback onLocateMe;
  final VoidCallback onToggleLayer;

  const _MapControls({
    required this.isSatelliteView,
    required this.isLocating,
    required this.controller,
    required this.onLocateMe,
    required this.onToggleLayer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ControlButton(
          icon: Icons.add,
          onTap: () {
            final c = controller;
            if (c != null) c.move(c.camera.center, c.camera.zoom + 1);
          },
        ),
        const SizedBox(height: 8),
        _ControlButton(
          icon: Icons.remove,
          onTap: () {
            final c = controller;
            if (c != null) c.move(c.camera.center, c.camera.zoom - 1);
          },
        ),
        const SizedBox(height: 8),
        _ControlButton(
          icon: isLocating ? Icons.gps_not_fixed : Icons.gps_fixed,
          onTap: onLocateMe,
          isLoading: isLocating,
        ),
        const SizedBox(height: 8),
        _ControlButton(
          icon: isSatelliteView ? Icons.map_outlined : Icons.satellite_alt,
          onTap: onToggleLayer,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
