import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:nrmflutter/config/geoserver_config.dart';
import 'package:nrmflutter/ui/home/widgets/base_map.dart';
import 'package:nrmflutter/ui/home/widgets/floating_tab_bar.dart';
import 'package:nrmflutter/ui/home/planning_screen.dart';
import 'package:nrmflutter/ui/home/resource_mapping_screen.dart';
import 'package:nrmflutter/ui/home/plan_sheet.dart';
import 'package:nrmflutter/utils/toast.dart';

class HomeScreen extends StatefulWidget {
  final String state;
  final String district;
  final String block;
  final String blockId;
  final String geoserverUrl;
  final String language;

  const HomeScreen({
    super.key,
    required this.state,
    required this.district,
    required this.block,
    required this.blockId,
    required this.geoserverUrl,
    required this.language,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  List<Polygon> _adminPolygons = [];
  int? _selectedPlanId;
  String? _selectedPlanName;

  @override
  void initState() {
    super.initState();
    _loadAdminBoundaries();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminBoundaries() async {
    try {
      final ctx = GeoServerContext(
        rawDistrict: widget.district,
        rawBlock: widget.block,
      );
      final url = GeoServerRegistry.panchayatBoundaryWfsUrl(widget.geoserverUrl, ctx);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 || !mounted) return;

      final geojson = jsonDecode(response.body) as Map<String, dynamic>;
      final features = geojson['features'] as List? ?? [];

      final polygons = <Polygon>[];
      final allPoints = <LatLng>[];

      for (final f in features) {
        final geo = f['geometry'] as Map<String, dynamic>?;
        if (geo == null) continue;
        final rings = _extractRings(geo);
        for (final ring in rings) {
          polygons.add(Polygon(
            points: ring,
            color: Colors.transparent,
            borderColor: Colors.black,
            borderStrokeWidth: 2.0,
          ));
          allPoints.addAll(ring);
        }
      }

      if (!mounted) return;
      setState(() => _adminPolygons = polygons);

      if (allPoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _zoomToPoints(allPoints);
        });
      }
    } catch (_) {}
  }

  List<List<LatLng>> _extractRings(Map<String, dynamic> geo) {
    final type = geo['type'] as String;
    final coords = geo['coordinates'];
    final rings = <List<LatLng>>[];
    if (type == 'Polygon') {
      rings.add(_toLatLngs(coords[0] as List));
    } else if (type == 'MultiPolygon') {
      for (final poly in (coords as List)) {
        rings.add(_toLatLngs((poly as List)[0] as List));
      }
    }
    return rings;
  }

  List<LatLng> _toLatLngs(List coords) => coords
      .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList();

  void _zoomToPoints(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final maxDiff = math.max(maxLat - minLat, maxLng - minLng);
    double zoom = 12.0;
    if (maxDiff < 0.05) { zoom = 14.0; }
    else if (maxDiff < 0.15) { zoom = 13.0; }
    else if (maxDiff < 0.4) { zoom = 11.0; }
    else { zoom = 10.0; }
    _mapController.move(center, zoom);
  }

  void _openSelectPlan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlanSheet(
        blockId: widget.blockId,
        selectedPlanId: _selectedPlanId,
        onPlanSelected: (plan) {
          setState(() {
            _selectedPlanId = plan.id;
            _selectedPlanName = plan.name;
          });
        },
      ),
    );
  }

  void _openResourceMapping() {
    if (_selectedPlanId == null) {
      showTopToast(context, 'Select a plan to start resource mapping');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResourceMappingScreen(
          state: widget.state,
          district: widget.district,
          block: widget.block,
          blockId: widget.blockId,
          geoserverUrl: widget.geoserverUrl,
          planId: _selectedPlanId!.toString(),
          planName: _selectedPlanName ?? '',
          cachedAdminPolygons: _adminPolygons,
        ),
      ),
    );
  }

  void _openPlanning() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanningScreen(
          district: widget.district,
          block: widget.block,
          blockId: widget.blockId,
          geoserverUrl: widget.geoserverUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final hasPlan = _selectedPlanId != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _GlassHeader(block: widget.block, district: widget.district),
        ),
      ),
      body: Stack(
        children: [
          BaseMap(
            controller: _mapController,
            polygons: _adminPolygons,
          ),

          // Select Plan pill — left-aligned, intrinsic width
          Positioned(
            top: topPadding + 56 + 12,
            left: 16,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              child: _SelectPlanPill(
                planName: _selectedPlanName,
                onTap: _openSelectPlan,
              ),
            ),
          ),

          FloatingTabBar(
            hasPlan: hasPlan,
            onResourceMappingTap: _openResourceMapping,
            onPlanningTap: _openPlanning,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass header (AppBar title)
// ---------------------------------------------------------------------------

class _GlassHeader extends StatelessWidget {
  final String block;
  final String district;

  const _GlassHeader({required this.block, required this.district});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.70),
                Colors.black.withValues(alpha: 0.45),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: Text(
            '$block · $district',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Select Plan pill
// ---------------------------------------------------------------------------

class _SelectPlanPill extends StatelessWidget {
  final String? planName;
  final VoidCallback onTap;

  const _SelectPlanPill({required this.planName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasSelection = planName != null;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.92),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasSelection ? Icons.check_circle_outline : Icons.assignment_outlined,
                  color: hasSelection ? const Color(0xFFD6D5C9) : Colors.white70,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    hasSelection ? planName! : 'Select Plan',
                    style: TextStyle(
                      color: hasSelection ? const Color(0xFFD6D5C9) : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
