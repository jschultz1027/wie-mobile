import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'storage_service.dart';

/// DI Engine (Dispatch Intelligence) API: health, hazard, salt protection, decide.
/// Matches web: /api/dispatch/*, /api/v1/engine/hazard/*, /api/salt/protection/*.
class DispatchService {
  static final DispatchService _instance = DispatchService._internal();
  factory DispatchService() => _instance;
  DispatchService._internal();

  final StorageService _storage = StorageService();
  String get _base => AppConfig.baseUrl;

  Map<String, String> _headers() {
    final m = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    final t = _storage.getToken();
    if (t != null) m['Authorization'] = 'Bearer $t';
    return m;
  }

  /// GET /api/dispatch/health
  Future<DispatchHealthResponse> getHealth() async {
    final r = await http.get(Uri.parse('$_base/api/dispatch/health'), headers: _headers());
    if (r.statusCode != 200) throw Exception('Health check failed: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return DispatchHealthResponse(
      status: d['status'] as String? ?? 'error',
      configuration: d['configuration'] as Map<String, dynamic>?,
      error: d['error'] as String?,
    );
  }

  /// GET /api/v1/engine/hazard/property/{id}/current
  Future<Map<String, dynamic>> getCurrentHazard(int propertyId) async {
    final r = await http.get(
      Uri.parse('$_base/api/v1/engine/hazard/property/$propertyId/current'),
      headers: _headers(),
    );
    if (r.statusCode != 200) throw Exception('Hazard current failed: ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// GET /api/v1/engine/hazard/property/{id}/forecast?hours=48
  Future<dynamic> getHazardForecast(int propertyId, {int hours = 48}) async {
    final r = await http.get(
      Uri.parse('$_base/api/v1/engine/hazard/property/$propertyId/forecast').replace(queryParameters: {'hours': hours.toString()}),
      headers: _headers(),
    );
    if (r.statusCode != 200) throw Exception('Hazard forecast failed: ${r.statusCode}');
    return jsonDecode(r.body);
  }

  /// GET /api/salt/protection/property/{id}?include_zones=true
  Future<Map<String, dynamic>> getSaltProtection(int propertyId, {bool includeZones = true}) async {
    final r = await http.get(
      Uri.parse('$_base/api/salt/protection/property/$propertyId').replace(queryParameters: {'include_zones': includeZones.toString()}),
      headers: _headers(),
    );
    if (r.statusCode != 200) throw Exception('Salt protection failed: ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// POST /api/dispatch/decide
  Future<Map<String, dynamic>> makeDecision(Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$_base/api/dispatch/decide'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception('Dispatch decide failed: ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// GET /api/dispatch/history/{property_id}?limit=10
  Future<List<dynamic>> getHistory(int propertyId, {int limit = 10}) async {
    final r = await http.get(
      Uri.parse('$_base/api/dispatch/history/$propertyId').replace(queryParameters: {'limit': limit.toString()}),
      headers: _headers(),
    );
    if (r.statusCode != 200) throw Exception('Dispatch history failed: ${r.statusCode}');
    final list = jsonDecode(r.body);
    return list is List ? list : [];
  }

  /// GET /api/dispatch/alerts/{property_id}?active_only=true
  Future<List<dynamic>> getAlerts(int propertyId, {bool activeOnly = true}) async {
    final r = await http.get(
      Uri.parse('$_base/api/dispatch/alerts/$propertyId').replace(queryParameters: {'active_only': activeOnly.toString()}),
      headers: _headers(),
    );
    if (r.statusCode != 200) throw Exception('Dispatch alerts failed: ${r.statusCode}');
    final list = jsonDecode(r.body);
    return list is List ? list : [];
  }

  /// GET /api/dispatch/analytics/{property_id}?days=30
  Future<Map<String, dynamic>> getAnalytics(int propertyId, {int days = 30}) async {
    final r = await http.get(
      Uri.parse('$_base/api/dispatch/analytics/$propertyId').replace(queryParameters: {'days': days.toString()}),
      headers: _headers(),
    );
    if (r.statusCode != 200) throw Exception('Dispatch analytics failed: ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// PATCH /api/dispatch/decision/{decision_id}/execute
  Future<void> markDecisionExecuted(int decisionId) async {
    final r = await http.patch(
      Uri.parse('$_base/api/dispatch/decision/$decisionId/execute'),
      headers: _headers(),
    );
    if (r.statusCode != 200) throw Exception('Mark executed failed: ${r.statusCode}');
  }
}

class DispatchHealthResponse {
  final String status;
  final Map<String, dynamic>? configuration;
  final String? error;
  DispatchHealthResponse({required this.status, this.configuration, this.error});
  bool get isOperational => status == 'operational';
}
