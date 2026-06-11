/// Single verification item from GET /api/v1/contractors/verifications.
/// Types: insurance, driver_license_front, driver_license_back, reference_1, reference_2, void_cheque
class VerificationItem {
  final int id;
  final String verificationType;
  final String status; // missing, pending, approved, rejected
  final String? documentUrl;
  final String? documentName;
  final String? referenceName;
  final String? referenceCompany;
  final String? referencePhone;
  final String? referenceEmail;
  final String? referenceRelationship;
  final String? rejectionReason;
  final String? createdAt;
  final String? updatedAt;

  VerificationItem({
    required this.id,
    required this.verificationType,
    required this.status,
    this.documentUrl,
    this.documentName,
    this.referenceName,
    this.referenceCompany,
    this.referencePhone,
    this.referenceEmail,
    this.referenceRelationship,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  factory VerificationItem.fromJson(Map<String, dynamic> json) {
    return VerificationItem(
      id: json['id'] as int,
      verificationType: (json['verification_type'] as String? ?? '').toString(),
      status: (json['status'] as String? ?? 'missing').toString().toLowerCase(),
      documentUrl: json['document_url'] as String?,
      documentName: json['document_name'] as String?,
      referenceName: json['reference_name'] as String?,
      referenceCompany: json['reference_company'] as String?,
      referencePhone: json['reference_phone'] as String?,
      referenceEmail: json['reference_email'] as String?,
      referenceRelationship: json['reference_relationship'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  String get displayType {
    switch (verificationType) {
      case 'insurance':
        return 'Insurance';
      case 'driver_license_front':
        return 'Driver License (Front)';
      case 'driver_license_back':
        return 'Driver License (Back)';
      case 'reference_1':
        return 'Reference 1';
      case 'reference_2':
        return 'Reference 2';
      case 'void_cheque':
        return 'Void Cheque';
      default:
        return verificationType;
    }
  }
}
