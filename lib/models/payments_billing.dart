/// Client invoice. Matches web and backend GET /api/v1/invoices/client/{client_id}.
class ClientInvoice {
  final int id;
  final String invoiceNumber;
  final String status; // paid, pending (sent/draft), overdue
  final double total;
  final String? issuedDate;
  final String? dueDate;
  final String? paidDate;
  final String? servicePeriod;
  final String? description;

  ClientInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.total,
    this.issuedDate,
    this.dueDate,
    this.paidDate,
    this.servicePeriod,
    this.description,
  });

  factory ClientInvoice.fromJson(Map<String, dynamic> json) {
    return ClientInvoice(
      id: json['id'] as int,
      invoiceNumber: json['invoice_number'] as String? ?? '',
      status: _normalizeStatus(json['status'] as String?),
      total: (json['total'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble() ?? 0,
      issuedDate: json['issued_date']?.toString() ?? json['date']?.toString(),
      dueDate: json['due_date']?.toString(),
      paidDate: json['paid_date']?.toString(),
      servicePeriod: json['service_period'] as String?,
      description: json['description'] as String?,
    );
  }

  static String _normalizeStatus(String? s) {
    if (s == null) return 'pending';
    switch (s.toLowerCase()) {
      case 'paid':
        return 'paid';
      case 'overdue':
        return 'overdue';
      case 'sent':
      case 'draft':
      default:
        return 'pending';
    }
  }

  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue';
  bool get isPending => status == 'pending';
}

/// Payment method for display. Web uses mock data; no backend endpoint yet.
class PaymentMethod {
  final int id;
  final String type;
  final String lastFour;
  final String expiry;
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.lastFour,
    required this.expiry,
    this.isDefault = false,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'Card',
      lastFour: json['last_four'] as String? ?? '',
      expiry: json['expiry'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}
