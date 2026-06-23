import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:nrmflutter/config/odk_urls.dart';
import 'package:nrmflutter/ui/home/odk_form_placeholder.dart';

/// Bottom sheet shown when an existing settlement is tapped.
/// Provides actions to mark resources (well, water structure, cropping)
/// and view resource info via real ODK/Enketo forms.
class MarkResourcesSheet extends StatelessWidget {
  final String settlement;
  final String settlementId;
  final Map<String, dynamic> settlementProperties;
  final String district;
  final String block;
  final String blockId;
  final String geoserverUrl;
  final String planId;
  final String planName;
  final LatLng markerPosition;
  final LatLng? userPosition;

  const MarkResourcesSheet({
    super.key,
    required this.settlement,
    required this.settlementId,
    required this.settlementProperties,
    required this.district,
    required this.block,
    required this.blockId,
    required this.geoserverUrl,
    required this.planId,
    required this.planName,
    required this.markerPosition,
    this.userPosition,
  });

  void _openForm(BuildContext context, String url, String title, String resourceType) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OdkFormScreen(
          url: url,
          title: title,
          resourceType: resourceType,
          planId: planId,
          planName: planName,
          district: district,
          block: block,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF592941).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.house_rounded,
                      color: Color(0xFF592941), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settlement,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF592941),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$block · $district',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MARK RESOURCES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _ResourceAction(
            icon: Icons.water_drop,
            color: const Color(0xFF1565C0),
            label: 'Add Well',
            subtitle: 'Record a well at this settlement',
            onTap: () => _openForm(
              context,
              OdkUrls.well(
                marker: markerPosition,
                block: block,
                planId: planId,
                planName: planName,
                settlementId: settlementId,
                settlementName: settlement,
                userPos: userPosition,
              ),
              'Add Well',
              OdkResourceType.well,
            ),
          ),
          _ResourceAction(
            icon: Icons.water,
            color: const Color(0xFF00838F),
            label: 'Add Water Structure',
            subtitle: 'Record a water structure',
            onTap: () => _openForm(
              context,
              OdkUrls.waterStructure(
                marker: markerPosition,
                block: block,
                planId: planId,
                planName: planName,
                settlementId: settlementId,
                settlementName: settlement,
                userPos: userPosition,
              ),
              'Add Water Structure',
              OdkResourceType.waterStructure,
            ),
          ),
          _ResourceAction(
            icon: Icons.grass,
            color: const Color(0xFF2E7D32),
            label: 'Add Cropping Pattern',
            subtitle: 'Record crop type and season',
            onTap: () => _openForm(
              context,
              OdkUrls.cropping(
                marker: markerPosition,
                block: block,
                planId: planId,
                planName: planName,
                settlementId: settlementId,
                settlementName: settlement,
                userPos: userPosition,
              ),
              'Add Cropping Pattern',
              OdkResourceType.cropping,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'INFORMATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _ResourceAction(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF592941),
            label: 'Resource Info',
            subtitle: 'View attributes for this settlement',
            onTap: () {
              Navigator.pop(context);
              _showResourceInfoSheet(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showResourceInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResourceInfoSheet(
        settlement: settlement,
        properties: settlementProperties,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _ResourceAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ResourceAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A1A1A))),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ResourceInfoSheet extends StatelessWidget {
  final String settlement;
  final Map<String, dynamic> properties;

  const _ResourceInfoSheet({
    required this.settlement,
    required this.properties,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final entries = properties.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  settlement,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF592941),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF592941)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No attributes available.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.only(bottom: bottomPadding + 16, top: 8),
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 20, endIndent: 20),
                itemBuilder: (_, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            entries[i].key.replaceAll('_', ' '),
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            entries[i].value.toString(),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
