import 'package:latlong2/latlong.dart';

/// Builds pre-filled ODK (Enketo) form URLs.
/// ODK GPS fields expect "lat lon" space-separated format.
/// React reference: latlong[1]=lat, latlong[0]=lon → "lat lon".
abstract final class OdkUrls {
  static String _enc(String v) => Uri.encodeComponent(v);

  // Base URLs with tokens — keep on one line so they're easy to update
  static const _settlementBase =
      'https://odk.core-stack.org/f/AOV0NchVMqkZVpCgZyWwJylCdnOIXwi?st=TBomGhMfOetjH6thCwy\$zzXyj!5bZs6Q20MejPCDCdNmX7IO9MqzRB6DkJ\$PEOpl';
  static const _wellBase =
      'https://odk.core-stack.org/f/iB707x5CMdklU3QbjvopaeNlBiG3WLc?st=19BTDQ31numlgTB5vTjZZZxrgPRtYv1TZtNw2662Md\$OA0uqHioc3xYYZ8lNwrar';
  static const _waterStructureBase =
      'https://odk.core-stack.org/f/JlbwXkMvol1fIoCRpMN07AxbZawhW2e?st=XidlpvnHZfCMxcDlxXr4Jbxr6eKwtsclHZki7s9pbiIb14rPh7uNYCalXHs0M6ht';
  static const _croppingBase =
      'https://odk.core-stack.org/f/Jg7MnKeZ1W9oQkwlDb2iCV7BhXgXDN8?st=z44571PIPvbF2lpzcaRZruzCVIucT8Agm!ZfbrhUxUwhY6l78V8Vs5P!\$smauFD3';

  static String _gps(LatLng p) => _enc('${p.latitude} ${p.longitude}');
  static String _userLatLon(LatLng p) => _enc('${p.latitude},${p.longitude}');

  static String settlement({
    required LatLng marker,
    required String block,
    required String planId,
    required String planName,
    LatLng? userPos,
  }) {
    final u = userPos ?? marker;
    return '$_settlementBase'
        '&d[/data/GPS_point/point_mapsappearance]=${_gps(marker)}'
        '&d[/data/block_name]=${_enc(block)}'
        '&d[/data/plan_id]=${_enc(planId)}'
        '&d[/data/plan_name]=${_enc(planName)}'
        '&d[/data/user_latlon]=${_userLatLon(u)}'
        '&d[/data/meta/instanceID]=';
  }

  static String well({
    required LatLng marker,
    required String block,
    required String planId,
    required String planName,
    required String settlementId,
    required String settlementName,
    LatLng? userPos,
  }) {
    final u = userPos ?? marker;
    return '$_wellBase'
        '&d[/data/GPS_point/point_mapappearance]=${_gps(marker)}'
        '&d[/data/hamlet_id]=${_enc(settlementId)}'
        '&d[/data/block_name]=${_enc(block)}'
        '&d[/data/plan_id]=${_enc(planId)}'
        '&d[/data/beneficiary_settlement]=${_enc(settlementName)}'
        '&d[/data/user_latlon]=${_userLatLon(u)}'
        '&d[/data/plan_name]=${_enc(planName)}'
        '&d[/data/meta/instanceID]=';
  }

  static String waterStructure({
    required LatLng marker,
    required String block,
    required String planId,
    required String planName,
    required String settlementId,
    required String settlementName,
    LatLng? userPos,
  }) {
    final u = userPos ?? marker;
    return '$_waterStructureBase'
        '&d[/data/GPS_point/point_mapappearance]=${_gps(marker)}'
        '&d[/data/hamlet_id]=${_enc(settlementId)}'
        '&d[/data/block_name]=${_enc(block)}'
        '&d[/data/plan_id]=${_enc(planId)}'
        '&d[/data/beneficiary_settlement]=${_enc(settlementName)}'
        '&d[/data/user_latlon]=${_userLatLon(u)}'
        '&d[/data/plan_name]=${_enc(planName)}'
        '&d[/data/meta/instanceID]=';
  }

  static String cropping({
    required LatLng marker,
    required String block,
    required String planId,
    required String planName,
    required String settlementId,
    required String settlementName,
    String cropId = '',
    LatLng? userPos,
  }) {
    final u = userPos ?? marker;
    return '$_croppingBase'
        '&d[/data/GPS_point/point_mapappearance]=${_gps(marker)}'
        '&d[/data/hamlet_id]=${_enc(settlementId)}'
        '&d[/data/block_name]=${_enc(block)}'
        '&d[/data/crop_Grid_id]=${_enc(cropId)}'
        '&d[/data/beneficiary_settlement]=${_enc(settlementName)}'
        '&d[/data/plan_id]=${_enc(planId)}'
        '&d[/data/user_latlon]=${_userLatLon(u)}'
        '&d[/data/plan_name]=${_enc(planName)}'
        '&d[/data/meta/instanceID]=';
  }
}
