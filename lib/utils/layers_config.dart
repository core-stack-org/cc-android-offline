import 'package:nrmflutter/config/geoserver_config.dart';
import 'package:nrmflutter/db/plans_db.dart';

class LayersConfig {
  static Future<List<Map<String, String>>> getLayers(
      String? district, String? block,
      {String? blockId}) async {
    final ctx = GeoServerContext(rawDistrict: district!, rawBlock: block!);

    // Static layers (vectors only – rasters are downloaded separately)
    final List<Map<String, String>> layers = GeoServerRegistry.allStaticLayers
        .where((l) => l.kind != GeoServerLayerKind.raster)
        .map((l) => {'name': l.displayName, 'geoserverPath': l.typeName(ctx)})
        .toList();

    if (blockId != null) {
      final plans =
          await PlansDatabase.instance.getPlansForTehsil(int.parse(blockId));

      for (var plan in plans) {
        final planId = plan['id'].toString();
        final planCtx = GeoServerContext(
          rawDistrict: district,
          rawBlock: block,
          planId: planId,
        );

        // Resource layer names must match original pattern for offline file storage.
        final resourceEntries = [
          ('settlement_$planId', GeoServerRegistry.settlement),
          ('well_$planId', GeoServerRegistry.planWell),
          ('waterbody_$planId', GeoServerRegistry.planWaterbody),
          ('cropping_$planId', GeoServerRegistry.planCropping),
        ];
        final worksEntries = [
          ('main_swb_$planId', GeoServerRegistry.planMainSwb),
          ('plan_agri_$planId', GeoServerRegistry.planAgri),
          ('plan_gw_$planId', GeoServerRegistry.planGroundwater),
          ('livelihood_$planId', GeoServerRegistry.planLivelihood),
        ];

        for (final (name, layer) in [...resourceEntries, ...worksEntries]) {
          layers.add({'name': name, 'geoserverPath': layer.typeName(planCtx)});
        }
      }
    }

    return layers;
  }
}
