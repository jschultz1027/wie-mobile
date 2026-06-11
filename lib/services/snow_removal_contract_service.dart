import '../models/snow_removal_contract.dart';

/// Snow removal contract for client. Matches web /snow-removal-contract; uses example data.
class SnowRemovalContractService {
  /// Example contract matching web /snow-removal-contract.
  static SnowRemovalContractDetails getMockContract() {
    return SnowRemovalContractDetails(
      contractNumber: 'WIE-2025-2026-0123',
      startDate: '2025-10-01',
      endDate: '2026-04-30',
      status: 'active',
      serviceType: 'monthly_base',
      properties: [
        ContractProperty(
          name: '2927 Fremont Street',
          address: '2927 Fremont Street, Vancouver, BC',
          areaSqft: 45000,
        ),
        ContractProperty(
          name: '715 Ducklow Street',
          address: '715 Ducklow Street, Coquitlam, BC',
          areaSqft: 32000,
        ),
        ContractProperty(
          name: '3402-3474 Copeland Avenue',
          address: '3402-3474 Copeland Avenue, Vancouver, BC',
          areaSqft: 28000,
        ),
      ],
      services: [
        'Snow plowing and removal',
        'Ice control and salting',
        'Sidewalk clearing',
        'Parking lot maintenance',
        '24/7 emergency response',
        'Weather monitoring and forecasting',
        'Post-service photo documentation',
        'Real-time hazard risk assessment',
      ],
      pricing: ContractPricing(
        monthlyBase: 1250.00,
        perService: 285.00,
        snowRemovalRate: r'$95/hour per crew',
        saltingRate: r'$1.20/lb of material',
      ),
      terms: ContractTerms(
        responseTime: '2 hours from snow accumulation trigger',
        serviceHours: '24/7 availability, priority service 5am-9am',
        snowAccumulationTrigger: '5cm (2 inches) or as needed',
        iceControl:
            'Proactive salting when temperature drops below 0°C with moisture',
      ),
      contact: ContractContact(
        accountManager: 'Sarah Johnson',
        phone: '(604) 555-0123',
        email: 'sarah.johnson@winterintelligence.com',
        emergencyLine: '(604) 555-SNOW (7669)',
      ),
    );
  }
}
