import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final StorageService _storage = StorageService();

  // Get headers with authorization
  Map<String, String> _getHeaders({bool includeAuth = false}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = _storage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // POST request (JSON)
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = false,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint');
    
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // POST request (Form data for OAuth2)
  Future<http.Response> postForm(
    String endpoint, {
    Map<String, String>? body,
    bool includeAuth = false,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint');
    
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = _storage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // GET request
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool includeAuth = true,
  }) async {
    var url = Uri.parse('${AppConfig.baseUrl}$endpoint');
    
    if (queryParams != null && queryParams.isNotEmpty) {
      url = url.replace(queryParameters: queryParams);
    }

    try {
      final response = await http.get(
        url,
        headers: _getHeaders(includeAuth: includeAuth),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // PUT request
  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint');

    try {
      final response = await http.put(
        url,
        headers: _getHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // DELETE request
  Future<http.Response> delete(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint');

    try {
      final response = await http.delete(
        url,
        headers: _getHeaders(includeAuth: includeAuth),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Get system status
  Future<Map<String, dynamic>> getStatus() async {
    try {
      print('Fetching status from: ${AppConfig.baseUrl}/api/v1/status');
      final response = await get('/api/v1/status', includeAuth: false);
      
      print('Status response code: ${response.statusCode}');
      print('Status response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in getStatus: $e');
      rethrow;
    }
  }

  // Handle API errors
  String getErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      return 'An error occurred';
    } catch (e) {
      return 'Network error occurred';
    }
  }
}
