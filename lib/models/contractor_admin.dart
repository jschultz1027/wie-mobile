/// Admin contractor list/detail model. Matches backend ContractorListItem / ContractorDetail.
class AdminContractor {
  final int id;
  final String fullName;
  final String email;
  final String? companyName;
  final String? phone;
  final String? homeBaseCity;
  final String? tierLevel;
  final String? availabilityStatus;
  final int? capacityTodayRemaining;
  final int? capacityNext24hRemaining;
  final List<String>? equipmentTags;
  final String? insuranceStatus;
  final String? courseStatus;
  final String? bankingStatus;
  final double? acceptRate;
  final double? onTimeRate;
  final int? totalJobsCompleted;
  final int? totalJobsAssigned;
  final int activeAssignmentsCount;
  final int upcomingDispatchesCount;

  AdminContractor({
    required this.id,
    required this.fullName,
    required this.email,
    this.companyName,
    this.phone,
    this.homeBaseCity,
    this.tierLevel,
    this.availabilityStatus,
    this.capacityTodayRemaining,
    this.capacityNext24hRemaining,
    this.equipmentTags,
    this.insuranceStatus,
    this.courseStatus,
    this.bankingStatus,
    this.acceptRate,
    this.onTimeRate,
    this.totalJobsCompleted,
    this.totalJobsAssigned,
    this.activeAssignmentsCount = 0,
    this.upcomingDispatchesCount = 0,
  });

  factory AdminContractor.fromJson(Map<String, dynamic> json) {
    List<String>? tags;
    if (json['equipment_tags'] is List) {
      tags = (json['equipment_tags'] as List).map((e) => e.toString()).toList();
    }
    return AdminContractor(
      id: json['id'] as int,
      fullName: json['full_name'] as String? ?? json['email'] as String? ?? '',
      email: json['email'] as String? ?? '',
      companyName: json['company_name'] as String?,
      phone: json['phone'] as String?,
      homeBaseCity: json['home_base_city'] as String?,
      tierLevel: json['tier_level'] as String?,
      availabilityStatus: json['availability_status'] as String?,
      capacityTodayRemaining: json['capacity_today_remaining'] as int?,
      capacityNext24hRemaining: json['capacity_next_24h_remaining'] as int?,
      equipmentTags: tags,
      insuranceStatus: json['insurance_status'] as String?,
      courseStatus: json['course_status'] as String?,
      bankingStatus: json['banking_status'] as String?,
      acceptRate: (json['accept_rate'] as num?)?.toDouble(),
      onTimeRate: (json['on_time_rate'] as num?)?.toDouble(),
      totalJobsCompleted: json['total_jobs_completed'] as int?,
      totalJobsAssigned: json['total_jobs_assigned'] as int?,
      activeAssignmentsCount: json['active_assignments_count'] as int? ?? 0,
      upcomingDispatchesCount: json['upcoming_dispatches_count'] as int? ?? 0,
    );
  }

  bool get isCompliant =>
      insuranceStatus == 'verified' &&
      courseStatus == 'verified' &&
      bankingStatus == 'verified';
}
