import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../config/app_config.dart';
import '../models/get_verified.dart';
import '../services/storage_service.dart';
import '../utils/image_compression.dart';

/// Contractor verifications API. GET/POST /api/v1/contractors/verifications, upload document.
class GetVerifiedService {
  final String _base = AppConfig.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) throw GetVerifiedException('Not authenticated');
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  /// GET /api/v1/contractors/verifications
  Future<List<VerificationItem>> getVerifications() async {
    final headers = await _headers();
    headers['Content-Type'] = 'application/json';
    final r = await http.get(
      Uri.parse('$_base/api/v1/contractors/verifications'),
      headers: headers,
    );
    if (r.statusCode == 401) throw GetVerifiedException.unauthorized();
    if (r.statusCode != 200) throw GetVerifiedException('Failed to load verifications: ${r.statusCode}');
    final list = jsonDecode(r.body) is List
        ? (jsonDecode(r.body) as List)
            .map((e) => VerificationItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <VerificationItem>[];
    return list;
  }

  /// POST /api/v1/contractors/verifications
  Future<VerificationItem> submitVerification({
    required String verificationType,
    String? referenceName,
    String? referenceCompany,
    String? referencePhone,
    String? referenceEmail,
    String? referenceRelationship,
    String? bankingData,
  }) async {
    final headers = await _headers();
    headers['Content-Type'] = 'application/json';
    final body = <String, dynamic>{
      'verification_type': verificationType,
    };
    if (referenceName != null) body['reference_name'] = referenceName;
    if (referenceCompany != null) body['reference_company'] = referenceCompany;
    if (referencePhone != null) body['reference_phone'] = referencePhone;
    if (referenceEmail != null) body['reference_email'] = referenceEmail;
    if (referenceRelationship != null) body['reference_relationship'] = referenceRelationship;
    if (bankingData != null) body['banking_data'] = bankingData;

    final r = await http.post(
      Uri.parse('$_base/api/v1/contractors/verifications'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (r.statusCode == 401) throw GetVerifiedException.unauthorized();
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw GetVerifiedException('Submit failed: ${r.statusCode} ${r.body}');
    }
    return VerificationItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// POST /api/v1/contractors/verifications/{id}/document (multipart file)
  Future<void> uploadDocument(int verificationId, File file) async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) throw GetVerifiedException('Not authenticated');

    final toUpload = await ImageCompression.compressPhotoFile(file);

    final uri = Uri.parse('$_base/api/v1/contractors/verifications/$verificationId/document');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        toUpload.path,
        filename: ImageCompression.isImagePath(toUpload.path)
            ? 'document.jpg'
            : toUpload.path.split(RegExp(r'[/\\]')).last,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) throw GetVerifiedException.unauthorized();
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw GetVerifiedException('Upload failed: ${response.statusCode} ${response.body}');
    }
  }
}

class GetVerifiedException implements Exception {
  final String message;
  final bool isUnauthorized;

  GetVerifiedException(this.message, {this.isUnauthorized = false});
  static GetVerifiedException unauthorized() =>
      GetVerifiedException('Session expired or not authenticated', isUnauthorized: true);
}
