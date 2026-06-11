import 'package:json_annotation/json_annotation.dart';

part 'pipeline_prediction.g.dart';

@JsonSerializable()
class GroundTemp {
  @JsonKey(name: 'soil_temp_0cm')
  final double? soilTemp0cm;
  
  @JsonKey(name: 'soil_temp_5cm')
  final double? soilTemp5cm;
  
  @JsonKey(name: 'soil_temp_10cm')
  final double? soilTemp10cm;
  
  @JsonKey(name: 'soil_temp_20cm')
  final double? soilTemp20cm;
  
  @JsonKey(name: 'freeze_depth_estimate')
  final double? freezeDepthCm;
  
  @JsonKey(name: 'confidence_score')
  final double? confidence;

  GroundTemp({
    this.soilTemp0cm,
    this.soilTemp5cm,
    this.soilTemp10cm,
    this.soilTemp20cm,
    this.freezeDepthCm,
    this.confidence,
  });

  factory GroundTemp.fromJson(Map<String, dynamic> json) => _$GroundTempFromJson(json);
  Map<String, dynamic> toJson() => _$GroundTempToJson(this);
}

@JsonSerializable()
class PavementTemp {
  @JsonKey(name: 'pavement_temp')
  final double? pavementTemp;
  
  @JsonKey(name: 'prob_below_0')
  final double? probBelow0;
  
  @JsonKey(name: 'prob_below_minus_2')
  final double? probBelowMinus2;
  
  @JsonKey(name: 'confidence_score')
  final double? confidence;

  PavementTemp({
    this.pavementTemp,
    this.probBelow0,
    this.probBelowMinus2,
    this.confidence,
  });

  factory PavementTemp.fromJson(Map<String, dynamic> json) => _$PavementTempFromJson(json);
  Map<String, dynamic> toJson() => _$PavementTempToJson(this);
}

@JsonSerializable()
class BlackIceRisk {
  @JsonKey(name: 'black_ice_risk_score')
  final double? riskScore;
  
  @JsonKey(name: 'spatial_factor')
  final double? spatialFactor;
  
  @JsonKey(name: 'bridge_like_factor')
  final double? bridgeLikeFactor;
  
  @JsonKey(name: 'contributing_factors')
  final List<String>? contributingFactors;

  BlackIceRisk({
    this.riskScore,
    this.spatialFactor,
    this.bridgeLikeFactor,
    this.contributingFactors,
  });

  factory BlackIceRisk.fromJson(Map<String, dynamic> json) => _$BlackIceRiskFromJson(json);
  Map<String, dynamic> toJson() => _$BlackIceRiskToJson(this);
}

@JsonSerializable()
class IcingTime {
  @JsonKey(name: 'minutes_until_icing')
  final double? minutesUntilIcing;
  
  @JsonKey(name: 'water_depth_estimate')
  final double? waterDepthMm;
  
  @JsonKey(name: 'icing_conditions_met')
  final bool? conditionsMet;

  IcingTime({
    this.minutesUntilIcing,
    this.waterDepthMm,
    this.conditionsMet,
  });

  factory IcingTime.fromJson(Map<String, dynamic> json) => _$IcingTimeFromJson(json);
  Map<String, dynamic> toJson() => _$IcingTimeToJson(this);
}

@JsonSerializable()
class RefreezeTime {
  @JsonKey(name: 'hours_until_refreeze')
  final double? hoursUntilRefreeze;
  
  @JsonKey(name: 'conditions_favorable')
  final bool? conditionsFavorable;

  RefreezeTime({
    this.hoursUntilRefreeze,
    this.conditionsFavorable,
  });

  factory RefreezeTime.fromJson(Map<String, dynamic> json) => _$RefreezeTimeFromJson(json);
  Map<String, dynamic> toJson() => _$RefreezeTimeToJson(this);
}

@JsonSerializable()
class SaltingRecommendation {
  @JsonKey(name: 'priority_level')
  final String? priorityLevel;
  
  @JsonKey(name: 'salt_needed_score')
  final double? saltNeededScore;
  
  @JsonKey(name: 'recommended_amount')
  final double? recommendedAmount;
  
  @JsonKey(name: 'estimated_effective_duration')
  final double? estimatedEffectiveDuration;
  
  @JsonKey(name: 'justification_codes')
  final List<String>? justificationCodes;

  SaltingRecommendation({
    this.priorityLevel,
    this.saltNeededScore,
    this.recommendedAmount,
    this.estimatedEffectiveDuration,
    this.justificationCodes,
  });

  factory SaltingRecommendation.fromJson(Map<String, dynamic> json) => _$SaltingRecommendationFromJson(json);
  Map<String, dynamic> toJson() => _$SaltingRecommendationToJson(this);
}

@JsonSerializable()
class PredictionResult {
  @JsonKey(name: 'ground_temp')
  final GroundTemp groundTemp;
  
  @JsonKey(name: 'pavement_temp')
  final PavementTemp pavementTemp;
  
  @JsonKey(name: 'black_ice_risk')
  final BlackIceRisk blackIceRisk;
  
  @JsonKey(name: 'ice_risk_score')
  final double iceRiskScore;
  
  @JsonKey(name: 'icing_time')
  final IcingTime? icingTime;
  
  @JsonKey(name: 'salting_recommendation')
  final SaltingRecommendation saltingRecommendation;
  
  @JsonKey(name: 'refreeze_time')
  final RefreezeTime? refreezeTime;

  PredictionResult({
    required this.groundTemp,
    required this.pavementTemp,
    required this.blackIceRisk,
    required this.iceRiskScore,
    this.icingTime,
    required this.saltingRecommendation,
    this.refreezeTime,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) => _$PredictionResultFromJson(json);
  Map<String, dynamic> toJson() => _$PredictionResultToJson(this);
}
