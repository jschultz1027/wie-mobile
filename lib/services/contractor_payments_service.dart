import '../models/contractor_payments.dart';
import 'storage_service.dart';

/// Contractor payments / earnings. Matches web: /contractor/payments.
/// Uses mock data until backend endpoint exists.
class ContractorPaymentsService {

  Future<PaymentSummary> getSummary() async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) {
      throw ContractorPaymentsException('Not authenticated', isUnauthorized: true);
    }

    // TODO: Replace with actual API when available
    // final r = await http.get(
    //   Uri.parse('$_baseUrl/api/v1/contractors/payments/summary'),
    //   headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    // );
    // if (r.statusCode == 401) throw ContractorPaymentsException.unauthorized();
    // if (r.statusCode != 200) throw ContractorPaymentsException('Failed to load');
    // return PaymentSummary.fromJson(jsonDecode(r.body) as Map<String, dynamic>);

    return getMockSummary();
  }

  /// Mock data matching web /contractor/payments.
  static PaymentSummary getMockSummary() {
    return PaymentSummary.fromJson({
      'current_period': {
        'start_date': '2026-01-01',
        'end_date': '2026-01-31',
        'total_earnings': 2450.00,
        'completed_jobs': 12,
        'pending_jobs': 3,
        'status': 'in_progress',
      },
      'historical_payouts': [
        {
          'id': 1,
          'period_start': '2025-12-01',
          'period_end': '2025-12-31',
          'total_amount': 3200.00,
          'jobs_count': 15,
          'paid_date': '2026-01-05',
          'payment_method': 'Direct Deposit',
          'status': 'paid',
        },
        {
          'id': 2,
          'period_start': '2025-11-01',
          'period_end': '2025-11-30',
          'total_amount': 2890.00,
          'jobs_count': 14,
          'paid_date': '2025-12-05',
          'payment_method': 'Direct Deposit',
          'status': 'paid',
        },
        {
          'id': 3,
          'period_start': '2025-10-01',
          'period_end': '2025-10-31',
          'total_amount': 2650.00,
          'jobs_count': 13,
          'paid_date': '2025-11-05',
          'payment_method': 'Direct Deposit',
          'status': 'paid',
        },
      ],
      'recent_services': [
        {
          'id': 1,
          'date': '2026-01-06',
          'property_name': 'Downtown Plaza',
          'service_type': 'Salt Application',
          'amount': 150.00,
          'status': 'completed',
        },
        {
          'id': 2,
          'date': '2026-01-05',
          'property_name': 'North Mall Parking',
          'service_type': 'Snow Removal + Salt',
          'amount': 280.00,
          'status': 'completed',
        },
        {
          'id': 3,
          'date': '2026-01-04',
          'property_name': 'West Side Complex',
          'service_type': 'Salt Application',
          'amount': 120.00,
          'status': 'approved',
        },
      ],
    });
  }
}

class ContractorPaymentsException implements Exception {
  final String message;
  final bool isUnauthorized;

  ContractorPaymentsException(this.message, {this.isUnauthorized = false});

  static ContractorPaymentsException unauthorized() =>
      ContractorPaymentsException('Session expired or not authenticated', isUnauthorized: true);
}
