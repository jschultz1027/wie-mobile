import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/contractor_assignment.dart';
import 'storage_service.dart';

/// Service for fetching contractor assignments
class ContractorAssignmentService {
  static const String _baseUrl = AppConfig.baseUrl;

  Future<List<ContractorAssignment>> getAssignments({String? status}) async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) {
      throw ContractorAssignmentException('Not authenticated', isUnauthorized: true);
    }

    final queryParams = status != null ? '?status=$status' : '';
    final url = Uri.parse('$_baseUrl/api/v1/contractors/assignments$queryParams');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      throw ContractorAssignmentException('Unauthorized', isUnauthorized: true);
    }

    if (response.statusCode != 200) {
      throw ContractorAssignmentException(
        'Failed to load assignments: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final assignments = data['assignments'] as List<dynamic>? ?? [];
    
    return assignments
        .map((a) => ContractorAssignment.fromJson(a as Map<String, dynamic>))
        .toList();
  }
}

class ContractorAssignmentException implements Exception {
  final String message;
  final bool isUnauthorized;

  ContractorAssignmentException(this.message, {this.isUnauthorized = false});

  @override
  String toString() => message;
}
