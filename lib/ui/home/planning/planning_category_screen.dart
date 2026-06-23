import 'package:flutter/material.dart';
import 'package:nrmflutter/config/geoserver_config.dart';
import 'package:nrmflutter/utils/geoserver_layer_renderer.dart';

/// Shared layer-list view used by every planning category subtab.
class PlanningCategoryScreen extends StatefulWidget {
  final PlanningCategory category;
  final String categoryTitle;
  final String district;
  final String block;
  final String blockId;
  final String geoserverUrl;

  const PlanningCategoryScreen({
    super.key,
    required this.category,
    required this.categoryTitle,
    required this.district,
    required this.block,
    required this.blockId,
    required this.geoserverUrl,
  });

  @override
  State<PlanningCategoryScreen> createState() => _PlanningCategoryScreenState();
}

class _PlanningCategoryScreenState extends State<PlanningCategoryScreen> {
  late final List<GeoServerLayer> _layers;
  final Map<String, bool> _enabled = {};
  final Map<String, _LayerLoadState> _states = {};

  @override
  void initState() {
    super.initState();
    _layers = GeoServerRegistry.layersForCategory(widget.category);
    for (final l in _layers) {
      _enabled[l.id] = false;
      _states[l.id] = _LayerLoadState.idle;
    }
  }

  Future<void> _toggle(GeoServerLayer layer) async {
    final nowEnabled = !(_enabled[layer.id] ?? false);
    setState(() {
      _enabled[layer.id] = nowEnabled;
      if (nowEnabled) _states[layer.id] = _LayerLoadState.loading;
    });

    if (!nowEnabled) return;

    try {
      final ctx = GeoServerContext(
        rawDistrict: widget.district,
        rawBlock: widget.block,
      );
      if (layer.kind == GeoServerLayerKind.raster) {
        // Raster: just mark ready (WMS tile layer rendered inline on the map)
        setState(() => _states[layer.id] = _LayerLoadState.ready);
      } else {
        await GeoServerLayerRenderer.fetchAndRender(
            layer, ctx, widget.geoserverUrl);
        setState(() => _states[layer.id] = _LayerLoadState.ready);
      }
    } catch (_) {
      setState(() {
        _enabled[layer.id] = false;
        _states[layer.id] = _LayerLoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_layers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No layers configured for this category.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _layers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _LayerRow(
        layer: _layers[i],
        enabled: _enabled[_layers[i].id] ?? false,
        state: _states[_layers[i].id] ?? _LayerLoadState.idle,
        onToggle: () => _toggle(_layers[i]),
      ),
    );
  }
}

enum _LayerLoadState { idle, loading, ready, error }

class _LayerRow extends StatelessWidget {
  final GeoServerLayer layer;
  final bool enabled;
  final _LayerLoadState state;
  final VoidCallback onToggle;

  const _LayerRow({
    required this.layer,
    required this.enabled,
    required this.state,
    required this.onToggle,
  });

  IconData get _kindIcon {
    switch (layer.kind) {
      case GeoServerLayerKind.point:
        return Icons.place_outlined;
      case GeoServerLayerKind.vector:
        return Icons.polyline_outlined;
      case GeoServerLayerKind.raster:
        return Icons.layers_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFF3E5F5)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _kindIcon,
                size: 18,
                color: enabled
                    ? const Color(0xFF592941)
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                layer.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      enabled ? FontWeight.w600 : FontWeight.w500,
                  color: enabled
                      ? const Color(0xFF592941)
                      : Colors.black87,
                ),
              ),
            ),
            if (state == _LayerLoadState.loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF592941),
                ),
              )
            else if (state == _LayerLoadState.error)
              const Icon(Icons.error_outline, color: Colors.red, size: 18)
            else
              Switch(
                value: enabled,
                onChanged: (_) => onToggle(),
                activeThumbColor: const Color(0xFF592941),
                activeTrackColor: const Color(0xFFD6D5C9),
              ),
          ],
        ),
      ),
    );
  }
}
