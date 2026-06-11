import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/my_level.dart';
import '../services/storage_service.dart';

/// Contractor level API. GET /api/v1/contractors/level (tier 1–5 + stats).
class MyLevelService {
  final String _base = AppConfig.baseUrl;

  /// GET /api/v1/contractors/level. Returns tier and performance stats.
  /// Throws [MyLevelException] with [isUnauthorized] for 401, or message for 403/other.
  Future<ContractorLevelResponse> getMyLevel() async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) {
      throw MyLevelException('Not authenticated');
    }
    final r = await http.get(
      Uri.parse('$_base/api/v1/contractors/level'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    if (r.statusCode == 401) throw MyLevelException.unauthorized();
    if (r.statusCode == 403) {
      throw MyLevelException(
        'This page is for contractors. Sign in as a contractor to see your tier and stats.',
      );
    }
    if (r.statusCode != 200) {
      throw MyLevelException('Failed to load level: ${r.statusCode}');
    }
    final map = jsonDecode(r.body) as Map<String, dynamic>;
    return ContractorLevelResponse.fromJson(map);
  }
}

class MyLevelException implements Exception {
  final String message;
  final bool isUnauthorized;

  MyLevelException(this.message, {this.isUnauthorized = false});
  static MyLevelException unauthorized() => MyLevelException(
        'Session expired or not authenticated',
        isUnauthorized: true,
      );
}
