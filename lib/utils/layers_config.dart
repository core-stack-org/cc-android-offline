import 'package:nrmflutter/db/plans_db.dart';

class LayersConfig {
  static Future<List<Map<String, String>>> getLayers(
      String? district, String? block,
      {String? blockId}) async {
    print(
        "LayersConfig.getLayers called with district: $district, block: $block, blockId: $blockId");

    String formattedBlock = formatName(block);
    String formattedDistrict = formatName(district);
    print(
        "Formatted names - district: $formattedDistrict, block: $formattedBlock");

    List<Map<String, String>> layers = [
      {
        "name": "Admin Boundaries",
        "geoserverPath":
            "panchayat_boundaries:${formattedDistrict}_${formattedBlock}"
      },
      {
        "name": "NREGA Assets",
        "geoserverPath": "nrega_assets:${formattedDistrict}_$formattedBlock"
      },
      {
        "name": "Well Depth Yearly",
        "geoserverPath":
            "mws_layers:deltaG_well_depth_${formattedDistrict}_${formattedBlock}"
      },
      {
        "name": "Well Depth Fortnightly",
        "geoserverPath":
            "mws_layers:deltaG_fortnight_${formattedDistrict}_${formattedBlock}"
      },
      {
        "name": "Drainage",
        "geoserverPath": "drainage:${formattedDistrict}_${formattedBlock}"
      },
      {
        "name": "Surface Waterbodies",
        "geoserverPath":
            "swb:surface_waterbodies_${formattedDistrict}_${formattedBlock}"
      },
      {
        "name": "Cropping Drought",
        "geoserverPath":
            "cropping_drought:${formattedDistrict}_${formattedBlock}_drought"
      },
      {
        "name": "Cropping Intensity",
        "geoserverPath":
            "cropping_intensity:${formattedDistrict}_${formattedBlock}_intensity"
      },
      {
        "name": "Crop Grid",
        "geoserverPath":
            "crop_grid_layers:${formattedDistrict}_${formattedBlock}_grid"
      }
    ];

    if (blockId != null) {
      final plans =
          await PlansDatabase.instance.getPlansForBlock(int.parse(blockId));
      print("Found ${plans.length} plans for block");

      final resourceLayers = ['settlement', 'well', 'waterbody'];
      final worksLayers = ['main_swb', 'plan_agri', 'plan_gw', 'livelihood'];

      for (var plan in plans) {
        final planId = plan['plan_id'];

        // Add resource layers
        for (var resourceType in resourceLayers) {
          final layerName = "${resourceType}_${planId}";
          final geoserverPath =
              "resources:${resourceType}_${planId}_${formattedDistrict}_${formattedBlock}";

          layers.add({"name": layerName, "geoserverPath": geoserverPath});
        }

        // Add works layers
        for (var workType in worksLayers) {
          final layerName = "${workType}_${planId}";
          final geoserverPath =
              "works:${workType}_${planId}_${formattedDistrict}_${formattedBlock}";

          layers.add({"name": layerName, "geoserverPath": geoserverPath});
        }
      }
    } else {
      print("No blockId provided, skipping resource and works layers");
    }

    print("Total layers generated: ${layers.length}");
    return layers;
  }

  static String formatName(String? name) {
    if (name == null) return '';
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'[-\s]+'), '_')
        .trim();
  }
}
