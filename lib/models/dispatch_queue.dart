/// Dispatch queue item. Matches backend DispatchQueueItem.
class DispatchQueueItem {
  final int id;
  final int propertyId;
  final String propertyName;
  final String propertyAddress;
  final String? region;
  final String? projectedDispatchBucket;
  final double? projectedDispatchEtaHours;
  final String? dueBy;
  final String? dispatchStatus;
  final String? workType;
  final double? riskScoreOverall;   // Peak when queue entry was created
  final double? currentRiskScore;    // Live risk now (matches Zone Manager)
  final String? topZoneRisk;
  final double? saltProtectionRemaining;
  final String? lastServiceTime;
  final String? dispatchType; // "initial" or "subsequent"
  final double? currentSaltEffectiveness; // Engine B current protection (0-100)
  final String? assignmentStatus;
  final int? assignedContractorId;
  final String? assignedContractorName;
  final String? assignmentNotes;

  DispatchQueueItem({
    required this.id,
    required this.propertyId,
    required this.propertyName,
    required this.propertyAddress,
    this.region,
    this.projectedDispatchBucket,
    this.projectedDispatchEtaHours,
    this.dueBy,
    this.dispatchStatus,
    this.workType,
    this.riskScoreOverall,
    this.currentRiskScore,
    this.topZoneRisk,
    this.saltProtectionRemaining,
    this.lastServiceTime,
    this.dispatchType,
    this.currentSaltEffectiveness,
    this.assignmentStatus,
    this.assignedContractorId,
    this.assignedContractorName,
    this.assignmentNotes,
  });

  factory DispatchQueueItem.fromJson(Map<String, dynamic> json) {
    return DispatchQueueItem(
      id: json['id'] as int,
      propertyId: json['property_id'] as int,
      propertyName: json['property_name'] as String? ?? '',
      propertyAddress: json['property_address'] as String? ?? '',
      region: json['region'] as String?,
      projectedDispatchBucket: json['projected_dispatch_bucket'] as String?,
      projectedDispatchEtaHours: (json['projected_dispatch_eta_hours'] as num?)?.toDouble(),
      dueBy: json['due_by']?.toString(),
      dispatchStatus: json['dispatch_status'] as String?,
      workType: json['work_type'] as String?,
      riskScoreOverall: (json['risk_score_overall'] as num?)?.toDouble(),
      currentRiskScore: (json['current_risk_score'] as num?)?.toDouble(),
      topZoneRisk: json['top_zone_risk'] as String?,
      saltProtectionRemaining: (json['salt_protection_remaining'] as num?)?.toDouble(),
      lastServiceTime: json['last_service_time']?.toString(),
      dispatchType: json['dispatch_type'] as String?,
      currentSaltEffectiveness: (json['current_salt_effectiveness'] as num?)?.toDouble(),
      assignmentStatus: json['assignment_status'] as String?,
      assignedContractorId: json['assigned_contractor_id'] as int?,
      assignedContractorName: json['assigned_contractor_name'] as String?,
      assignmentNotes: json['assignment_notes'] as String?,
    );
  }
}

/// Bucket counts for queue summary.
class DispatchBucketCounts {
  final int unassigned24h;
  final int unassigned24_48h;
  final int unassigned48_72h;
  final int unassigned3_7d;
  final int totalUnassigned;
  final int totalAssigned;
  final int totalInProgress;

  DispatchBucketCounts({
    this.unassigned24h = 0,
    this.unassigned24_48h = 0,
    this.unassigned48_72h = 0,
    this.unassigned3_7d = 0,
    this.totalUnassigned = 0,
    this.totalAssigned = 0,
    this.totalInProgress = 0,
  });

  factory DispatchBucketCounts.fromJson(Map<String, dynamic> json) {
    return DispatchBucketCounts(
      unassigned24h: json['unassigned_24h'] as int? ?? 0,
      unassigned24_48h: json['unassigned_24_48h'] as int? ?? 0,
      unassigned48_72h: json['unassigned_48_72h'] as int? ?? 0,
      unassigned3_7d: json['unassigned_3_7d'] as int? ?? 0,
      totalUnassigned: json['total_unassigned'] as int? ?? 0,
      totalAssigned: json['total_assigned'] as int? ?? 0,
      totalInProgress: json['total_in_progress'] as int? ?? 0,
    );
  }
}

/// Contractor match for assign modal.
class ContractorMatch {
  final int contractorId;
  final String contractorName;
  final String tierLevel;
  final String availabilityStatus;
  final int capacityTodayRemaining;
  final double matchScore;
  final bool complianceOk;
  final List<String> equipmentMatch;
  final int activeAssignments;
  final int upcomingDispatches;
  final bool isFavorite;
  final int? preferenceLevel;
  final String? favoriteNotes;

  ContractorMatch({
    required this.contractorId,
    required this.contractorName,
    required this.tierLevel,
    required this.availabilityStatus,
    required this.capacityTodayRemaining,
    required this.matchScore,
    required this.complianceOk,
    required this.equipmentMatch,
    required this.activeAssignments,
    required this.upcomingDispatches,
    this.isFavorite = false,
    this.preferenceLevel,
    this.favoriteNotes,
  });

  factory ContractorMatch.fromJson(Map<String, dynamic> json) {
    List<String> eq = [];
    if (json['equipment_match'] is List) {
      eq = (json['equipment_match'] as List).map((e) => e.toString()).toList();
    }
    return ContractorMatch(
      contractorId: json['contractor_id'] as int,
      contractorName: json['contractor_name'] as String? ?? '',
      tierLevel: json['tier_level'] as String? ?? 'novice',
      availabilityStatus: json['availability_status'] as String? ?? 'unknown',
      capacityTodayRemaining: json['capacity_today_remaining'] as int? ?? 0,
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0,
      complianceOk: json['compliance_ok'] as bool? ?? false,
      equipmentMatch: eq,
      activeAssignments: json['active_assignments'] as int? ?? 0,
      upcomingDispatches: json['upcoming_dispatches'] as int? ?? 0,
      isFavorite: json['is_favorite'] as bool? ?? false,
      preferenceLevel: json['preference_level'] as int?,
      favoriteNotes: json['favorite_notes'] as String?,
    );
  }
}
