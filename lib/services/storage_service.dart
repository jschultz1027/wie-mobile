import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token management
  Future<void> saveToken(String token) async {
    await _prefs?.setString(AppConfig.tokenKey, token);
  }

  String? getToken() {
    return _prefs?.getString(AppConfig.tokenKey);
  }

  Future<void> removeToken() async {
    await _prefs?.remove(AppConfig.tokenKey);
  }

  // User management
  Future<void> saveUser(User user) async {
    final userJson = jsonEncode(user.toJson());
    await _prefs?.setString(AppConfig.userKey, userJson);
    await _prefs?.setString(AppConfig.userRoleKey, user.role);
  }

  User? getUser() {
    final userJson = _prefs?.getString(AppConfig.userKey);
    if (userJson == null) return null;
    
    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return User.fromJson(userMap);
    } catch (e) {
      return null;
    }
  }

  Future<void> removeUser() async {
    await _prefs?.remove(AppConfig.userKey);
    await _prefs?.remove(AppConfig.userRoleKey);
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return getToken() != null && getUser() != null;
  }

  // Clear all data
  Future<void> clearAll() async {
    await removeToken();
    await removeUser();
  }
}
