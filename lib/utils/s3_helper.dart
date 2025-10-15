// s3_helper.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class S3Helper {
  final String accessKey;
  final String secretKey;
  final String region;
  final String bucketName;

  S3Helper({
    required this.accessKey,
    required this.secretKey,
    required this.region,
    required this.bucketName,
  });

  /// Downloads a file from private S3 bucket
  Future<String> downloadFile(String objectKey) async {
    final url = 'https://s3.$region.amazonaws.com/$bucketName/$objectKey';
    final uri = Uri.parse(url);
    
    final now = DateTime.now().toUtc();
    final dateStamp = _formatDateStamp(now);
    final amzDate = _formatAmzDate(now);
    
    final headers = {
      'host': uri.host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': _hash(''),
    };
    
    final signature = _generateSignature(
      method: 'GET',
      uri: uri,
      headers: headers,
      dateStamp: dateStamp,
      amzDate: amzDate,
    );
    
    headers['Authorization'] = signature;
    
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to download from S3: ${response.statusCode} - ${response.body}');
    }
  }

  String _generateSignature({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String dateStamp,
    required String amzDate,
  }) {
    // Step 1: Create canonical request
    final canonicalUri = uri.path.isEmpty ? '/' : uri.path;
    final canonicalQueryString = uri.query;
    
    final sortedHeaders = headers.keys.toList()..sort();
    final canonicalHeaders = sortedHeaders
        .map((key) => '${key.toLowerCase()}:${headers[key]!.trim()}')
        .join('\n') + '\n';
    
    final signedHeaders = sortedHeaders.map((key) => key.toLowerCase()).join(';');
    
    final payloadHash = headers['x-amz-content-sha256']!;
    
    final canonicalRequest = '$method\n'
        '$canonicalUri\n'
        '$canonicalQueryString\n'
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';
    
    // Step 2: Create string to sign
    final algorithm = 'AWS4-HMAC-SHA256';
    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    
    final stringToSign = '$algorithm\n'
        '$amzDate\n'
        '$credentialScope\n'
        '${_hash(canonicalRequest)}';
    
    // Step 3: Calculate signature
    final signingKey = _getSignatureKey(secretKey, dateStamp, region, 's3');
    final signature = _hmacSha256(signingKey, utf8.encode(stringToSign));
    
    // Step 4: Create authorization header
    return '$algorithm Credential=$accessKey/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=${_bytesToHex(signature)}';
  }

  List<int> _getSignatureKey(String key, String dateStamp, String region, String service) {
    final kDate = _hmacSha256(utf8.encode('AWS4$key'), utf8.encode(dateStamp));
    final kRegion = _hmacSha256(kDate, utf8.encode(region));
    final kService = _hmacSha256(kRegion, utf8.encode(service));
    final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
    return kSigning;
  }

  List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }

  String _hash(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String _formatAmzDate(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}'
        'T'
        '${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}'
        'Z';
  }

  String _formatDateStamp(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // * Downloads a file from S3 as bytes (for binary files like images)
  Future<List<int>> downloadFileBytes(String objectKey) async {
    final url = 'https://s3.$region.amazonaws.com/$bucketName/$objectKey';
    final uri = Uri.parse(url);
    
    final now = DateTime.now().toUtc();
    final dateStamp = _formatDateStamp(now);
    final amzDate = _formatAmzDate(now);
    
    final headers = {
      'host': uri.host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': _hash(''),
    };
    
    final signature = _generateSignature(
      method: 'GET',
      uri: uri,
      headers: headers,
      dateStamp: dateStamp,
      amzDate: amzDate,
    );
    
    headers['Authorization'] = signature;
    
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download from S3: ${response.statusCode} - ${response.body}');
    }
  }
}