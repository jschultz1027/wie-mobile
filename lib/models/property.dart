class Property {
  final int id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? city;
  final String? province;
  final String? postalCode;
  /// Current risk (0–100), from API when include_risk_data=true
  final int? riskScore;
  /// Peak risk next 24h (0–100)
  final int? highest24h;
  /// Peak risk next 48h (0–100)
  final int? highest48h;
  /// Highest risk in last 7 days (0–100)
  final int? highest7days;
  /// Highest zone risk (0–100), from API when include_risk_data=true
  final int? highestZoneRisk;
  /// Salt protection / effectiveness (0–100), from API when include_risk_data=true
  final int? saltEffectiveness;

  Property({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.city,
    this.province,
    this.postalCode,
    this.riskScore,
    this.highest24h,
    this.highest48h,
    this.highest7days,
    this.highestZoneRisk,
    this.saltEffectiveness,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      city: json['city'] as String?,
      province: json['province'] as String?,
      postalCode: json['postal_code'] as String?,
      riskScore: (json['risk_score'] as num?)?.toInt(),
      highest24h: (json['highest_24h'] as num?)?.toInt(),
      highest48h: (json['highest_48h'] as num?)?.toInt(),
      highest7days: (json['highest_7days'] as num?)?.toInt(),
      highestZoneRisk: (json['highest_zone_risk'] as num?)?.toInt(),
      saltEffectiveness: (json['salt_effectiveness'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      if (riskScore != null) 'risk_score': riskScore,
      if (highest24h != null) 'highest_24h': highest24h,
      if (highest48h != null) 'highest_48h': highest48h,
      if (highest7days != null) 'highest_7days': highest7days,
      if (highestZoneRisk != null) 'highest_zone_risk': highestZoneRisk,
      if (saltEffectiveness != null) 'salt_effectiveness': saltEffectiveness,
    };
  }

  /// True if any risk/protection metric is available (for showing risk summary UI).
  bool get hasRiskData =>
      riskScore != null ||
      highest24h != null ||
      highest48h != null ||
      highest7days != null ||
      highestZoneRisk != null ||
      saltEffectiveness != null;
}
