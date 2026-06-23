import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:nrmflutter/config/geoserver_config.dart';
import 'package:nrmflutter/config/odk_urls.dart';
import 'package:nrmflutter/ui/home/odk_form_placeholder.dart';
import 'package:nrmflutter/ui/home/widgets/base_map.dart';

// ---------------------------------------------------------------------------
// Resource type
// ---------------------------------------------------------------------------

enum _ResourceType {
  settlement,
  well,
  waterStructure,
  cropping;

  String get label {
    switch (this) {
      case settlement:   return 'Settlements';
      case well:         return 'Wells';
      case waterStructure: return 'Water Structures';
      case cropping:     return 'Cropping';
    }
  }

  String get singular {
    switch (this) {
      case settlement:   return 'Settlement';
      case well:         return 'Well';
      case waterStructure: return 'Water Structure';
      case cropping:     return 'Cropping Pattern';
    }
  }

  IconData get icon {
    switch (this) {
      case settlement:   return Icons.house_rounded;
      case well:         return Icons.water_drop;
      case waterStructure: return Icons.water;
      case cropping:     return Icons.grass;
    }
  }

  Color get color {
    switch (this) {
      case settlement:   return const Color(0xFF592941);
      case well:         return const Color(0xFF1565C0);
      case waterStructure: return const Color(0xFF00838F);
      case cropping:     return const Color(0xFF2E7D32);
    }
  }

  GeoServerLayer get layer {
    switch (this) {
      case settlement:   return GeoServerRegistry.settlement;
      case well:         return GeoServerRegistry.planWell;
      case waterStructure: return GeoServerRegistry.planWaterbody;
      case cropping:     return GeoServerRegistry.planCropping;
    }
  }

  /// Resource type string expected by the add_resources API.
  String get apiResourceType {
    switch (this) {
      case settlement:   return OdkResourceType.settlement;
      case well:         return OdkResourceType.well;
      case waterStructure: return OdkResourceType.waterStructure;
      case cropping:     return OdkResourceType.cropping;
    }
  }
}

// ---------------------------------------------------------------------------
// Feature model
// ---------------------------------------------------------------------------

class _ResourceFeature {
  final _ResourceType type;
  final String name;
  final LatLng position;
  final Map<String, dynamic> properties;
  final List<List<LatLng>> rings;

  const _ResourceFeature({
    required this.type,
    required this.name,
    required this.position,
    required this.properties,
    this.rings = const [],
  });

  String get id =>
      (properties['id'] ?? properties['hamlet_id'] ?? properties['gid'] ?? '')
          .toString();
}

// ---------------------------------------------------------------------------
// Session context — active "add settlement → add resources" loop
// ---------------------------------------------------------------------------

class _SessionContext {
  final LatLng settlementPos;
  final String settlementId;
  final String settlementName;

  const _SessionContext({
    required this.settlementPos,
    this.settlementId = '',
    this.settlementName = 'New Settlement',
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResourceMappingScreen extends StatefulWidget {
  final String state;
  final String district;
  final String block;
  final String blockId;
  final String geoserverUrl;
  final String planId;
  final String planName;

  const ResourceMappingScreen({
    super.key,
    required this.state,
    required this.district,
    required this.block,
    required this.blockId,
    required this.geoserverUrl,
    required this.planId,
    required this.planName,
  });

  @override
  State<ResourceMappingScreen> createState() => _ResourceMappingScreenState();
}

class _ResourceMappingScreenState extends State<ResourceMappingScreen> {
  final MapController _mapController = MapController();

  bool _isLoading = true;
  String? _loadError;

  List<Polygon> _adminPolygons = [];
  bool _adminVisible = true;

  final Map<_ResourceType, List<_ResourceFeature>> _features = {
    for (final t in _ResourceType.values) t: [],
  };
  final Map<_ResourceType, bool> _visible = {
    for (final t in _ResourceType.values) t: true,
  };

  // Marker placement state
  LatLng? _placedMarker;
  // null = placing settlement; non-null = placing that resource type (during session)
  _ResourceType? _pendingType;

  // Active settlement session (after adding a new settlement)
  _SessionContext? _session;

  // User GPS position for ODK prefill
  LatLng? _userPosition;

  // Layer legend expanded
  bool _showLegend = false;

  @override
  void initState() {
    super.initState();
    _loadLayers();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadLayers() async {
    setState(() { _isLoading = true; _loadError = null; });

    try {
      final ctx = GeoServerContext(rawDistrict: widget.district, rawBlock: widget.block);

      final results = await Future.wait([
        _fetchAdminBoundaries(ctx),
        ..._ResourceType.values.map((t) => _fetchResourceLayer(t)),
      ]);

      if (!mounted) return;

      final adminPolygons = results[0] as List<Polygon>;
      final features = <_ResourceType, List<_ResourceFeature>>{
        for (var i = 0; i < _ResourceType.values.length; i++)
          _ResourceType.values[i]: results[i + 1] as List<_ResourceFeature>,
      };

      setState(() {
        _adminPolygons = adminPolygons;
        for (final t in _ResourceType.values) { _features[t] = features[t]!; }
        _isLoading = false;
      });

      final pts = features[_ResourceType.settlement]?.map((f) => f.position).toList() ?? [];
      if (pts.isNotEmpty) {
        _fitBounds(pts);
      } else if (adminPolygons.isNotEmpty) {
        _fitBounds(adminPolygons.expand((p) => p.points).toList());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _loadError = e.toString(); });
    }
  }

  Future<List<Polygon>> _fetchAdminBoundaries(GeoServerContext ctx) async {
    final url = GeoServerRegistry.panchayatBoundaryWfsUrl(widget.geoserverUrl, ctx);
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return [];

    final geojson = jsonDecode(res.body) as Map<String, dynamic>;
    final polygons = <Polygon>[];
    for (final f in (geojson['features'] as List? ?? [])) {
      for (final ring in _rings(f['geometry'] as Map<String, dynamic>? ?? {})) {
        polygons.add(Polygon(
          points: ring,
          color: Colors.transparent,
          borderColor: Colors.black,
          borderStrokeWidth: 2.0,
        ));
      }
    }
    return polygons;
  }

  Future<List<_ResourceFeature>> _fetchResourceLayer(_ResourceType type) async {
    final planCtx = GeoServerContext(
      rawDistrict: widget.district, rawBlock: widget.block, planId: widget.planId);
    final url = type.layer.wfsUrl(widget.geoserverUrl, planCtx);
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return [];

    final geojson = jsonDecode(res.body) as Map<String, dynamic>;
    final features = <_ResourceFeature>[];

    for (final f in (geojson['features'] as List? ?? [])) {
      final geo = f['geometry'] as Map<String, dynamic>?;
      if (geo == null) continue;
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final rings = _rings(geo);
      LatLng pos;

      if (geo['type'] == 'Point') {
        final c = geo['coordinates'] as List;
        pos = LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
      } else if (rings.isNotEmpty) {
        pos = _centroid(rings.first);
      } else {
        continue;
      }

      features.add(_ResourceFeature(
        type: type,
        name: _featureName(type, props),
        position: pos,
        properties: props,
        rings: rings,
      ));
    }
    return features;
  }

  String _featureName(_ResourceType type, Map<String, dynamic> props) {
    switch (type) {
      case _ResourceType.settlement:
        return (props['settlement_name'] ?? props['name'] ?? props['vill_name'] ?? 'Settlement').toString();
      case _ResourceType.well:
        return (props['well_name'] ?? props['name'] ?? 'Well').toString();
      case _ResourceType.waterStructure:
        return (props['structure_name'] ?? props['name'] ?? 'Water Structure').toString();
      case _ResourceType.cropping:
        return (props['crop_name'] ?? props['crop_type'] ?? props['name'] ?? 'Cropping').toString();
    }
  }

  // ---------------------------------------------------------------------------
  // Geometry helpers
  // ---------------------------------------------------------------------------

  List<List<LatLng>> _rings(Map<String, dynamic> geo) {
    final type = geo['type'] as String? ?? '';
    final coords = geo['coordinates'];
    final out = <List<LatLng>>[];
    if (type == 'Polygon' && coords != null) {
      out.add(_lls(coords[0] as List));
    } else if (type == 'MultiPolygon' && coords != null) {
      for (final poly in (coords as List)) { out.add(_lls((poly as List)[0] as List)); }
    }
    return out;
  }

  List<LatLng> _lls(List c) =>
      c.map<LatLng>((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())).toList();

  LatLng _centroid(List<LatLng> pts) {
    double lat = 0, lng = 0;
    for (final p in pts) { lat += p.latitude; lng += p.longitude; }
    return LatLng(lat / pts.length, lng / pts.length);
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final diff = math.max(maxLat - minLat, maxLng - minLng);
    final zoom = diff < 0.02 ? 15.0 : diff < 0.05 ? 14.0 : diff < 0.15 ? 13.0 : 12.0;
    _mapController.move(center, zoom);
  }

  // ---------------------------------------------------------------------------
  // Interaction
  // ---------------------------------------------------------------------------

  void _onMapTap(TapPosition _, LatLng pos) {
    // Ignore taps while a pin is already placed (user must confirm/dismiss first)
    if (_placedMarker != null) return;
    // If session is active but no pending type, ignore raw map taps
    if (_session != null && _pendingType == null) return;
    HapticFeedback.lightImpact();
    setState(() => _placedMarker = pos);
  }

  void _confirmPlacedMarker() {
    final pos = _placedMarker!;
    final type = _pendingType;
    setState(() { _placedMarker = null; _pendingType = null; });

    if (type == null) {
      // Adding a new settlement
      final url = OdkUrls.settlement(
        marker: pos,
        block: widget.block,
        planId: widget.planId,
        planName: widget.planName,
        userPos: _userPosition,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OdkFormScreen(
            url: url,
            title: 'Add Settlement',
            resourceType: OdkResourceType.settlement,
            planId: widget.planId,
            planName: widget.planName,
            district: widget.district,
            block: widget.block,
          ),
        ),
      ).then((_) {
        if (!mounted) return;
        // Enter resource-adding session, then reload layers so new settlement appears
        setState(() {
          _session = _SessionContext(
            settlementPos: pos,
            settlementId: '',
            settlementName: 'Settlement at ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
          );
        });
        _loadLayers();
      });
    } else {
      // Adding a resource (well / water / crop) in session
      final session = _session!;
      final url = _buildResourceUrl(type, pos, session);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OdkFormScreen(
            url: url,
            title: 'Add ${type.singular}',
            resourceType: type.apiResourceType,
            planId: widget.planId,
            planName: widget.planName,
            district: widget.district,
            block: widget.block,
          ),
        ),
      ).then((_) {
        if (mounted) _loadLayers();
      });
    }
  }

  void _dismissMarker() {
    setState(() { _placedMarker = null; _pendingType = null; });
  }

  void _onFeatureTapped(_ResourceFeature f) {
    if (f.type == _ResourceType.settlement) {
      _showSettlementSheet(f);
    } else {
      _showFeatureSheet(f);
    }
  }

  void _showSettlementSheet(_ResourceFeature f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettlementSheet(
        feature: f,
        block: widget.block,
        district: widget.district,
        planId: widget.planId,
        planName: widget.planName,
        userPos: _userPosition,
      ),
    );
  }

  void _showFeatureSheet(_ResourceFeature f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeatureSheet(
        feature: f,
        block: widget.block,
        district: widget.district,
        planId: widget.planId,
        planName: widget.planName,
        userPos: _userPosition,
      ),
    );
  }

  String _buildResourceUrl(_ResourceType type, LatLng pos, _SessionContext session) {
    switch (type) {
      case _ResourceType.well:
        return OdkUrls.well(
          marker: pos, block: widget.block,
          planId: widget.planId, planName: widget.planName,
          settlementId: session.settlementId,
          settlementName: session.settlementName,
          userPos: _userPosition,
        );
      case _ResourceType.waterStructure:
        return OdkUrls.waterStructure(
          marker: pos, block: widget.block,
          planId: widget.planId, planName: widget.planName,
          settlementId: session.settlementId,
          settlementName: session.settlementName,
          userPos: _userPosition,
        );
      case _ResourceType.cropping:
        return OdkUrls.cropping(
          marker: pos, block: widget.block,
          planId: widget.planId, planName: widget.planName,
          settlementId: session.settlementId,
          settlementName: session.settlementName,
          userPos: _userPosition,
        );
      default:
        return '';
    }
  }

  // ---------------------------------------------------------------------------
  // Map layers
  // ---------------------------------------------------------------------------

  List<Polygon> get _resourcePolygons {
    final out = <Polygon>[];
    for (final type in _ResourceType.values) {
      if (!(_visible[type] ?? true)) continue;
      for (final f in (_features[type] ?? [])) {
        for (final ring in f.rings) {
          out.add(Polygon(
            points: ring,
            color: type.color.withValues(alpha: 0.15),
            borderColor: type.color,
            borderStrokeWidth: 2.0,
          ));
        }
      }
    }
    return out;
  }

  List<Marker> get _allMarkers {
    final out = <Marker>[];

    // Placed pin
    if (_placedMarker != null) {
      out.add(Marker(
        point: _placedMarker!,
        width: 40,
        height: 52,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: _confirmPlacedMarker,
          child: Icon(
            Icons.location_on,
            size: 52,
            color: const Color(0xFFD32F2F),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ));
    }

    // Session settlement ghost pin
    if (_session != null) {
      out.add(Marker(
        point: _session!.settlementPos,
        width: 36,
        height: 46,
        alignment: Alignment.bottomCenter,
        child: Icon(
          Icons.location_on,
          size: 46,
          color: const Color(0xFF592941).withValues(alpha: 0.6),
        ),
      ));
    }

    // Resource feature markers — all circles same size (44×44)
    const iconSize = 44.0;
    const iconInner = 22.0;
    for (final type in _ResourceType.values) {
      if (!(_visible[type] ?? true)) continue;
      for (final f in (_features[type] ?? [])) {
        final isSettlement = type == _ResourceType.settlement;
        // Settlement gets an extra name label below → taller widget
        final markerHeight = isSettlement ? 64.0 : iconSize;
        // Anchor: for settlement (icon + label), place anchor at center of icon
        // icon center is at y=22 from top of a 64-tall widget
        // normalized: (22 - 32) / 32 = -0.3125
        final alignment = isSettlement ? const Alignment(0, -0.31) : Alignment.center;

        final iconWidget = Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: type.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: type.color.withValues(alpha: 0.45),
                blurRadius: 8,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(type.icon, size: iconInner, color: Colors.white),
        );

        out.add(Marker(
          point: f.position,
          width: isSettlement ? 90.0 : iconSize,
          height: markerHeight,
          alignment: alignment,
          child: GestureDetector(
            onTap: () => _onFeatureTapped(f),
            child: isSettlement
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          f.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : iconWidget,
          ),
        ));
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final sessionBarH = _session != null ? 110.0 : 0.0;

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
          child: _GlassTitle(
            title: 'Resource Mapping',
            subtitle: widget.planName.isNotEmpty ? widget.planName : null,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _loadLayers,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          BaseMap(
            controller: _mapController,
            polygons: [
              if (_adminVisible) ..._adminPolygons,
              ..._resourcePolygons,
            ],
            markers: _allMarkers,
            onTap: _onMapTap,
            onUserPositionChanged: (pos) => _userPosition = pos,
          ),

          if (_isLoading) _LoadingOverlay(),

          if (_loadError != null)
            _ErrorBanner(error: _loadError!, onRetry: _loadLayers),

          // Layer info bar
          if (!_isLoading)
            Positioned(
              top: topPadding + 70,
              left: 16,
              child: _LayerInfoBar(
                adminVisible: _adminVisible,
                onToggleAdmin: () => setState(() => _adminVisible = !_adminVisible),
                visible: _visible,
                counts: {for (final t in _ResourceType.values) t: _features[t]?.length ?? 0},
                onToggle: (t) => setState(() => _visible[t] = !(_visible[t] ?? true)),
                expanded: _showLegend,
                onToggleExpand: () => setState(() => _showLegend = !_showLegend),
              ),
            ),

          // Placement hint — shown when a resource type is pending but no marker yet
          if (_pendingType != null && _placedMarker == null)
            Positioned(
              top: topPadding + 70,
              left: 0,
              right: 0,
              child: Center(
                child: _PlacementHintChip(type: _pendingType!,
                  onCancel: () => setState(() => _pendingType = null)),
              ),
            ),

          // Marker chips — shown when a pin is placed
          if (_placedMarker != null)
            Positioned(
              bottom: bottomPadding + sessionBarH + 24,
              left: 0,
              right: 0,
              child: Center(
                child: _MarkerActionCard(
                  position: _placedMarker!,
                  type: _pendingType,
                  onConfirm: _confirmPlacedMarker,
                  onDismiss: _dismissMarker,
                ),
              ),
            ),

          // Session bar — persistent bottom bar during resource-adding loop
          if (_session != null && _placedMarker == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _SessionBar(
                session: _session!,
                pendingType: _pendingType,
                onAdd: (type) => setState(() { _pendingType = type; }),
                onDone: () => setState(() { _session = null; _pendingType = null; }),
                bottomPadding: bottomPadding,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass AppBar title
// ---------------------------------------------------------------------------

class _GlassTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _GlassTitle({required this.title, this.subtitle});

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
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
          ),
          child: subtitle != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(subtitle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w400),
                        overflow: TextOverflow.ellipsis),
                  ],
                )
              : Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layer info bar
// ---------------------------------------------------------------------------

class _LayerInfoBar extends StatelessWidget {
  final bool adminVisible;
  final VoidCallback onToggleAdmin;
  final Map<_ResourceType, bool> visible;
  final Map<_ResourceType, int> counts;
  final ValueChanged<_ResourceType> onToggle;
  final bool expanded;
  final VoidCallback onToggleExpand;

  const _LayerInfoBar({
    required this.adminVisible, required this.onToggleAdmin,
    required this.visible, required this.counts, required this.onToggle,
    required this.expanded, required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onToggleExpand,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text('$total features',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    Icon(expanded ? Icons.expand_less : Icons.info_outline,
                        color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 5),
          _LegendChip(label: 'Admin Boundaries', color: Colors.black,
              isSquare: true, on: adminVisible, onTap: onToggleAdmin),
          ..._ResourceType.values.map((t) => _LegendChip(
                label: '${t.label} (${counts[t] ?? 0})',
                color: t.color, isSquare: false,
                on: visible[t] ?? true,
                onTap: () => onToggle(t),
              )),
        ],
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSquare;
  final bool on;
  final VoidCallback onTap;
  const _LegendChip({required this.label, required this.color,
      required this.isSquare, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? Colors.black.withValues(alpha: 0.75) : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isSquare
                ? Container(
                    width: 14, height: 10,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: on ? color : Colors.grey, width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ))
                : Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: on ? color : Colors.grey, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: on ? Colors.white : Colors.white54,
                    fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placement hint chip
// ---------------------------------------------------------------------------

class _PlacementHintChip extends StatelessWidget {
  final _ResourceType type;
  final VoidCallback onCancel;
  const _PlacementHintChip({required this.type, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: type.color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('Tap map to place ${type.singular}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.close, color: Colors.white70, size: 16),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Marker chips — glass lat/lon chip + glass action chip
// ---------------------------------------------------------------------------

class _MarkerActionCard extends StatelessWidget {
  final LatLng position;
  final _ResourceType? type;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;
  const _MarkerActionCard({required this.position, required this.type,
      required this.onConfirm, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final label = type == null ? 'Add Settlement' : 'Add ${type!.singular}';
    final icon = type?.icon ?? Icons.house_rounded;
    final lat = position.latitude.toStringAsFixed(5);
    final lon = position.longitude.toStringAsFixed(5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lat / lon chip
        _GlassChip(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_pin, color: Color(0xFFD32F2F), size: 13),
              const SizedBox(width: 5),
              Text('$lat, $lon',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace')),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Action chip — tapping opens ODK form directly
        GestureDetector(
          onTap: onConfirm,
          child: _GlassChip(
            highlighted: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Dismiss chip
        GestureDetector(
          onTap: onDismiss,
          child: _GlassChip(
            child: const Icon(Icons.close, color: Colors.white70, size: 14),
          ),
        ),
      ],
    );
  }
}

class _GlassChip extends StatelessWidget {
  final Widget child;
  final bool highlighted;
  const _GlassChip({required this.child, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlighted
                  ? [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.75),
                    ]
                  : [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.50),
                    ],
            ),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.12),
              width: highlighted ? 1 : 0.5,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session bar — persistent bottom bar during settlement resource loop
// ---------------------------------------------------------------------------

class _SessionBar extends StatelessWidget {
  final _SessionContext session;
  final _ResourceType? pendingType;
  final ValueChanged<_ResourceType> onAdd;
  final VoidCallback onDone;
  final double bottomPadding;

  const _SessionBar({
    required this.session, required this.pendingType,
    required this.onAdd, required this.onDone, required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF592941),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.house_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.settlementName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onDone,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Done', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QuickAddBtn(
                icon: Icons.water_drop,
                label: 'Well',
                active: pendingType == _ResourceType.well,
                onTap: () => onAdd(_ResourceType.well),
              ),
              const SizedBox(width: 8),
              _QuickAddBtn(
                icon: Icons.water,
                label: 'Water',
                active: pendingType == _ResourceType.waterStructure,
                onTap: () => onAdd(_ResourceType.waterStructure),
              ),
              const SizedBox(width: 8),
              _QuickAddBtn(
                icon: Icons.grass,
                label: 'Crop',
                active: pendingType == _ResourceType.cropping,
                onTap: () => onAdd(_ResourceType.cropping),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAddBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _QuickAddBtn({required this.icon, required this.label,
      required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settlement action sheet (existing settlement tapped)
// ---------------------------------------------------------------------------

class _SettlementSheet extends StatelessWidget {
  final _ResourceFeature feature;
  final String block;
  final String district;
  final String planId;
  final String planName;
  final LatLng? userPos;
  const _SettlementSheet({required this.feature, required this.block,
      required this.district, required this.planId, required this.planName,
      this.userPos});

  void _openForm(BuildContext ctx, _ResourceType type) {
    final url = _url(type);
    Navigator.pop(ctx);
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => OdkFormScreen(
        url: url,
        title: 'Add ${type.singular}',
        resourceType: type.apiResourceType,
        planId: planId,
        planName: planName,
        district: district,
        block: block,
      ),
    ));
  }

  String _url(_ResourceType type) {
    switch (type) {
      case _ResourceType.well:
        return OdkUrls.well(marker: feature.position, block: block,
            planId: planId, planName: planName,
            settlementId: feature.id, settlementName: feature.name, userPos: userPos);
      case _ResourceType.waterStructure:
        return OdkUrls.waterStructure(marker: feature.position, block: block,
            planId: planId, planName: planName,
            settlementId: feature.id, settlementName: feature.name, userPos: userPos);
      case _ResourceType.cropping:
        return OdkUrls.cropping(marker: feature.position, block: block,
            planId: planId, planName: planName,
            settlementId: feature.id, settlementName: feature.name, userPos: userPos);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: bottomPadding + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          _FeatureHeader(feature: feature),
          _SectionLabel('MARK RESOURCES'),
          _SheetAction(icon: Icons.water_drop, color: const Color(0xFF1565C0),
              label: 'Add Well', onTap: () => _openForm(context, _ResourceType.well)),
          _SheetAction(icon: Icons.water, color: const Color(0xFF00838F),
              label: 'Add Water Structure', onTap: () => _openForm(context, _ResourceType.waterStructure)),
          _SheetAction(icon: Icons.grass, color: const Color(0xFF2E7D32),
              label: 'Add Cropping Pattern', onTap: () => _openForm(context, _ResourceType.cropping)),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _SectionLabel('INFORMATION'),
          _SheetAction(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF592941),
            label: 'Resource Info',
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _InfoSheet(feature: feature),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Non-settlement feature sheet
// ---------------------------------------------------------------------------

class _FeatureSheet extends StatelessWidget {
  final _ResourceFeature feature;
  final String block;
  final String district;
  final String planId;
  final String planName;
  final LatLng? userPos;
  const _FeatureSheet({required this.feature, required this.block,
      required this.district, required this.planId, required this.planName,
      this.userPos});

  String get _addUrl {
    switch (feature.type) {
      case _ResourceType.well:
        return OdkUrls.well(marker: feature.position, block: block,
            planId: planId, planName: planName,
            settlementId: feature.id, settlementName: feature.name, userPos: userPos);
      case _ResourceType.waterStructure:
        return OdkUrls.waterStructure(marker: feature.position, block: block,
            planId: planId, planName: planName,
            settlementId: feature.id, settlementName: feature.name, userPos: userPos);
      case _ResourceType.cropping:
        return OdkUrls.cropping(marker: feature.position, block: block,
            planId: planId, planName: planName,
            settlementId: feature.id, settlementName: feature.name,
            cropId: feature.properties['crop_Grid_id']?.toString() ?? '',
            userPos: userPos);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: bottomPadding + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          _FeatureHeader(feature: feature),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _SheetAction(
            icon: Icons.edit_location_alt_outlined,
            color: feature.type.color,
            label: 'Add ${feature.type.singular}',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => OdkFormScreen(
                  url: _addUrl,
                  title: 'Add ${feature.type.singular}',
                  resourceType: feature.type.apiResourceType,
                  planId: planId,
                  planName: planName,
                  district: district,
                  block: block,
                ),
              ));
            },
          ),
          _SheetAction(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF592941),
            label: 'Resource Info',
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _InfoSheet(feature: feature),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resource info sheet
// ---------------------------------------------------------------------------

class _InfoSheet extends StatelessWidget {
  final _ResourceFeature feature;
  const _InfoSheet({required this.feature});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final entries = feature.properties.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          _FeatureHeader(feature: feature, showClose: true),
          const Divider(height: 1),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No attributes available.', style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.only(bottom: bottomPadding + 16, top: 4),
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, indent: 20, endIndent: 20, color: Colors.grey.shade100),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(entries[i].key.replaceAll('_', ' '),
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(entries[i].value.toString(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.end),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sheet sub-widgets
// ---------------------------------------------------------------------------

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }
}

class _FeatureHeader extends StatelessWidget {
  final _ResourceFeature feature;
  final bool showClose;
  const _FeatureHeader({required this.feature, this.showClose = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: feature.type.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.type.icon, color: feature.type.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.name,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: feature.type.color),
                    overflow: TextOverflow.ellipsis),
                Text(feature.type.singular,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (showClose)
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF592941)),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: Colors.grey.shade500, letterSpacing: 0.8)),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _SheetAction({required this.icon, required this.color,
      required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay widgets
// ---------------------------------------------------------------------------

class _LoadingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.2),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF592941))),
                SizedBox(width: 12),
                Text('Loading layers…',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF592941))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text('Failed to load layers',
                style: TextStyle(fontSize: 13, color: Colors.red))),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(color: Color(0xFF592941))),
            ),
          ],
        ),
      ),
    );
  }
}
