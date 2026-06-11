import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/contractor_admin.dart';
import 'storage_service.dart';

/// Admin contractor list/detail API. Matches web: GET /api/v1/admin/contractors.
class ContractorManagementService {
  final StorageService _storage = StorageService();
  String get _base => AppConfig.baseUrl;

  Map<String, String> _headers() {
    final m = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    final t = _storage.getToken();
    if (t != null) m['Authorization'] = 'Bearer $t';
    return m;
  }

  /// GET /api/v1/admin/contractors with optional tier, availability, compliance_ok
  Future<ContractorListResult> getContractors({
    int page = 1,
    int pageSize = 50,
    String? tier,
    String? availability,
    bool? complianceOk,
  }) async {
    final q = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (tier != null && tier.isNotEmpty) q['tier'] = tier;
    if (availability != null && availability.isNotEmpty) q['availability'] = availability;
    if (complianceOk != null) q['compliance_ok'] = complianceOk.toString();

    final r = await http.get(
      Uri.parse('$_base/api/v1/admin/contractors').replace(queryParameters: q),
      headers: _headers(),
    );
    if (r.statusCode == 401) throw ContractorManagementException.unauthorized();
    if (r.statusCode != 200) throw Exception('Contractors failed: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (d['contractors'] as List?)?.map((e) => AdminContractor.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    return ContractorListResult(
      contractors: list,
      total: d['total'] as int? ?? list.length,
      page: d['page'] as int? ?? page,
      pageSize: d['page_size'] as int? ?? pageSize,
    );
  }

  /// GET /api/v1/admin/contractors/{id}
  Future<AdminContractor?> getContractorDetail(int contractorId) async {
    final r = await http.get(
      Uri.parse('$_base/api/v1/admin/contractors/$contractorId'),
      headers: _headers(),
    );
    if (r.statusCode == 404) return null;
    if (r.statusCode == 401) throw ContractorManagementException.unauthorized();
    if (r.statusCode != 200) throw Exception('Contractor detail failed: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return AdminContractor.fromJson(d);
  }
}

class ContractorListResult {
  final List<AdminContractor> contractors;
  final int total;
  final int page;
  final int pageSize;
  ContractorListResult({
    required this.contractors,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}

class ContractorManagementException implements Exception {
  final String message;
  final bool isUnauthorized;
  ContractorManagementException(this.message, {this.isUnauthorized = false});
  static ContractorManagementException unauthorized() =>
      ContractorManagementException('Session expired or not authenticated', isUnauthorized: true);
  @override
  String toString() => message;
}
