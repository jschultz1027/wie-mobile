/// Contractor Assignment model. Matches backend API response from /api/v1/contractors/assignments
class ContractorAssignment {
  final int id;
  final int propertyId;
  final String propertyName;
  final String propertyAddress;
  final String? propertyMapImageUrl;
  final double? propertyLatitude;
  final double? propertyLongitude;
  final String serviceType;
  final int priority;
  final double? riskScore;
  final double? protectionLevel;
  final double? residualHazard;
  final int zonesTotal;
  final int zonesCompleted;
  final List<TargetZone> targetZones;
  final String status;
  final String? createdAt;
  final String? scheduledStart;
  final String? actualStart;
  final String? actualEnd;
  final String? instructions;
  final String? contractorNotes;
  final int? estimatedDurationMinutes;

  ContractorAssignment({
    required this.id,
    required this.propertyId,
    required this.propertyName,
    required this.propertyAddress,
    this.propertyMapImageUrl,
    this.propertyLatitude,
    this.propertyLongitude,
    required this.serviceType,
    required this.priority,
    this.riskScore,
    this.protectionLevel,
    this.residualHazard,
    required this.zonesTotal,
    required this.zonesCompleted,
    required this.targetZones,
    required this.status,
    this.createdAt,
    this.scheduledStart,
    this.actualStart,
    this.actualEnd,
    this.instructions,
    this.contractorNotes,
    this.estimatedDurationMinutes,
  });

  // Convenience getters for UI
  /// Maps backend status to UI dispatch status
  /// Backend: pending, assigned, in_progress, completed, cancelled
  /// UI: DISPATCH (active), STANDBY (waiting), MONITORING (completed)
  String get dispatchStatus {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'assigned':
        return 'DISPATCH';
      case 'pending':
        return 'STANDBY';
      case 'completed':
        return 'MONITORING';
      case 'cancelled':
        return 'STANDBY';
      default:
        return status.toUpperCase();
    }
  }
  
  String get protectionLabel {
    if (protectionLevel == null) return 'N/A';
    if (protectionLevel! >= 80) return 'High';
    if (protectionLevel! >= 50) return 'Medium';
    if (protectionLevel! >= 20) return 'Low';
    return 'Minimal';
  }

  /// Calculate urgency hours from scheduled_start
  /// Returns hours until scheduled start, or 999 if no scheduled start
  int get urgencyHours {
    if (scheduledStart == null) return 999;
    try {
      final scheduled = DateTime.parse(scheduledStart!);
      final now = DateTime.now();
      final diff = scheduled.difference(now);
      return diff.inHours.clamp(0, 999);
    } catch (e) {
      return 999;
    }
  }

  factory ContractorAssignment.fromJson(Map<String, dynamic> json) {
    // Parse target zones
    List<TargetZone> zones = [];
    if (json['target_zones'] is List) {
      zones = (json['target_zones'] as List)
          .map((z) => TargetZone.fromJson(z as Map<String, dynamic>))
          .toList();
    }

    return ContractorAssignment(
      id: (json['id'] as num).toInt(),
      propertyId: (json['property_id'] as num).toInt(),
      propertyName: json['property_name'] as String? ?? 'Unknown Property',
      propertyAddress: json['property_address'] as String? ?? '',
      propertyMapImageUrl: json['property_map_image_url'] as String?,
      propertyLatitude: (json['property_latitude'] as num?)?.toDouble(),
      propertyLongitude: (json['property_longitude'] as num?)?.toDouble(),
      serviceType: json['service_type'] as String? ?? 'UNKNOWN',
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      riskScore: (json['risk_score'] as num?)?.toDouble(),
      protectionLevel: (json['protection_level'] as num?)?.toDouble(),
      residualHazard: (json['residual_hazard'] as num?)?.toDouble(),
      zonesTotal: (json['zones_total'] as num?)?.toInt() ?? 0,
      zonesCompleted: (json['zones_completed'] as num?)?.toInt() ?? 0,
      targetZones: zones,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String?,
      scheduledStart: json['scheduled_start'] as String?,
      actualStart: json['actual_start'] as String?,
      actualEnd: json['actual_end'] as String?,
      instructions: json['instructions'] as String?,
      contractorNotes: json['contractor_notes'] as String?,
      estimatedDurationMinutes: (json['estimated_duration_minutes'] as num?)?.toInt(),
    );
  }
}

/// Target zone with completion data
class TargetZone {
  final int zoneId;
  final String? zoneName;
  final String? status; // completed, in_progress, pending
  final String? completedAt;
  final String? beforePhotoUrl;
  final String? afterPhotoUrl;
  final double? arrivalLatitude;
  final double? arrivalLongitude;
  final String? contractorNotes;

  TargetZone({
    required this.zoneId,
    this.zoneName,
    this.status,
    this.completedAt,
    this.beforePhotoUrl,
    this.afterPhotoUrl,
    this.arrivalLatitude,
    this.arrivalLongitude,
    this.contractorNotes,
  });

  factory TargetZone.fromJson(Map<String, dynamic> json) {
    // Backend nests completion: { status, before_photo_url, after_photo_url, ... }
    final comp = json['completion'] as Map<String, dynamic>?;
    return TargetZone(
      zoneId: (json['zone_id'] as num).toInt(),
      zoneName: json['zone_name'] as String?,
      status: comp?['status'] as String? ?? json['status'] as String?,
      completedAt: comp?['completed_at'] as String? ?? json['completed_at'] as String?,
      beforePhotoUrl: comp?['before_photo_url'] as String? ?? json['before_photo_url'] as String?,
      afterPhotoUrl: comp?['after_photo_url'] as String? ?? json['after_photo_url'] as String?,
      arrivalLatitude: (comp?['arrival_latitude'] as num?)?.toDouble() ?? (json['arrival_latitude'] as num?)?.toDouble(),
      arrivalLongitude: (comp?['arrival_longitude'] as num?)?.toDouble() ?? (json['arrival_longitude'] as num?)?.toDouble(),
      contractorNotes: comp?['contractor_notes'] as String? ?? json['contractor_notes'] as String?,
    );
  }
}
