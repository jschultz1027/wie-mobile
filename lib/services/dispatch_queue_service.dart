import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/dispatch_queue.dart';
import 'storage_service.dart';

/// Admin dispatch queue API. Matches web: /api/v1/admin/dispatch-queue, assign, unassign, contractor-matches.
class DispatchQueueService {
  final StorageService _storage = StorageService();
  String get _base => AppConfig.baseUrl;

  Map<String, String> _headers() {
    final m = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    final t = _storage.getToken();
    if (t != null) m['Authorization'] = 'Bearer $t';
    return m;
  }

  /// GET /api/v1/admin/dispatch-queue
  Future<DispatchQueueResult> getDispatchQueue({
    int page = 1,
    int pageSize = 50,
    String? assignmentStatus,
    String? bucket,
    String? workType,
  }) async {
    final q = <String, String>{'page': page.toString(), 'page_size': pageSize.toString()};
    if (assignmentStatus != null && assignmentStatus.isNotEmpty) q['assignment_status'] = assignmentStatus;
    if (bucket != null && bucket.isNotEmpty) q['bucket'] = bucket;
    if (workType != null && workType.isNotEmpty) q['work_type'] = workType;

    final r = await http.get(
      Uri.parse('$_base/api/v1/admin/dispatch-queue').replace(queryParameters: q),
      headers: _headers(),
    );
    if (r.statusCode == 401) throw DispatchQueueException.unauthorized();
    if (r.statusCode != 200) throw Exception('Dispatch queue failed: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (d['dispatches'] as List?)?.map((e) => DispatchQueueItem.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    final counts = d['bucket_counts'] != null ? DispatchBucketCounts.fromJson(d['bucket_counts'] as Map<String, dynamic>) : DispatchBucketCounts();
    return DispatchQueueResult(
      dispatches: list,
      bucketCounts: counts,
      total: d['total'] as int? ?? list.length,
      page: d['page'] as int? ?? page,
      pageSize: d['page_size'] as int? ?? pageSize,
    );
  }

  /// GET /api/v1/admin/dispatch/{id}/contractor-matches
  Future<List<ContractorMatch>> getContractorMatches(int dispatchId) async {
    final r = await http.get(
      Uri.parse('$_base/api/v1/admin/dispatch/$dispatchId/contractor-matches'),
      headers: _headers(),
    );
    if (r.statusCode == 401) throw DispatchQueueException.unauthorized();
    if (r.statusCode != 200) throw Exception('Contractor matches failed: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (d['matches'] as List?)?.map((e) => ContractorMatch.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    return list;
  }

  /// POST /api/v1/admin/dispatch/{id}/assign body: { contractor_id: number }
  Future<void> assignContractor(int dispatchId, int contractorId) async {
    final r = await http.post(
      Uri.parse('$_base/api/v1/admin/dispatch/$dispatchId/assign'),
      headers: _headers(),
      body: jsonEncode({'contractor_id': contractorId}),
    );
    if (r.statusCode == 401) throw DispatchQueueException.unauthorized();
    if (r.statusCode != 200) throw Exception('Assign failed: ${r.statusCode}');
  }

  /// POST /api/v1/admin/dispatch/{id}/unassign body: {}
  Future<void> unassignContractor(int dispatchId) async {
    final r = await http.post(
      Uri.parse('$_base/api/v1/admin/dispatch/$dispatchId/unassign'),
      headers: _headers(),
      body: jsonEncode({}),
    );
    if (r.statusCode == 401) throw DispatchQueueException.unauthorized();
    if (r.statusCode != 200) throw Exception('Unassign failed: ${r.statusCode}');
  }
}

class DispatchQueueResult {
  final List<DispatchQueueItem> dispatches;
  final DispatchBucketCounts bucketCounts;
  final int total;
  final int page;
  final int pageSize;
  DispatchQueueResult({
    required this.dispatches,
    required this.bucketCounts,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}

class DispatchQueueException implements Exception {
  final String message;
  final bool isUnauthorized;
  DispatchQueueException(this.message, {this.isUnauthorized = false});
  static DispatchQueueException unauthorized() =>
      DispatchQueueException('Session expired or not authenticated', isUnauthorized: true);
  @override
  String toString() => message;
}
