// ignore_for_file: unused_import
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nrmflutter/utils/constants.dart';
import 'package:nrmflutter/services/login_service.dart';

class ResourceService {
  // TODO: Wire these once the API endpoints are finalised.
  // Both methods currently return successfully without hitting any server.

  /// POST /add_resources — record a surveyed resource (well, water structure, etc.)
  static Future<void> addResources({
    required String resourceType,
    required String settlementName,
    required String district,
    required String block,
    required String blockId,
    required Map<String, dynamic> formData,
  }) async {
    // TODO: Implement once /add_resources endpoint contract is defined.
    // final headers = await _authHeaders();
    // final body = {
    //   'resource_type': resourceType,
    //   'settlement': settlementName,
    //   'district': district,
    //   'block': block,
    //   'block_id': blockId,
    //   ...formData,
    // };
    // final response = await http.post(
    //   Uri.parse('${apiUrl}add_resources/'),
    //   headers: headers,
    //   body: jsonEncode(body),
    // );
    // if (response.statusCode != 201) throw Exception('add_resources failed');
    return;
  }

  /// POST /add — record a work item
  static Future<void> add({
    required String workType,
    required String district,
    required String block,
    required String blockId,
    required Map<String, dynamic> formData,
  }) async {
    // TODO: Implement once /add endpoint contract is defined.
    // final headers = await _authHeaders();
    // final body = {
    //   'work_type': workType,
    //   'district': district,
    //   'block': block,
    //   'block_id': blockId,
    //   ...formData,
    // };
    // final response = await http.post(
    //   Uri.parse('${apiUrl}add/'),
    //   headers: headers,
    //   body: jsonEncode(body),
    // );
    // if (response.statusCode != 201) throw Exception('add failed');
    return;
  }

  // ignore: unused_element
  static Future<Map<String, String>> _authHeaders() async {
    final token = await LoginService().getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
