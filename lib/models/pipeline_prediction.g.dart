// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pipeline_prediction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroundTemp _$GroundTempFromJson(Map<String, dynamic> json) => GroundTemp(
  soilTemp0cm: (json['soil_temp_0cm'] as num?)?.toDouble(),
  soilTemp5cm: (json['soil_temp_5cm'] as num?)?.toDouble(),
  soilTemp10cm: (json['soil_temp_10cm'] as num?)?.toDouble(),
  soilTemp20cm: (json['soil_temp_20cm'] as num?)?.toDouble(),
  freezeDepthCm: (json['freeze_depth_estimate'] as num?)?.toDouble(),
  confidence: (json['confidence_score'] as num?)?.toDouble(),
);

Map<String, dynamic> _$GroundTempToJson(GroundTemp instance) =>
    <String, dynamic>{
      'soil_temp_0cm': instance.soilTemp0cm,
      'soil_temp_5cm': instance.soilTemp5cm,
      'soil_temp_10cm': instance.soilTemp10cm,
      'soil_temp_20cm': instance.soilTemp20cm,
      'freeze_depth_estimate': instance.freezeDepthCm,
      'confidence_score': instance.confidence,
    };

PavementTemp _$PavementTempFromJson(Map<String, dynamic> json) => PavementTemp(
  pavementTemp: (json['pavement_temp'] as num?)?.toDouble(),
  probBelow0: (json['prob_below_0'] as num?)?.toDouble(),
  probBelowMinus2: (json['prob_below_minus_2'] as num?)?.toDouble(),
  confidence: (json['confidence_score'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PavementTempToJson(PavementTemp instance) =>
    <String, dynamic>{
      'pavement_temp': instance.pavementTemp,
      'prob_below_0': instance.probBelow0,
      'prob_below_minus_2': instance.probBelowMinus2,
      'confidence_score': instance.confidence,
    };

BlackIceRisk _$BlackIceRiskFromJson(Map<String, dynamic> json) => BlackIceRisk(
  riskScore: (json['black_ice_risk_score'] as num?)?.toDouble(),
  spatialFactor: (json['spatial_factor'] as num?)?.toDouble(),
  bridgeLikeFactor: (json['bridge_like_factor'] as num?)?.toDouble(),
  contributingFactors: (json['contributing_factors'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$BlackIceRiskToJson(BlackIceRisk instance) =>
    <String, dynamic>{
      'black_ice_risk_score': instance.riskScore,
      'spatial_factor': instance.spatialFactor,
      'bridge_like_factor': instance.bridgeLikeFactor,
      'contributing_factors': instance.contributingFactors,
    };

IcingTime _$IcingTimeFromJson(Map<String, dynamic> json) => IcingTime(
  minutesUntilIcing: (json['minutes_until_icing'] as num?)?.toDouble(),
  waterDepthMm: (json['water_depth_estimate'] as num?)?.toDouble(),
  conditionsMet: json['icing_conditions_met'] as bool?,
);

Map<String, dynamic> _$IcingTimeToJson(IcingTime instance) => <String, dynamic>{
  'minutes_until_icing': instance.minutesUntilIcing,
  'water_depth_estimate': instance.waterDepthMm,
  'icing_conditions_met': instance.conditionsMet,
};

RefreezeTime _$RefreezeTimeFromJson(Map<String, dynamic> json) => RefreezeTime(
  hoursUntilRefreeze: (json['hours_until_refreeze'] as num?)?.toDouble(),
  conditionsFavorable: json['conditions_favorable'] as bool?,
);

Map<String, dynamic> _$RefreezeTimeToJson(RefreezeTime instance) =>
    <String, dynamic>{
      'hours_until_refreeze': instance.hoursUntilRefreeze,
      'conditions_favorable': instance.conditionsFavorable,
    };

SaltingRecommendation _$SaltingRecommendationFromJson(
  Map<String, dynamic> json,
) => SaltingRecommendation(
  priorityLevel: json['priority_level'] as String?,
  saltNeededScore: (json['salt_needed_score'] as num?)?.toDouble(),
  recommendedAmount: (json['recommended_amount'] as num?)?.toDouble(),
  estimatedEffectiveDuration: (json['estimated_effective_duration'] as num?)
      ?.toDouble(),
  justificationCodes: (json['justification_codes'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SaltingRecommendationToJson(
  SaltingRecommendation instance,
) => <String, dynamic>{
  'priority_level': instance.priorityLevel,
  'salt_needed_score': instance.saltNeededScore,
  'recommended_amount': instance.recommendedAmount,
  'estimated_effective_duration': instance.estimatedEffectiveDuration,
  'justification_codes': instance.justificationCodes,
};

PredictionResult _$PredictionResultFromJson(
  Map<String, dynamic> json,
) => PredictionResult(
  groundTemp: GroundTemp.fromJson(json['ground_temp'] as Map<String, dynamic>),
  pavementTemp: PavementTemp.fromJson(
    json['pavement_temp'] as Map<String, dynamic>,
  ),
  blackIceRisk: BlackIceRisk.fromJson(
    json['black_ice_risk'] as Map<String, dynamic>,
  ),
  iceRiskScore: (json['ice_risk_score'] as num).toDouble(),
  icingTime: json['icing_time'] == null
      ? null
      : IcingTime.fromJson(json['icing_time'] as Map<String, dynamic>),
  saltingRecommendation: SaltingRecommendation.fromJson(
    json['salting_recommendation'] as Map<String, dynamic>,
  ),
  refreezeTime: json['refreeze_time'] == null
      ? null
      : RefreezeTime.fromJson(json['refreeze_time'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PredictionResultToJson(PredictionResult instance) =>
    <String, dynamic>{
      'ground_temp': instance.groundTemp,
      'pavement_temp': instance.pavementTemp,
      'black_ice_risk': instance.blackIceRisk,
      'ice_risk_score': instance.iceRiskScore,
      'icing_time': instance.icingTime,
      'salting_recommendation': instance.saltingRecommendation,
      'refreeze_time': instance.refreezeTime,
    };
