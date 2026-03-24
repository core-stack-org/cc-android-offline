import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

enum LoginResult { success, invalidCredentials, networkError, serverError }

sealed class ForgotPasswordResult {}

class ForgotPasswordSuccess extends ForgotPasswordResult {}

class ForgotPasswordEmailRequired extends ForgotPasswordResult {}

class ForgotPasswordError extends ForgotPasswordResult {
  final String message;
  ForgotPasswordError(this.message);
}

class LoginService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _tokenExpiryKey = 'token_expiry';

  Future<LoginResult> login(String username, String password) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('${apiUrl}auth/login/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
    } on SocketException {
      return LoginResult.networkError;
    } on HttpException {
      return LoginResult.networkError;
    } on FormatException {
      return LoginResult.serverError;
    } catch (e) {
      return LoginResult.networkError;
    }

    Map<String, dynamic> responseData;
    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      return LoginResult.serverError;
    }

    if (response.statusCode == 200) {
      final String? accessToken = responseData['access'];
      final String? refreshToken = responseData['refresh'];
      final Map<String, dynamic>? userData = responseData['user'];

      if (accessToken != null && refreshToken != null && userData != null) {
        await _storeAuthData(accessToken, refreshToken, userData);
        return LoginResult.success;
      }
      return LoginResult.serverError;
    }

    if (response.statusCode == 401 || response.statusCode == 400) {
      return LoginResult.invalidCredentials;
    }

    return LoginResult.serverError;
  }

  Future<ForgotPasswordResult> forgotPassword(String username, {String? email}) async {
    final http.Response response;
    try {
      final body = <String, String>{'username': username};
      if (email != null) body['email'] = email;

      response = await http.post(
        Uri.parse('${apiUrl}auth/forgot-password/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
    } on SocketException {
      return ForgotPasswordError('network');
    } on HttpException {
      return ForgotPasswordError('network');
    } catch (e) {
      return ForgotPasswordError('network');
    }

    if (response.statusCode == 200) {
      return ForgotPasswordSuccess();
    }

    Map<String, dynamic> responseData;
    try {
      responseData = jsonDecode(response.body);
    } catch (_) {
      return ForgotPasswordError('server');
    }

    if (response.statusCode == 400 && responseData['email_required'] == true) {
      return ForgotPasswordEmailRequired();
    }

    final detail = responseData['detail'] as String?;
    return ForgotPasswordError(detail ?? 'server');
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
        Uri.parse('${apiUrl}auth/token/refresh/'),
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
