import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/property.dart';
import '../models/zone_attributes.dart';
import 'storage_service.dart';

/// Zone Manager APIs (properties paginated, map-url, zones, lock, salt events).
/// See docs/ZONE_MANAGER_LOGIC_FOR_FLUTTER.md.
class ZoneManagerService {
  static final ZoneManagerService _instance = ZoneManagerService._internal();
  factory ZoneManagerService() => _instance;
  ZoneManagerService._internal();

  final StorageService _storage = StorageService();
  String get _base => AppConfig.baseUrl;

  Map<String, String> _headers({bool auth = true}) {
    final m = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final t = _storage.getToken();
      if (t != null) m['Authorization'] = 'Bearer $t';
    }
    return m;
  }

  /// GET /api/v1/properties/paginated
  Future<PaginatedPropertiesResponse> getPropertiesPaginated({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool includeRiskData = true,
  }) async {
    final q = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'include_risk_data': includeRiskData.toString(),
    };
    if (search != null && search.isNotEmpty) q['search'] = search;
    final url = Uri.parse('$_base/api/v1/properties/paginated').replace(queryParameters: q);
    final r = await http.get(url, headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to load properties: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final items = (d['items'] as List?)?.map((e) => Property.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    return PaginatedPropertiesResponse(
      items: items,
      total: d['total'] as int? ?? 0,
      page: d['page'] as int? ?? 1,
      pageSize: d['page_size'] as int? ?? pageSize,
      totalPages: d['total_pages'] as int? ?? 1,
    );
  }

  /// GET /api/v1/properties/{id}
  Future<Property> getPropertyById(int id) async {
    final r = await http.get(Uri.parse('$_base/api/v1/properties/$id'), headers: _headers());
    if (r.statusCode != 200) throw Exception('Property not found: ${r.statusCode}');
    return Property.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Fetch map image bytes (for drawing). Uses auth when URL is same-origin.
  Future<List<int>> getMapImageBytes(String mapImageUrl) async {
    final uri = Uri.parse(mapImageUrl);
    final useAuth = mapImageUrl.startsWith(_base);
    final r = await http.get(uri, headers: useAuth ? _headers() : {'Accept': 'image/*'});
    if (r.statusCode != 200) throw Exception('Failed to load map image: ${r.statusCode}');
    return r.bodyBytes;
  }

  /// GET /api/v1/properties/{id}/map-url
  Future<MapUrlResponse> getMapUrl(int propertyId) async {
    final r = await http.get(Uri.parse('$_base/api/v1/properties/$propertyId/map-url'), headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to get map URL: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return MapUrlResponse(mapImageUrl: d['map_image_url'] as String?);
  }

  /// GET /api/v1/properties/{id}/zones
  Future<List<ZoneAttributes>> getZones(int propertyId) async {
    final r = await http.get(Uri.parse('$_base/api/v1/properties/$propertyId/zones'), headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to load zones: ${r.statusCode}');
    final list = jsonDecode(r.body) as List? ?? [];
    return list.map((e) => ZoneAttributes.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/v1/properties/{id}/lock-status
  Future<LockStatusResponse> getLockStatus(int propertyId) async {
    final r = await http.get(Uri.parse('$_base/api/v1/properties/$propertyId/lock-status'), headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to get lock status: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return LockStatusResponse(
      locked: d['locked'] as bool? ?? false,
      lockedBy: d['locked_by'] as String?,
    );
  }

  /// GET /api/v1/properties/{id}/active-assignment
  Future<ActiveAssignmentResponse> getActiveAssignment(int propertyId) async {
    final r = await http.get(Uri.parse('$_base/api/v1/properties/$propertyId/active-assignment'), headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to get active assignment: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return ActiveAssignmentResponse(
      canRecordManually: d['can_record_manually'] as bool? ?? false,
      reason: d['reason'] as String? ?? '',
      hasActiveAssignment: d['has_active_assignment'] as bool? ?? false,
      hasCompletedAssignment: d['has_completed_assignment'] as bool? ?? false,
      contractorName: d['contractor_name'] as String?,
    );
  }

  /// POST /api/v1/properties/{id}/lock or unlock
  Future<LockStatusResponse> lockProperty(int propertyId) async {
    final r = await http.post(Uri.parse('$_base/api/v1/properties/$propertyId/lock'), headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to lock: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return LockStatusResponse(locked: d['locked'] as bool? ?? true, lockedBy: d['locked_by'] as String?);
  }

  Future<LockStatusResponse> unlockProperty(int propertyId) async {
    final r = await http.post(Uri.parse('$_base/api/v1/properties/$propertyId/unlock'), headers: _headers());
    if (r.statusCode != 200) throw Exception('Failed to unlock: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return LockStatusResponse(locked: false, lockedBy: null);
  }

  /// POST /api/v1/properties/{id}/upload-map (multipart)
  Future<MapUrlResponse> uploadMap(int propertyId, List<int> fileBytes, String filename) async {
    final uri = Uri.parse('$_base/api/v1/properties/$propertyId/upload-map');
    final request = http.MultipartRequest('POST', uri);
    final token = _storage.getToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));
    final streamed = await request.send();
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode != 200) throw Exception('Upload failed: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return MapUrlResponse(mapImageUrl: d['map_image_url'] as String?);
  }

  /// POST /api/v1/properties/{id}/zones
  Future<ZoneAttributes> createZone(int propertyId, ZoneAttributes zone) async {
    final r = await http.post(
      Uri.parse('$_base/api/v1/properties/$propertyId/zones'),
      headers: _headers(),
      body: jsonEncode(zone.toJson()),
    );
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception('Failed to create zone: ${r.statusCode}');
    return ZoneAttributes.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// PUT /api/v1/properties/{id}/zones/{zoneId}
  Future<ZoneAttributes> updateZone(int propertyId, int zoneId, ZoneAttributes zone) async {
    final r = await http.put(
      Uri.parse('$_base/api/v1/properties/$propertyId/zones/$zoneId'),
      headers: _headers(),
      body: jsonEncode(zone.toJson()),
    );
    if (r.statusCode != 200) throw Exception('Failed to update zone: ${r.statusCode}');
    return ZoneAttributes.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /api/v1/properties/{id}/zones/{zoneId}
  Future<void> deleteZone(int propertyId, int zoneId) async {
    final r = await http.delete(Uri.parse('$_base/api/v1/properties/$propertyId/zones/$zoneId'), headers: _headers());
    if (r.statusCode != 200 && r.statusCode != 204) throw Exception('Failed to delete zone: ${r.statusCode}');
  }

  /// POST /api/salt/events (no /v1)
  Future<void> createSaltEvent({
    required int siteId,
    required String eventType,
    required String saltType,
    required String applicationAmount,
    List<int>? zonesTreated,
    String? notes,
  }) async {
    final body = {
      'site_id': siteId,
      'event_type': eventType,
      'salt_type': saltType,
      'application_amount': applicationAmount,
      'zones_treated': zonesTreated,
      'notes': notes,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final r = await http.post(
      Uri.parse('$_base/api/salt/events'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception('Failed to record salt event: ${r.statusCode}');
  }
}

class PaginatedPropertiesResponse {
  final List<Property> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  PaginatedPropertiesResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
}

class MapUrlResponse {
  final String? mapImageUrl;
  MapUrlResponse({this.mapImageUrl});
}

class LockStatusResponse {
  final bool locked;
  final String? lockedBy;
  LockStatusResponse({required this.locked, this.lockedBy});
}

class ActiveAssignmentResponse {
  final bool canRecordManually;
  final String reason;
  final bool hasActiveAssignment;
  final bool hasCompletedAssignment;
  final String? contractorName;
  ActiveAssignmentResponse({
    required this.canRecordManually,
    required this.reason,
    required this.hasActiveAssignment,
    required this.hasCompletedAssignment,
    this.contractorName,
  });
}
