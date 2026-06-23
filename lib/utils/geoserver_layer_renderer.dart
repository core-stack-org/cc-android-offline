import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:nrmflutter/config/geoserver_config.dart';

class RenderedVectorLayer {
  final GeoServerLayer layer;
  final List<Polygon> polygons;
  final List<Marker> markers;

  const RenderedVectorLayer({
    required this.layer,
    required this.polygons,
    required this.markers,
  });
}

class GeoServerLayerRenderer {
  static Future<RenderedVectorLayer> fetchAndRender(
    GeoServerLayer layer,
    GeoServerContext ctx,
    String geoserverBaseUrl, {
    Color polygonFill = const Color(0x1A2196F3),
    Color polygonBorder = const Color(0xFF2196F3),
    double borderWidth = 1.5,
    Color markerColor = const Color(0xFF592941),
  }) async {
    final url = layer.wfsUrl(geoserverBaseUrl, ctx);
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
          'GeoServer WFS error ${response.statusCode} for ${layer.displayName}');
    }

    final geojson = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (geojson['features'] as List? ?? []);

    final polygons = <Polygon>[];
    final markers = <Marker>[];

    for (final feature in features) {
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) continue;
      final type = geometry['type'] as String;
      final coords = geometry['coordinates'];

      if (type == 'Point') {
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        markers.add(_buildMarker(LatLng(lat, lng), markerColor,
            feature['properties'] as Map<String, dynamic>?));
      } else if (type == 'MultiPoint') {
        for (final pt in (coords as List)) {
          final lng = (pt[0] as num).toDouble();
          final lat = (pt[1] as num).toDouble();
          markers.add(_buildMarker(LatLng(lat, lng), markerColor,
              feature['properties'] as Map<String, dynamic>?));
        }
      } else if (type == 'Polygon') {
        final ring = _toLatLngs(coords[0] as List);
        polygons.add(Polygon(
          points: ring,
          color: polygonFill,
          borderColor: polygonBorder,
          borderStrokeWidth: borderWidth,
        ));
      } else if (type == 'MultiPolygon') {
        for (final poly in (coords as List)) {
          final ring = _toLatLngs((poly as List)[0] as List);
          polygons.add(Polygon(
            points: ring,
            color: polygonFill,
            borderColor: polygonBorder,
            borderStrokeWidth: borderWidth,
          ));
        }
      } else if (type == 'LineString') {
        // Render lines as thin polygons (1px) or ignore if not needed
      } else if (type == 'MultiLineString') {
        // same
      }
    }

    return RenderedVectorLayer(layer: layer, polygons: polygons, markers: markers);
  }

  static List<LatLng> _toLatLngs(List coords) {
    return coords.map<LatLng>((c) {
      final lng = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      return LatLng(lat, lng);
    }).toList();
  }

  static Marker _buildMarker(
      LatLng pos, Color color, Map<String, dynamic>? properties) {
    return Marker(
      point: pos,
      width: 28,
      height: 28,
      child: GestureDetector(
        child: Icon(Icons.location_on, color: color, size: 28),
      ),
    );
  }

  /// Build a WMS TileLayer for a raster GeoServerLayer.
  static TileLayer wmsRasterLayer(
      GeoServerLayer layer, GeoServerContext ctx, String geoserverBaseUrl) {
    assert(layer.kind == GeoServerLayerKind.raster);
    final baseUrl = layer.wmsBaseUrl(geoserverBaseUrl);
    return TileLayer(
      wmsOptions: WMSTileLayerOptions(
        baseUrl: baseUrl,
        layers: [layer.typeName(ctx)],
        styles: layer.wmsStyle != null ? [layer.wmsStyle!] : [],
        format: 'image/png',
        version: '1.1.1',
        crs: const Epsg4326(),
        transparent: true,
      ),
    );
  }
}
