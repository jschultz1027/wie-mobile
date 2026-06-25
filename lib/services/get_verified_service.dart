import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
  Future<VerificationUploadResult> uploadDocument(int verificationId, File file) async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) throw GetVerifiedException('Not authenticated');

    if (!await file.exists()) {
      throw GetVerifiedException('File not found');
    }

    final isPdf = ImageCompression.isPdfPath(file.path);
    final toUpload = isPdf ? file : await ImageCompression.compressPhotoFile(file);
    if (!await toUpload.exists()) {
      throw GetVerifiedException('File not found');
    }

    final bytes = await toUpload.readAsBytes();
    if (bytes.isEmpty) {
      throw GetVerifiedException('File is empty');
    }

    final filename = ImageCompression.uploadFilename(
      toUpload.path,
      fallback: isPdf ? 'document.pdf' : 'document.jpg',
    );
    final contentType = MediaType.parse(ImageCompression.mimeTypeForPath(filename));

    final uri = Uri.parse('$_base/api/v1/contractors/verifications/$verificationId/document');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentType,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) throw GetVerifiedException.unauthorized();
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw GetVerifiedException(
        _parseUploadError(response.statusCode, response.body),
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return VerificationUploadResult(
      documentUrl: decoded['document_url'] as String? ?? '',
      documentName: decoded['document_name'] as String?,
      verificationId: decoded['verification_id'] as int? ?? verificationId,
      status: decoded['status']?.toString() ?? 'pending',
    );
  }

  String _parseUploadError(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return '${first['msg']}';
          }
        }
      }
    } catch (_) {}
    return 'Upload failed: $statusCode';
  }
}

class GetVerifiedException implements Exception {
  final String message;
  final bool isUnauthorized;

  GetVerifiedException(this.message, {this.isUnauthorized = false});
  static GetVerifiedException unauthorized() =>
      GetVerifiedException('Session expired or not authenticated', isUnauthorized: true);
}

class VerificationUploadResult {
  final String documentUrl;
  final String? documentName;
  final int verificationId;
  final String status;

  VerificationUploadResult({
    required this.documentUrl,
    this.documentName,
    required this.verificationId,
    required this.status,
  });
}
