/// Shift history item. Matches backend ShiftHistoryItem / ContractorShift.
class ShiftHistoryItem {
  final int shiftId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final String status; // 'active' | 'completed'
  final int totalPropertiesCompleted;
  final int totalZonesCompleted;
  final double totalDistanceKm;

  ShiftHistoryItem({
    required this.shiftId,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.status,
    required this.totalPropertiesCompleted,
    required this.totalZonesCompleted,
    required this.totalDistanceKm,
  });

  factory ShiftHistoryItem.fromJson(Map<String, dynamic> json) {
    return ShiftHistoryItem(
      shiftId: json['shift_id'] as int,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'completed',
      totalPropertiesCompleted:
          (json['total_properties_completed'] as num?)?.toInt() ?? 0,
      totalZonesCompleted:
          (json['total_zones_completed'] as num?)?.toInt() ?? 0,
      totalDistanceKm:
          (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
