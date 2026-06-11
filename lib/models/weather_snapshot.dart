class WeatherSnapshot {
  final double lat;
  final double lon;
  final String timestamp;
  final double airTempC;
  final Map<String, double?> airTempRaw;
  final double dewpointC;
  final Map<String, double?> dewpointRaw;
  final double? wetBulbC;
  final String precipType;
  final Map<String, dynamic> precipTypeRaw;
  final double precipRateMmh;
  final Map<String, double?> precipRateRaw;
  final double? cloudCoverPct;
  final Map<String, double?>? cloudCoverRaw;
  final double? windSpeedMs;
  final double? windGustMs;
  final double tempPlus2hC;
  final Map<String, double?> tempPlus2hRaw;
  final Map<String, String> sourceTimestamps;

  WeatherSnapshot({
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.airTempC,
    required this.airTempRaw,
    required this.dewpointC,
    required this.dewpointRaw,
    this.wetBulbC,
    required this.precipType,
    required this.precipTypeRaw,
    required this.precipRateMmh,
    required this.precipRateRaw,
    this.cloudCoverPct,
    this.cloudCoverRaw,
    this.windSpeedMs,
    this.windGustMs,
    required this.tempPlus2hC,
    required this.tempPlus2hRaw,
    required this.sourceTimestamps,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      timestamp: json['timestamp'] as String,
      airTempC: (json['air_temp_c'] as num).toDouble(),
      airTempRaw: Map<String, double?>.from(
        (json['air_temp_raw'] as Map).map(
          (k, v) => MapEntry(k.toString(), v == null ? null : (v as num).toDouble()),
        ),
      ),
      dewpointC: (json['dewpoint_c'] as num).toDouble(),
      dewpointRaw: Map<String, double?>.from(
        (json['dewpoint_raw'] as Map).map(
          (k, v) => MapEntry(k.toString(), v == null ? null : (v as num).toDouble()),
        ),
      ),
      wetBulbC: json['wet_bulb_c'] == null ? null : (json['wet_bulb_c'] as num).toDouble(),
      precipType: json['precip_type'] as String,
      precipTypeRaw: Map<String, dynamic>.from(json['precip_type_raw'] as Map),
      precipRateMmh: (json['precip_rate_mmh'] as num).toDouble(),
      precipRateRaw: Map<String, double?>.from(
        (json['precip_rate_raw'] as Map).map(
          (k, v) => MapEntry(k.toString(), v == null ? null : (v as num).toDouble()),
        ),
      ),
      cloudCoverPct: json['cloud_cover_pct'] == null ? null : (json['cloud_cover_pct'] as num).toDouble(),
      cloudCoverRaw: json['cloud_cover_raw'] == null
          ? null
          : Map<String, double?>.from(
              (json['cloud_cover_raw'] as Map).map(
                (k, v) => MapEntry(k.toString(), v == null ? null : (v as num).toDouble()),
              ),
            ),
      windSpeedMs: json['wind_speed_ms'] == null ? null : (json['wind_speed_ms'] as num).toDouble(),
      windGustMs: json['wind_gust_ms'] == null ? null : (json['wind_gust_ms'] as num).toDouble(),
      tempPlus2hC: (json['temp_plus_2h_c'] as num).toDouble(),
      tempPlus2hRaw: Map<String, double?>.from(
        (json['temp_plus_2h_raw'] as Map).map(
          (k, v) => MapEntry(k.toString(), v == null ? null : (v as num).toDouble()),
        ),
      ),
      sourceTimestamps: Map<String, String>.from(
        (json['source_timestamps'] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      ),
    );
  }
}

class SoilSnapshot {
  final double lat;
  final double lon;
  final String timestamp;
  final double soilTempShallowC;
  final Map<String, double?> soilTempRaw;
  final double? soilTemp10To40cmC;
  final double? soilTemp40To100cmC;
  final Map<String, String> sourceTimestamps;

  SoilSnapshot({
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.soilTempShallowC,
    required this.soilTempRaw,
    this.soilTemp10To40cmC,
    this.soilTemp40To100cmC,
    required this.sourceTimestamps,
  });

  factory SoilSnapshot.fromJson(Map<String, dynamic> json) {
    return SoilSnapshot(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      timestamp: json['timestamp'] as String,
      soilTempShallowC: (json['soil_temp_shallow_c'] as num).toDouble(),
      soilTempRaw: Map<String, double?>.from(
        (json['soil_temp_raw'] as Map).map(
          (k, v) => MapEntry(k.toString(), v == null ? null : (v as num).toDouble()),
        ),
      ),
      soilTemp10To40cmC: json['soil_temp_10_to_40cm_c'] == null
          ? null
          : (json['soil_temp_10_to_40cm_c'] as num).toDouble(),
      soilTemp40To100cmC: json['soil_temp_40_to_100cm_c'] == null
          ? null
          : (json['soil_temp_40_to_100cm_c'] as num).toDouble(),
      sourceTimestamps: Map<String, String>.from(
        (json['source_timestamps'] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      ),
    );
  }
}

class HazardInput {
  final WeatherSnapshot weather;
  final SoilSnapshot soil;

  HazardInput({
    required this.weather,
    required this.soil,
  });

  factory HazardInput.fromJson(Map<String, dynamic> json) {
    return HazardInput(
      weather: WeatherSnapshot.fromJson(json['weather'] as Map<String, dynamic>),
      soil: SoilSnapshot.fromJson(json['soil'] as Map<String, dynamic>),
    );
  }
}
