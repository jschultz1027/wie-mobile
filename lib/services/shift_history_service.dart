import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/shift_history.dart';
import '../services/storage_service.dart';

/// Contractor shift history API. Matches web: GET /api/v1/contractors/shifts/history.
class ShiftHistoryService {
  final String _base = AppConfig.baseUrl;

  /// GET /api/v1/contractors/shifts/history?limit=50
  Future<List<ShiftHistoryItem>> getHistory({int limit = 50}) async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) {
      throw ShiftHistoryException('Not authenticated');
    }
    final url = Uri.parse('$_base/api/v1/contractors/shifts/history')
        .replace(queryParameters: {'limit': limit.toString()});
    final r = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    if (r.statusCode == 401) throw ShiftHistoryException.unauthorized();
    if (r.statusCode != 200) {
      throw ShiftHistoryException('Failed to load shift history: ${r.statusCode}');
    }
    final list = jsonDecode(r.body) is List
        ? (jsonDecode(r.body) as List)
            .map((e) => ShiftHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <ShiftHistoryItem>[];
    return list;
  }
}

class ShiftHistoryException implements Exception {
  final String message;
  final bool isUnauthorized;

  ShiftHistoryException(this.message, {this.isUnauthorized = false});
  static ShiftHistoryException unauthorized() =>
      ShiftHistoryException('Session expired or not authenticated',
          isUnauthorized: true);
}
