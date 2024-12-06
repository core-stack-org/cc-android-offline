class LayersConfig {
  static List<Map<String, String>> getLayers(String? district, String? block) {
    String formattedBlock = formatName(block);
    String formattedDistrict = formatName(district);

    return [
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
    ];
  }

  static String formatName(String? name) {
    if (name == null) return '';
    return name.toLowerCase().replaceAll(' ', '_');
  }
}
