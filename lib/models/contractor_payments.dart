/// Contractor payments / earnings. Matches web: /contractor/payments.

class CurrentPeriod {
  final String startDate;
  final String endDate;
  final double totalEarnings;
  final int completedJobs;
  final int pendingJobs;
  final String status; // in_progress | ready_for_payout | paid

  CurrentPeriod({
    required this.startDate,
    required this.endDate,
    required this.totalEarnings,
    required this.completedJobs,
    required this.pendingJobs,
    required this.status,
  });

  factory CurrentPeriod.fromJson(Map<String, dynamic> json) {
    return CurrentPeriod(
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0,
      completedJobs: json['completed_jobs'] as int? ?? 0,
      pendingJobs: json['pending_jobs'] as int? ?? 0,
      status: json['status'] as String? ?? 'in_progress',
    );
  }
}

class PayoutRecord {
  final int id;
  final String periodStart;
  final String periodEnd;
  final double totalAmount;
  final int jobsCount;
  final String paidDate;
  final String paymentMethod;
  final String status; // paid | pending | processing

  PayoutRecord({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.totalAmount,
    required this.jobsCount,
    required this.paidDate,
    required this.paymentMethod,
    required this.status,
  });

  factory PayoutRecord.fromJson(Map<String, dynamic> json) {
    return PayoutRecord(
      id: json['id'] as int? ?? 0,
      periodStart: json['period_start'] as String? ?? '',
      periodEnd: json['period_end'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      jobsCount: json['jobs_count'] as int? ?? 0,
      paidDate: json['paid_date'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'Direct Deposit',
      status: json['status'] as String? ?? 'paid',
    );
  }
}

class ServiceRecord {
  final int id;
  final String date;
  final String propertyName;
  final String serviceType;
  final double amount;
  final String status; // completed | pending | approved

  ServiceRecord({
    required this.id,
    required this.date,
    required this.propertyName,
    required this.serviceType,
    required this.amount,
    required this.status,
  });

  factory ServiceRecord.fromJson(Map<String, dynamic> json) {
    return ServiceRecord(
      id: json['id'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      propertyName: json['property_name'] as String? ?? '',
      serviceType: json['service_type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'completed',
    );
  }
}

class PaymentSummary {
  final CurrentPeriod currentPeriod;
  final List<PayoutRecord> historicalPayouts;
  final List<ServiceRecord> recentServices;

  PaymentSummary({
    required this.currentPeriod,
    required this.historicalPayouts,
    required this.recentServices,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      currentPeriod: CurrentPeriod.fromJson(
        (json['current_period'] as Map<String, dynamic>? ?? {}),
      ),
      historicalPayouts: (json['historical_payouts'] as List<dynamic>?)
              ?.map((e) => PayoutRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentServices: (json['recent_services'] as List<dynamic>?)
              ?.map((e) => ServiceRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
