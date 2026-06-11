class ZoneRisk {
  final int zoneId;
  final String zoneName;
  final double riskScore;

  ZoneRisk({
    required this.zoneId,
    required this.zoneName,
    required this.riskScore,
  });

  factory ZoneRisk.fromJson(Map<String, dynamic> json) {
    return ZoneRisk(
      zoneId: json['zone_id'] as int,
      zoneName: json['zone_name'] as String,
      riskScore: (json['risk_score'] as num).toDouble(),
    );
  }
}

class RiskDataPoint {
  final String timestamp;
  final int propertyId;
  final String propertyName;
  final double riskScore;
  final double protection;
  final double residual;
  final List<ZoneRisk> zoneRisks;
  final String decisionType;
  final String triggerReason;

  RiskDataPoint({
    required this.timestamp,
    required this.propertyId,
    required this.propertyName,
    required this.riskScore,
    required this.protection,
    required this.residual,
    required this.zoneRisks,
    required this.decisionType,
    required this.triggerReason,
  });

  factory RiskDataPoint.fromJson(Map<String, dynamic> json) {
    return RiskDataPoint(
      timestamp: json['timestamp'] as String,
      propertyId: json['property_id'] as int,
      propertyName: json['property_name'] as String,
      riskScore: (json['risk_score'] as num).toDouble(),
      protection: (json['protection'] as num).toDouble(),
      residual: (json['residual'] as num).toDouble(),
      zoneRisks: (json['zone_risks'] as List?)
          ?.map((z) => ZoneRisk.fromJson(z as Map<String, dynamic>))
          .toList() ?? [],
      decisionType: json['decision_type'] as String? ?? '',
      triggerReason: json['trigger_reason'] as String? ?? '',
    );
  }
}

class HistoricalRiskData {
  final int propertyId;
  final String propertyName;
  final String dateFrom;
  final String dateTo;
  final List<RiskDataPoint> dataPoints;
  final int totalPoints;

  HistoricalRiskData({
    required this.propertyId,
    required this.propertyName,
    required this.dateFrom,
    required this.dateTo,
    required this.dataPoints,
    required this.totalPoints,
  });

  factory HistoricalRiskData.fromJson(Map<String, dynamic> json) {
    return HistoricalRiskData(
      propertyId: json['property_id'] as int,
      propertyName: json['property_name'] as String,
      dateFrom: json['date_from'] as String,
      dateTo: json['date_to'] as String,
      dataPoints: (json['data_points'] as List?)
          ?.map((d) => RiskDataPoint.fromJson(d as Map<String, dynamic>))
          .toList() ?? [],
      totalPoints: json['total_points'] as int,
    );
  }
}

class DailySummary {
  final int propertyId;
  final String propertyName;
  final String date;
  final bool dataAvailable;
  final int? dataPoints;
  final double? peakRisk;
  final double? averageRisk;
  final double? peakResidual;
  final int? hoursHighRisk;
  final int? hoursCriticalRisk;
  final bool? serviceNeeded;
  final int? dispatchActions;
  final String? recommendation;
  final String? message;

  DailySummary({
    required this.propertyId,
    required this.propertyName,
    required this.date,
    required this.dataAvailable,
    this.dataPoints,
    this.peakRisk,
    this.averageRisk,
    this.peakResidual,
    this.hoursHighRisk,
    this.hoursCriticalRisk,
    this.serviceNeeded,
    this.dispatchActions,
    this.recommendation,
    this.message,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      propertyId: json['property_id'] as int,
      propertyName: json['property_name'] as String,
      date: json['date'] as String,
      dataAvailable: json['data_available'] as bool,
      dataPoints: json['data_points'] as int?,
      peakRisk: (json['peak_risk'] as num?)?.toDouble(),
      averageRisk: (json['average_risk'] as num?)?.toDouble(),
      peakResidual: (json['peak_residual'] as num?)?.toDouble(),
      hoursHighRisk: json['hours_high_risk'] as int?,
      hoursCriticalRisk: json['hours_critical_risk'] as int?,
      serviceNeeded: json['service_needed'] as bool?,
      dispatchActions: json['dispatch_actions'] as int?,
      recommendation: json['recommendation'] as String?,
      message: json['message'] as String?,
    );
  }
}
