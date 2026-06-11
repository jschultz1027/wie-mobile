class PropertyReport {
  final String propertyId;
  final String timestamp;
  final List<SegmentPrediction> segments;
  final ColdStreakStatus coldStreakStatus;
  final double overallRiskScore;
  final List<String> criticalSegments;
  final List<String> recommendedActions;

  PropertyReport({
    required this.propertyId,
    required this.timestamp,
    required this.segments,
    required this.coldStreakStatus,
    required this.overallRiskScore,
    required this.criticalSegments,
    required this.recommendedActions,
  });

  factory PropertyReport.fromJson(Map<String, dynamic> json) {
    return PropertyReport(
      propertyId: json['property_id'] as String,
      timestamp: json['timestamp'] as String,
      segments: (json['segments'] as List)
          .map((s) => SegmentPrediction.fromJson(s as Map<String, dynamic>))
          .toList(),
      coldStreakStatus: ColdStreakStatus.fromJson(json['cold_streak_status'] as Map<String, dynamic>),
      overallRiskScore: (json['overall_risk_score'] as num).toDouble(),
      criticalSegments: (json['critical_segments'] as List).map((s) => s.toString()).toList(),
      recommendedActions: (json['recommended_actions'] as List).map((s) => s.toString()).toList(),
    );
  }
}

class SegmentPrediction {
  final String segmentId;
  final PavementTemp pavementTemp;
  final GroundTemp groundTemp;
  final BlackIceRisk blackIceRisk;
  final double iceRiskScore;
  final SaltingRecommendation saltingRecommendation;

  SegmentPrediction({
    required this.segmentId,
    required this.pavementTemp,
    required this.groundTemp,
    required this.blackIceRisk,
    required this.iceRiskScore,
    required this.saltingRecommendation,
  });

  factory SegmentPrediction.fromJson(Map<String, dynamic> json) {
    return SegmentPrediction(
      segmentId: json['segment_id'] as String,
      pavementTemp: PavementTemp.fromJson(json['pavement_temp'] as Map<String, dynamic>),
      groundTemp: GroundTemp.fromJson(json['ground_temp'] as Map<String, dynamic>),
      blackIceRisk: BlackIceRisk.fromJson(json['black_ice_risk'] as Map<String, dynamic>),
      iceRiskScore: (json['ice_risk_score'] as num).toDouble(),
      saltingRecommendation: SaltingRecommendation.fromJson(json['salting_recommendation'] as Map<String, dynamic>),
    );
  }
}

class PavementTemp {
  final double pavementTemp;

  PavementTemp({required this.pavementTemp});

  factory PavementTemp.fromJson(Map<String, dynamic> json) {
    return PavementTemp(
      pavementTemp: (json['pavement_temp'] as num).toDouble(),
    );
  }
}

class GroundTemp {
  final double soilTemp0cm;

  GroundTemp({required this.soilTemp0cm});

  factory GroundTemp.fromJson(Map<String, dynamic> json) {
    return GroundTemp(
      soilTemp0cm: (json['soil_temp_0cm'] as num).toDouble(),
    );
  }
}

class BlackIceRisk {
  final double blackIceRiskScore;

  BlackIceRisk({required this.blackIceRiskScore});

  factory BlackIceRisk.fromJson(Map<String, dynamic> json) {
    return BlackIceRisk(
      blackIceRiskScore: (json['black_ice_risk_score'] as num).toDouble(),
    );
  }
}

class SaltingRecommendation {
  final double saltNeededScore;
  final String priorityLevel;
  final String? recommendedAmount;
  final List<String> justificationCodes;

  SaltingRecommendation({
    required this.saltNeededScore,
    required this.priorityLevel,
    this.recommendedAmount,
    required this.justificationCodes,
  });

  factory SaltingRecommendation.fromJson(Map<String, dynamic> json) {
    return SaltingRecommendation(
      saltNeededScore: (json['salt_needed_score'] as num).toDouble(),
      priorityLevel: json['priority_level'] as String,
      recommendedAmount: json['recommended_amount']?.toString(),
      justificationCodes: (json['justification_codes'] as List).map((c) => c.toString()).toList(),
    );
  }
}

class ColdStreakStatus {
  final bool active;
  final double? durationHours;
  final double? freezeDepthCm;
  final double? saltingReductionFactor;

  ColdStreakStatus({
    required this.active,
    this.durationHours,
    this.freezeDepthCm,
    this.saltingReductionFactor,
  });

  factory ColdStreakStatus.fromJson(Map<String, dynamic> json) {
    return ColdStreakStatus(
      active: json['active'] as bool,
      durationHours: json['duration_hours'] == null ? null : (json['duration_hours'] as num).toDouble(),
      freezeDepthCm: json['freeze_depth_cm'] == null ? null : (json['freeze_depth_cm'] as num).toDouble(),
      saltingReductionFactor: json['salting_reduction_factor'] == null ? null : (json['salting_reduction_factor'] as num).toDouble(),
    );
  }
}
