import 'package:nrmflutter/utils/utility.dart';

enum GeoServerLayerKind { point, vector, raster }

enum PlanningCategory {
  groundwater,
  surfaceWater,
  agriculture,
  livelihood,
  agrohorticulture,
}

class GeoServerContext {
  final String district;
  final String block;
  final String? planId;
  final String? lulcYear;

  GeoServerContext({
    required String rawDistrict,
    required String rawBlock,
    this.planId,
    this.lulcYear,
  })  : district = formatNameForGeoServer(rawDistrict),
        block = formatNameForGeoServer(rawBlock);
}

class GeoServerLayer {
  final String id;
  final String displayName;
  final String workspace;
  final GeoServerLayerKind kind;
  final String? wmsStyle;
  final PlanningCategory? planningCategory;
  final String Function(GeoServerContext ctx) _typeNameBuilder;

  const GeoServerLayer({
    required this.id,
    required this.displayName,
    required this.workspace,
    required this.kind,
    required String Function(GeoServerContext ctx) typeNameBuilder,
    this.wmsStyle,
    this.planningCategory,
  }) : _typeNameBuilder = typeNameBuilder;

  String typeName(GeoServerContext ctx) => _typeNameBuilder(ctx);

  /// Fully qualified WFS GetFeature URL
  String wfsUrl(String geoserverBaseUrl, GeoServerContext ctx) {
    return '${geoserverBaseUrl}geoserver/wfs?'
        'service=WFS&version=1.0.0&request=GetFeature'
        '&typeName=${typeName(ctx)}'
        '&outputFormat=application/json';
  }

  /// WMS GetMap base URL for raster overlay (use with flutter_map WMSTileLayerOptions)
  String wmsBaseUrl(String geoserverBaseUrl) {
    return '${geoserverBaseUrl}geoserver/wms';
  }
}

class GeoServerRegistry {
  GeoServerRegistry._();

  // ---------------------------------------------------------------------------
  // Static vector / point layers
  // ---------------------------------------------------------------------------

  static final adminBoundaries = GeoServerLayer(
    id: 'admin_boundaries',
    displayName: 'Admin Boundaries',
    workspace: 'panchayat_boundaries',
    kind: GeoServerLayerKind.vector,
    typeNameBuilder: (ctx) => 'panchayat_boundaries:${ctx.district}_${ctx.block}',
  );

  static final settlement = GeoServerLayer(
    id: 'settlement',
    displayName: 'Settlements',
    workspace: 'resources',
    kind: GeoServerLayerKind.point,
    typeNameBuilder: (ctx) =>
        'resources:settlement_${ctx.planId ?? ''}_${ctx.district}_${ctx.block}',
  );

  static final nregaAssets = GeoServerLayer(
    id: 'nrega_assets',
    displayName: 'NREGA Assets',
    workspace: 'nrega_assets',
    kind: GeoServerLayerKind.point,
    planningCategory: PlanningCategory.livelihood,
    typeNameBuilder: (ctx) => 'nrega_assets:${ctx.district}_${ctx.block}',
  );

  static final wellDepthYearly = GeoServerLayer(
    id: 'well_depth_yearly',
    displayName: 'Well Depth Yearly',
    workspace: 'mws_layers',
    kind: GeoServerLayerKind.point,
    planningCategory: PlanningCategory.groundwater,
    typeNameBuilder: (ctx) =>
        'mws_layers:deltaG_well_depth_${ctx.district}_${ctx.block}',
  );

  static final wellDepthFortnightly = GeoServerLayer(
    id: 'well_depth_fortnightly',
    displayName: 'Well Depth Fortnightly',
    workspace: 'mws_layers',
    kind: GeoServerLayerKind.point,
    planningCategory: PlanningCategory.groundwater,
    typeNameBuilder: (ctx) =>
        'mws_layers:deltaG_fortnight_${ctx.district}_${ctx.block}',
  );

  static final drainage = GeoServerLayer(
    id: 'drainage',
    displayName: 'Drainage',
    workspace: 'drainage',
    kind: GeoServerLayerKind.vector,
    planningCategory: PlanningCategory.surfaceWater,
    typeNameBuilder: (ctx) => 'drainage:${ctx.district}_${ctx.block}',
  );

  static final surfaceWaterbodies = GeoServerLayer(
    id: 'surface_waterbodies',
    displayName: 'Surface Waterbodies',
    workspace: 'swb',
    kind: GeoServerLayerKind.vector,
    planningCategory: PlanningCategory.surfaceWater,
    typeNameBuilder: (ctx) =>
        'swb:surface_waterbodies_${ctx.district}_${ctx.block}',
  );

  static final croppingDrought = GeoServerLayer(
    id: 'cropping_drought',
    displayName: 'Cropping Drought',
    workspace: 'drought',
    kind: GeoServerLayerKind.vector,
    planningCategory: PlanningCategory.agriculture,
    typeNameBuilder: (ctx) => 'drought:${ctx.district}_${ctx.block}_drought',
  );

  static final croppingIntensity = GeoServerLayer(
    id: 'cropping_intensity',
    displayName: 'Cropping Intensity',
    workspace: 'crop_intensity',
    kind: GeoServerLayerKind.vector,
    planningCategory: PlanningCategory.agriculture,
    typeNameBuilder: (ctx) =>
        'crop_intensity:${ctx.district}_${ctx.block}_intensity',
  );

  static final cropGrid = GeoServerLayer(
    id: 'crop_grid',
    displayName: 'Crop Grid',
    workspace: 'crop_grid_layers',
    kind: GeoServerLayerKind.vector,
    planningCategory: PlanningCategory.agriculture,
    typeNameBuilder: (ctx) =>
        'crop_grid_layers:${ctx.district}_${ctx.block}_grid',
  );

  // ---------------------------------------------------------------------------
  // Plan resource layers (require planId in context)
  // ---------------------------------------------------------------------------

  static final planWell = GeoServerLayer(
    id: 'plan_well',
    displayName: 'Wells',
    workspace: 'resources',
    kind: GeoServerLayerKind.point,
    typeNameBuilder: (ctx) =>
        'resources:well_${ctx.planId ?? ''}_${ctx.district}_${ctx.block}',
  );

  static final planWaterbody = GeoServerLayer(
    id: 'plan_waterbody',
    displayName: 'Water Structures',
    workspace: 'resources',
    kind: GeoServerLayerKind.point,
    typeNameBuilder: (ctx) =>
        'resources:waterbody_${ctx.planId ?? ''}_${ctx.district}_${ctx.block}',
  );

  static final planCropping = GeoServerLayer(
    id: 'plan_cropping',
    displayName: 'Cropping Patterns',
    workspace: 'resources',
    kind: GeoServerLayerKind.vector,
    typeNameBuilder: (ctx) =>
        'resources:cropping_${ctx.planId ?? ''}_${ctx.district}_${ctx.block}',
  );

  static final planMainSwb = GeoServerLayer(
    id: 'plan_main_swb',
    displayName: 'Main SWB',
    workspace: 'works',
    kind: GeoServerLayerKind.vector,
    planningCategory: PlanningCategory.surfaceWater,
    typeNameBuilder: (ctx) =>
        'works:main_swb_${ctx.planId ?? ''}_${ctx.district}_${ctx.block}',
  );

  static final planAgri = GeoServerLayer(
    id: 'plan_agri',
    displayName: 'Agriculture Plan',
    workspace: 'works',
    kind: GeoServerLayerKind.vector,
    planningCategory: PlanningCategory.agriculture,
    typeNameBuilder: (ctx) =>
        'works:plan_agri_${ctx.planId ?? ''}_${ctx.district}_${ctx.block}',
  );

  static final planGroundwater = GeoServerLayer(
    id: 'plan_gw',
    displayName: 'Groundwater Plan',
    workspace: 'works',
    kind: GeoServerLayerKind.vector,
    planningCategory: PlanningCategory.groundwater,
    typeNameBuilder: (ctx) =>
        'works:plan_gw_${ctx.planId ?? ''}_${ctx.district}_${ctx.block}',
  );

  static final planLivelihood = GeoServerLayer(
    id: 'plan_livelihood',
    displayName: 'Livelihood Plan',
    workspace: 'works',
    kind: GeoServerLayerKind.vector,
    planningCategory: PlanningCategory.livelihood,
    typeNameBuilder: (ctx) =>
        'works:livelihood_${ctx.planId ?? ''}_${ctx.district}_${ctx.block}',
  );

  // ---------------------------------------------------------------------------
  // Raster layers
  // ---------------------------------------------------------------------------

  static final clart = GeoServerLayer(
    id: 'clart',
    displayName: 'CLART',
    workspace: 'clart',
    kind: GeoServerLayerKind.raster,
    wmsStyle: 'testClart',
    planningCategory: PlanningCategory.agriculture,
    typeNameBuilder: (ctx) => 'clart:${ctx.district}_${ctx.block}_clart',
  );

  static final streamOrder = GeoServerLayer(
    id: 'stream_order',
    displayName: 'Stream Order',
    workspace: 'stream_order',
    kind: GeoServerLayerKind.raster,
    wmsStyle: 'stream_order',
    planningCategory: PlanningCategory.surfaceWater,
    typeNameBuilder: (ctx) =>
        'stream_order:stream_order_${ctx.district}_${ctx.block}_raster',
  );

  static final naturalDepression = GeoServerLayer(
    id: 'natural_depression',
    displayName: 'Natural Depression',
    workspace: 'natural_depression',
    kind: GeoServerLayerKind.raster,
    wmsStyle: 'natural_depression',
    planningCategory: PlanningCategory.surfaceWater,
    typeNameBuilder: (ctx) =>
        'natural_depression:natural_depression_${ctx.district}_${ctx.block}_raster',
  );

  static final terrain = GeoServerLayer(
    id: 'terrain',
    displayName: 'Terrain',
    workspace: 'terrain',
    kind: GeoServerLayerKind.raster,
    wmsStyle: 'Terrain_Style_11_Classes',
    planningCategory: PlanningCategory.agriculture,
    typeNameBuilder: (ctx) =>
        'terrain:${ctx.district}_${ctx.block}_terrain_raster',
  );

  static final siteSuitability = GeoServerLayer(
    id: 'site_suitability',
    displayName: 'Site Suitability',
    workspace: 'plantation',
    kind: GeoServerLayerKind.raster,
    wmsStyle: 'site_suitability',
    planningCategory: PlanningCategory.agrohorticulture,
    typeNameBuilder: (ctx) =>
        'plantation:${ctx.district}_${ctx.block}_site_suitability_raster',
  );

  static GeoServerLayer lulc(String year) => GeoServerLayer(
        id: 'lulc_$year',
        displayName: 'LULC $year',
        workspace: 'LULC_level_3',
        kind: GeoServerLayerKind.raster,
        wmsStyle: 'lulc_level_3_style',
        planningCategory: PlanningCategory.agriculture,
        typeNameBuilder: (ctx) =>
            'LULC_level_3:LULC_${year}_${ctx.district}_${ctx.block}_level_3',
      );

  static const List<String> lulcYears = [
    '17_18', '18_19', '19_20', '20_21', '21_22', '22_23', '23_24'
  ];

  // ---------------------------------------------------------------------------
  // Category helpers
  // ---------------------------------------------------------------------------

  static List<GeoServerLayer> get allStaticLayers => [
        adminBoundaries,
        nregaAssets,
        wellDepthYearly,
        wellDepthFortnightly,
        drainage,
        surfaceWaterbodies,
        croppingDrought,
        croppingIntensity,
        cropGrid,
        clart,
        streamOrder,
        naturalDepression,
        terrain,
        siteSuitability,
        ...lulcYears.map(lulc),
      ];

  static List<GeoServerLayer> layersForCategory(PlanningCategory category) {
    return allStaticLayers
        .where((l) => l.planningCategory == category)
        .toList();
  }

  // Panchayat boundary WFS URL (used by mark_location and resource mapping)
  static String panchayatBoundaryWfsUrl(
      String geoserverBaseUrl, GeoServerContext ctx) {
    return '${geoserverBaseUrl}geoserver/panchayat_boundaries/ows?'
        'service=WFS&version=1.0.0&request=GetFeature'
        '&typeName=panchayat_boundaries:${ctx.district}_${ctx.block}'
        '&outputFormat=application/json';
  }
}
