import 'dart:convert';
import '../config/app_config.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  // Login
  Future<AuthResponse> login(String email, String password) async {
    try {
      // Your backend expects JSON with 'email' and 'password' fields
      final response = await _api.post(
        AppConfig.loginEndpoint,
        body: {
          'email': email,
          'password': password,
        },
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        
        // Save token and user
        await _storage.saveToken(authResponse.accessToken);
        await _storage.saveUser(authResponse.user);
        
        return authResponse;
      } else {
        throw Exception(_api.getErrorMessage(response));
      }
    } catch (e) {
      rethrow;
    }
  }

  // Register
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String role,
    String? name,
  }) async {
    try {
      print('Registering user with email: $email, role: $role');
      
      final response = await _api.post(
        AppConfig.registerEndpoint,
        body: {
          'email': email,
          'password': password,
          'role': role,
          if (name != null) 'name': name,
        },
        includeAuth: false,
      );

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        if (responseData == null) {
          throw Exception('Received null response from server');
        }
        
        // Check if response contains access_token (login-style response)
        if (responseData.containsKey('access_token')) {
          final authResponse = AuthResponse.fromJson(responseData);
          
          // Save token and user
          await _storage.saveToken(authResponse.accessToken);
          await _storage.saveUser(authResponse.user);
          
          print('Registration successful with token');
          return authResponse;
        } else {
          // Backend returned only user object without token
          // Need to login separately to get token
          print('Registration successful, but no token returned. Logging in...');
          
          // Save user temporarily
          final user = User.fromJson(responseData);
          
          // Automatically login to get token
          return await login(email, password);
        }
      } else {
        throw Exception(_api.getErrorMessage(response));
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  // Get current user
  Future<User> getCurrentUser() async {
    try {
      final response = await _api.get(
        AppConfig.profileEndpoint,
        includeAuth: true,
      );

      if (response.statusCode == 200) {
        final user = User.fromJson(jsonDecode(response.body));
        await _storage.saveUser(user);
        return user;
      } else {
        throw Exception(_api.getErrorMessage(response));
      }
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    await _storage.clearAll();
  }

  // Check if logged in
  bool isLoggedIn() {
    return _storage.isLoggedIn();
  }

  // Get cached user
  User? getCachedUser() {
    return _storage.getUser();
  }
}
