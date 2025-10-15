import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class LoginService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _tokenExpiryKey = 'token_expiry';

  Future<bool> login(String username, String password) async {
    try {
      print('Making login request to: ${apiUrl}auth/login/');
      print('Username: $username');
      print('Password: [HIDDEN]');

      final Map<String, dynamic> requestBody = {
        'username': username,
        'password': password,
      };

      print('REQUEST BODY: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('${apiUrl}auth/login/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('RESPONSE STATUS CODE: ${response.statusCode}');
      print('RESPONSE HEADERS: ${response.headers}');
      print('RESPONSE BODY: ${response.body}');

      // Parse the JSON response
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body);
        print('Parsed JSON response: $responseData');
      } catch (e) {
        print('Error parsing JSON response: $e');
        return false;
      }

      if (response.statusCode == 200) {
        print('=== LOGIN API SUCCESS (200) ===');

        final String? accessToken = responseData['access'];
        final String? refreshToken = responseData['refresh'];
        final Map<String, dynamic>? userData = responseData['user'];

        print('Access token exists: ${accessToken != null}');
        print('Refresh token exists: ${refreshToken != null}');
        print('User data exists: ${userData != null}');

        if (accessToken != null) {
          print('Access token length: ${accessToken.length}');
        }
        if (refreshToken != null) {
          print('Refresh token length: ${refreshToken.length}');
        }
        if (userData != null) {
          print('User data keys: ${userData.keys.toList()}');
        }

        if (accessToken != null && refreshToken != null && userData != null) {
          print('=== ALL REQUIRED FIELDS PRESENT ===');

          // Store tokens and user data securely
          await _storeAuthData(accessToken, refreshToken, userData);

          print('=== STORED AUTH DATA ===');
          print('Access token: ${accessToken.substring(0, 20)}...');
          print('Refresh token: ${refreshToken.substring(0, 20)}...');
          print('User: ${userData['username']} (${userData['email']})');
          print('Organization: ${userData['organization_name']}');
          print('Is Superadmin: ${userData['is_superadmin']}');
          print('Groups: ${userData['groups']}');

          print('=== RETURNING TRUE FOR LOGIN SUCCESS ===');
          return true;
        } else {
          print('=== LOGIN RESPONSE MISSING REQUIRED FIELDS ===');
          print('Missing access token: ${accessToken == null}');
          print('Missing refresh token: ${refreshToken == null}');
          print('Missing user data: ${userData == null}');
          return false;
        }
      } else if (response.statusCode == 401) {
        print('Login failed: Invalid credentials (401)');
        if (responseData.containsKey('detail')) {
          print('Error message: ${responseData['detail']}');
        }
        return false;
      } else if (response.statusCode == 400) {
        print('Login failed: Bad request (400)');
        if (responseData.containsKey('detail')) {
          print('Error message: ${responseData['detail']}');
        }
        return false;
      } else {
        print('Login failed: Unexpected status code ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Network error during login: $e');
      print('Exception type: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  Future<void> _storeAuthData(String accessToken, String refreshToken,
      Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);

    await prefs.setString(_userDataKey, jsonEncode(userData));

    final expiryTime = DateTime.now().add(const Duration(days: 2));
    await prefs.setString(_tokenExpiryKey, expiryTime.toIso8601String());

    print('Auth data stored successfully');
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userDataKey);
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  Future<bool> isAccessTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryString = prefs.getString(_tokenExpiryKey);
    if (expiryString != null) {
      final expiryTime = DateTime.parse(expiryString);
      final now = DateTime.now();
      return now.isAfter(expiryTime.subtract(const Duration(minutes: 5)));
    }
    return true;
  }

  Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    final isExpired = await isAccessTokenExpired();

    if (accessToken != null && refreshToken != null) {
      if (!isExpired) {
        print('User is logged in with valid access token');
        return true;
      } else {
        print('Access token expired, attempting refresh...');
        return await refreshAccessToken();
      }
    }

    print('User is not logged in');
    return false;
  }

  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        print('No refresh token available');
        return false;
      }

      print('Refreshing access token...');

      final response = await http.post(
        Uri.parse('${apiUrl}auth/refresh/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'refresh': refreshToken,
        }),
      );

      print('Token refresh response status: ${response.statusCode}');
      print('Token refresh response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String? newAccessToken = responseData['access'];
        final String? newRefreshToken = responseData['refresh'];

        if (newAccessToken != null) {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString(_accessTokenKey, newAccessToken);

          if (newRefreshToken != null) {
            await prefs.setString(_refreshTokenKey, newRefreshToken);
            print('Both access and refresh tokens updated');
          } else {
            print('Only access token updated');
          }

          final expiryTime = DateTime.now().add(const Duration(days: 2));
          await prefs.setString(_tokenExpiryKey, expiryTime.toIso8601String());

          print('Token refresh successful');
          return true;
        }
      } else if (response.statusCode == 401) {
        print('Refresh token expired or invalid, user needs to login again');
        await clearStoredCredentials();
        return false;
      }

      print('Token refresh failed');
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  Future<String?> getValidAccessToken() async {
    final isExpired = await isAccessTokenExpired();

    if (isExpired) {
      final refreshSuccess = await refreshAccessToken();
      if (!refreshSuccess) {
        return null;
      }
    }

    return await getAccessToken();
  }

  Future<http.Response?> makeAuthenticatedRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final accessToken = await getValidAccessToken();
    if (accessToken == null) {
      print('No valid access token available');
      return null;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      http.Response response;
      final uri = Uri.parse('$apiUrl$endpoint');

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(uri,
              headers: headers, body: body != null ? jsonEncode(body) : null);
          break;
        case 'PUT':
          response = await http.put(uri,
              headers: headers, body: body != null ? jsonEncode(body) : null);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      return response;
    } catch (e) {
      print('Error making authenticated request: $e');
      return null;
    }
  }

  Future<void> clearStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_tokenExpiryKey);
    print('All stored credentials cleared');
  }

  Future<void> logout() async {
    try {
      final response =
          await makeAuthenticatedRequest('auth/logout/', method: 'POST');
      if (response != null) {
        print('Server logout response: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during server logout: $e');
    } finally {
      await clearStoredCredentials();
      print('User logged out successfully');
    }
  }

  /// Get authentication data for webview
  Future<Map<String, dynamic>?> getAuthDataForWebView() async {
    try {
      final accessToken = await getValidAccessToken();
      final userData = await getUserData();

      if (accessToken != null && userData != null) {
        return {
          'access_token': accessToken,
          'user': userData,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
      }
      return null;
    } catch (e) {
      print('Error getting auth data for webview: $e');
      return null;
    }
  }

  /// Refresh token specifically for webview requests
  Future<Map<String, dynamic>?> refreshTokenForWebView() async {
    try {
      final success = await refreshAccessToken();
      if (success) {
        return await getAuthDataForWebView();
      }
      return null;
    } catch (e) {
      print('Error refreshing token for webview: $e');
      return null;
    }
  }
}
