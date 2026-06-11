/// Snow removal contract. Matches web /snow-removal-contract example data.
class SnowRemovalContractDetails {
  final String contractNumber;
  final String startDate;
  final String endDate;
  final String status; // active, expired, pending
  /// Selected commercial model for this contract:
  /// 'pay_per_service' | 'monthly_base' | 'prepaid_seasonal'
  final String serviceType;
  final List<ContractProperty> properties;
  final List<String> services;
  final ContractPricing pricing;
  final ContractTerms terms;
  final ContractContact contact;

  SnowRemovalContractDetails({
    required this.contractNumber,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.serviceType,
    required this.properties,
    required this.services,
    required this.pricing,
    required this.terms,
    required this.contact,
  });

  bool get isActive => status == 'active';
  int get totalAreaSqft =>
      properties.fold(0, (sum, p) => sum + p.areaSqft);
}

class ContractProperty {
  final String name;
  final String address;
  final int areaSqft;

  ContractProperty({
    required this.name,
    required this.address,
    required this.areaSqft,
  });
}

class ContractPricing {
  final double monthlyBase;
  final double perService;
  final String snowRemovalRate;
  final String saltingRate;

  ContractPricing({
    required this.monthlyBase,
    required this.perService,
    required this.snowRemovalRate,
    required this.saltingRate,
  });
}

class ContractTerms {
  final String responseTime;
  final String serviceHours;
  final String snowAccumulationTrigger;
  final String iceControl;

  ContractTerms({
    required this.responseTime,
    required this.serviceHours,
    required this.snowAccumulationTrigger,
    required this.iceControl,
  });
}

class ContractContact {
  final String accountManager;
  final String phone;
  final String email;
  final String emergencyLine;

  ContractContact({
    required this.accountManager,
    required this.phone,
    required this.email,
    required this.emergencyLine,
  });
}
