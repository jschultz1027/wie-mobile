class WinterHazardResponse {
  final int propertyId;
  final String timestamp;
  final double riskScoreCurrent;
  final String hazardRiskBand;
  final List<ZoneRisk> zoneRiskScores;
  final List<String> riskDrivers;
  final double? airTemperature;
  final double? surfaceTemperature;
  final double? moisturePotential;
  final double? environmentalMultiplier;

  WinterHazardResponse({
    required this.propertyId,
    required this.timestamp,
    required this.riskScoreCurrent,
    required this.hazardRiskBand,
    required this.zoneRiskScores,
    required this.riskDrivers,
    this.airTemperature,
    this.surfaceTemperature,
    this.moisturePotential,
    this.environmentalMultiplier,
  });

  factory WinterHazardResponse.fromJson(Map<String, dynamic> json) {
    return WinterHazardResponse(
      propertyId: json['property_id'] as int,
      timestamp: json['timestamp'] as String,
      riskScoreCurrent: (json['risk_score_current'] as num).toDouble(),
      hazardRiskBand: json['hazard_risk_band'] as String,
      zoneRiskScores: (json['zone_risk_scores'] as List)
          .map((z) => ZoneRisk.fromJson(z as Map<String, dynamic>))
          .toList(),
      riskDrivers: (json['risk_drivers'] as List).map((d) => d.toString()).toList(),
      airTemperature: json['air_temperature'] == null ? null : (json['air_temperature'] as num).toDouble(),
      surfaceTemperature: json['surface_temperature'] == null ? null : (json['surface_temperature'] as num).toDouble(),
      moisturePotential: json['moisture_potential'] == null ? null : (json['moisture_potential'] as num).toDouble(),
      environmentalMultiplier: json['environmental_multiplier'] == null ? null : (json['environmental_multiplier'] as num).toDouble(),
    );
  }
}

class ZoneRisk {
  final int zoneId;
  final String zoneName;
  final double riskScore;
  final String riskBand;
  final String priority;

  ZoneRisk({
    required this.zoneId,
    required this.zoneName,
    required this.riskScore,
    required this.riskBand,
    required this.priority,
  });

  factory ZoneRisk.fromJson(Map<String, dynamic> json) {
    return ZoneRisk(
      zoneId: json['zone_id'] as int,
      zoneName: json['zone_name'] as String,
      riskScore: (json['risk_score'] as num).toDouble(),
      riskBand: json['risk_band'] as String,
      priority: json['priority'] as String,
    );
  }
}

class RiskForecastPoint {
  final int hour;
  final double riskScore;
  final String riskBand;
  final String timestamp;

  RiskForecastPoint({
    required this.hour,
    required this.riskScore,
    required this.riskBand,
    required this.timestamp,
  });

  factory RiskForecastPoint.fromJson(Map<String, dynamic> json) {
    return RiskForecastPoint(
      hour: json['hour'] as int,
      riskScore: (json['risk_score'] as num).toDouble(),
      riskBand: json['risk_band'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}

class ForecastResponse {
  final int propertyId;
  final int forecastHours;
  final List<RiskForecastPoint> riskScoreForecast;
  final int peakRiskHour;
  final double peakRiskScore;
  final String peakRiskBand;

  ForecastResponse({
    required this.propertyId,
    required this.forecastHours,
    required this.riskScoreForecast,
    required this.peakRiskHour,
    required this.peakRiskScore,
    required this.peakRiskBand,
  });

  factory ForecastResponse.fromJson(Map<String, dynamic> json) {
    return ForecastResponse(
      propertyId: json['property_id'] as int,
      forecastHours: json['forecast_hours'] as int,
      riskScoreForecast: (json['risk_score_forecast'] as List)
          .map((p) => RiskForecastPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      peakRiskHour: json['peak_risk_hour'] as int,
      peakRiskScore: (json['peak_risk_score'] as num).toDouble(),
      peakRiskBand: json['peak_risk_band'] as String,
    );
  }
}

class Site {
  final int id;
  final String name;
  final double latitude;
  final double longitude;

  Site({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'] as int,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}
