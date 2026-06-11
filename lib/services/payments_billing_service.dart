import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/payments_billing.dart';
import 'storage_service.dart';

/// Client payments & billing API. Matches web /payments-billing.
/// Backend: GET /api/v1/invoices/client/{client_id}, GET /api/v1/invoices/{id}.
class PaymentsBillingService {
  final StorageService _storage = StorageService();
  String get _base => AppConfig.baseUrl;

  Map<String, String> _headers() {
    final m = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    final t = _storage.getToken();
    if (t != null) m['Authorization'] = 'Bearer $t';
    return m;
  }

  /// GET /api/v1/invoices/client/{client_id}
  Future<List<ClientInvoice>> getClientInvoices(int clientId, {String? status}) async {
    final url = status != null && status.isNotEmpty
        ? '$_base/api/v1/invoices/client/$clientId?status=$status'
        : '$_base/api/v1/invoices/client/$clientId';
    final r = await http.get(Uri.parse(url), headers: _headers());
    if (r.statusCode == 401) throw PaymentsBillingException.unauthorized();
    if (r.statusCode == 404) return [];
    if (r.statusCode != 200) throw Exception('Invoices failed: ${r.statusCode}');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (d['invoices'] as List?)?.map((e) => ClientInvoice.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    return list;
  }

  /// GET /api/v1/invoices/{invoice_id} - for details / download placeholder
  Future<Map<String, dynamic>?> getInvoiceDetails(int invoiceId) async {
    final r = await http.get(
      Uri.parse('$_base/api/v1/invoices/$invoiceId'),
      headers: _headers(),
    );
    if (r.statusCode == 401) throw PaymentsBillingException.unauthorized();
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw Exception('Invoice details failed: ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Example invoices matching web /payments-billing.
  static List<ClientInvoice> getMockInvoices() {
    return [
      ClientInvoice(
        id: 1,
        invoiceNumber: 'INV-2026-001',
        status: 'paid',
        total: 2450.00,
        issuedDate: '2026-01-01',
        dueDate: '2026-01-15',
        servicePeriod: 'December 2025',
        description: 'Snow removal services - 8 service calls',
      ),
      ClientInvoice(
        id: 2,
        invoiceNumber: 'INV-2025-012',
        status: 'paid',
        total: 3120.00,
        issuedDate: '2025-12-01',
        dueDate: '2025-12-15',
        servicePeriod: 'November 2025',
        description: 'Snow removal services - 12 service calls',
      ),
      ClientInvoice(
        id: 3,
        invoiceNumber: 'INV-2025-011',
        status: 'paid',
        total: 1875.00,
        issuedDate: '2025-11-01',
        dueDate: '2025-11-15',
        servicePeriod: 'October 2025',
        description: 'Snow removal services - 5 service calls',
      ),
      ClientInvoice(
        id: 4,
        invoiceNumber: 'INV-2025-010',
        status: 'paid',
        total: 850.00,
        issuedDate: '2025-10-01',
        dueDate: '2025-10-15',
        servicePeriod: 'September 2025',
        description: 'Pre-season equipment inspection',
      ),
    ];
  }

  /// Payment methods: web uses mock data; no backend yet. Return mock list.
  List<PaymentMethod> getMockPaymentMethods() {
    return [
      PaymentMethod(id: 1, type: 'Visa', lastFour: '4242', expiry: '12/2027', isDefault: true),
      PaymentMethod(id: 2, type: 'Mastercard', lastFour: '8888', expiry: '06/2026', isDefault: false),
    ];
  }
}

class PaymentsBillingException implements Exception {
  final String message;
  final bool isUnauthorized;
  PaymentsBillingException(this.message, {this.isUnauthorized = false});
  static PaymentsBillingException unauthorized() =>
      PaymentsBillingException('Session expired or not authenticated', isUnauthorized: true);
  @override
  String toString() => message;
}
