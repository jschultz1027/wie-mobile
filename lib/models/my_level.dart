/// Contractor tier definition (matches web: Starter, Standard, Reliable, Pro, Elite).
class LevelDefinition {
  final int id;
  final String name;
  final int tier;
  final String serviceRangeLabel; // e.g. "0–99 completed services" or "Top 5–10% network"
  final String payoutMultiplier;   // e.g. "1.00", "1.03", "1.15–1.20"
  final List<String> access;
  final List<String> requirements;

  const LevelDefinition({
    required this.id,
    required this.name,
    required this.tier,
    required this.serviceRangeLabel,
    required this.payoutMultiplier,
    required this.access,
    required this.requirements,
  });
}

/// Response from GET /api/v1/contractors/level (tier 1–5 and performance stats).
class ContractorLevelResponse {
  final int tier;
  final String tierName;
  final int completedServices;
  final double onTimeRate;
  final double completionRate;
  final double reportCompliance;
  final double qualityScore;
  final int incidentCount;
  final double declineRate;
  final double siteStabilityScore;
  final double reworkRate;

  ContractorLevelResponse({
    required this.tier,
    required this.tierName,
    required this.completedServices,
    required this.onTimeRate,
    required this.completionRate,
    required this.reportCompliance,
    required this.qualityScore,
    required this.incidentCount,
    required this.declineRate,
    required this.siteStabilityScore,
    required this.reworkRate,
  });

  factory ContractorLevelResponse.fromJson(Map<String, dynamic> json) {
    return ContractorLevelResponse(
      tier: (json['tier'] as num?)?.toInt() ?? 1,
      tierName: json['tier_name'] as String? ?? 'Starter',
      completedServices: (json['completed_services'] as num?)?.toInt() ?? 0,
      onTimeRate: (json['on_time_rate'] as num?)?.toDouble() ?? 0.0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 100.0,
      reportCompliance: (json['report_compliance'] as num?)?.toDouble() ?? 0.0,
      qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 0.0,
      incidentCount: (json['incident_count'] as num?)?.toInt() ?? 0,
      declineRate: (json['decline_rate'] as num?)?.toDouble() ?? 0.0,
      siteStabilityScore: (json['site_stability_score'] as num?)?.toDouble() ?? 0.0,
      reworkRate: (json['rework_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
