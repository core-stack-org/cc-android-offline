import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/constants.dart';

class AdminDetails {
  final String? state;
  final String? district;
  final String? tehsil;

  AdminDetails({this.state, this.district, this.tehsil});

  factory AdminDetails.fromJson(Map<String, dynamic> json) {
    final normalized = json.map((k, v) => MapEntry(k.toLowerCase(), v));
    return AdminDetails(
      state: normalized['state'] as String?,
      district: normalized['district'] as String?,
      tehsil: normalized['tehsil'] as String?,
    );
  }

  bool get hasData => state != null || district != null || tehsil != null;
}

enum LocateMeError { locationDisabled, permissionDenied, networkError, apiError }

class LocateMeResult {
  final AdminDetails? data;
  final LocateMeError? error;
  final String? message;

  LocateMeResult.success(this.data)
      : error = null,
        message = null;

  LocateMeResult.failure(this.error, [this.message]) : data = null;
}

class LocateMeService {
  static Future<LocateMeResult> fetchAdminDetailsByCoordinates(
      double latitude, double longitude) async {
    return await _getAdminDetails(latitude, longitude);
  }

  static Future<LocateMeResult> fetchAdminDetailsFromLocation() async {
    try {
      final position = await _determinePosition();
      if (position == null) {
        return LocateMeResult.failure(LocateMeError.permissionDenied);
      }
      return await _getAdminDetails(position.latitude, position.longitude);
    } on LocationServiceDisabledException {
      return LocateMeResult.failure(LocateMeError.locationDisabled,
          'Please enable location services');
    } on PermissionDeniedException {
      return LocateMeResult.failure(
          LocateMeError.permissionDenied, 'Location permission denied');
    } catch (e) {
      return LocateMeResult.failure(LocateMeError.networkError, e.toString());
    }
  }

  static Future<Position?> _determinePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException(
          'Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  static Future<LocateMeResult> _getAdminDetails(
      double latitude, double longitude) async {
    try {
      final uri = Uri.parse('${apiUrl}get_admin_details_by_latlon/').replace(
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'X-API-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LocateMeResult.success(AdminDetails.fromJson(data));
      }

      return LocateMeResult.failure(
          LocateMeError.apiError, 'Server returned ${response.statusCode}');
    } on SocketException {
      return LocateMeResult.failure(
          LocateMeError.networkError, 'No internet connection');
    } catch (e) {
      return LocateMeResult.failure(LocateMeError.apiError, e.toString());
    }
  }
}
