/// Past service report. Matches web /service-reports example data.
class ServiceReport {
  final int id;
  final String date;
  final String property;
  final String serviceType;
  final String startTime;
  final String endTime;
  final String duration;
  final int crewSize;
  final String materialsUsed;
  final ServiceReportWeather weatherConditions;
  final int photos;
  final String notes;
  final String status; // 'completed' | 'verified'

  ServiceReport({
    required this.id,
    required this.date,
    required this.property,
    required this.serviceType,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.crewSize,
    required this.materialsUsed,
    required this.weatherConditions,
    required this.photos,
    required this.notes,
    required this.status,
  });

  factory ServiceReport.fromJson(Map<String, dynamic> json) {
    return ServiceReport(
      id: json['id'] as int,
      date: json['date'] as String? ?? '',
      property: json['property'] as String? ?? '',
      serviceType: json['service_type'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      crewSize: json['crew_size'] as int? ?? 0,
      materialsUsed: json['materials_used'] as String? ?? '',
      weatherConditions: json['weather_conditions'] != null
          ? ServiceReportWeather.fromJson(
              json['weather_conditions'] as Map<String, dynamic>,
            )
          : ServiceReportWeather(temperature: '', conditions: ''),
      photos: json['photos'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
    );
  }

  bool get isVerified => status == 'verified';
}

class ServiceReportWeather {
  final String temperature;
  final String conditions;

  ServiceReportWeather({
    required this.temperature,
    required this.conditions,
  });

  factory ServiceReportWeather.fromJson(Map<String, dynamic> json) {
    return ServiceReportWeather(
      temperature: json['temperature'] as String? ?? '',
      conditions: json['conditions'] as String? ?? '',
    );
  }
}
