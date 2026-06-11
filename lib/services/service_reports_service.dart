import '../models/service_report.dart';

/// Service reports for client. Matches web /service-reports; uses example data.
class ServiceReportsService {
  /// Example reports matching web /service-reports.
  static List<ServiceReport> getMockReports() {
    return [
      ServiceReport(
        id: 1,
        date: '2026-01-05',
        property: '2927 Fremont Street',
        serviceType: 'Snow Plowing & Salting',
        startTime: '05:30 AM',
        endTime: '07:15 AM',
        duration: '1h 45m',
        crewSize: 3,
        materialsUsed: 'Rock salt (250 lbs), Brine pre-treatment',
        weatherConditions: ServiceReportWeather(
          temperature: '-8°C',
          conditions: 'Heavy snowfall, 15cm accumulation',
        ),
        photos: 8,
        notes:
            'All zones cleared. Extra attention to parking areas due to ice buildup. Applied brine to prevent refreezing.',
        status: 'completed',
      ),
      ServiceReport(
        id: 2,
        date: '2026-01-03',
        property: '715 Ducklow Street',
        serviceType: 'Ice Control & Spot Salting',
        startTime: '06:00 AM',
        endTime: '06:45 AM',
        duration: '45m',
        crewSize: 2,
        materialsUsed: 'Treated salt (150 lbs)',
        weatherConditions: ServiceReportWeather(
          temperature: '-5°C',
          conditions: 'Clear skies, black ice on sidewalks',
        ),
        photos: 5,
        notes:
            'Focused on high-traffic walkways and entry points. No snow removal required.',
        status: 'verified',
      ),
      ServiceReport(
        id: 3,
        date: '2025-12-28',
        property: '2927 Fremont Street',
        serviceType: 'Full Property Snow Removal',
        startTime: '04:00 AM',
        endTime: '08:30 AM',
        duration: '4h 30m',
        crewSize: 5,
        materialsUsed: 'Rock salt (400 lbs), Sand mixture (200 lbs)',
        weatherConditions: ServiceReportWeather(
          temperature: '-12°C',
          conditions: 'Blizzard conditions, 25cm accumulation',
        ),
        photos: 12,
        notes:
            'Major snow event. Full property cleared including loading zones. Deployed extra crew for efficiency.',
        status: 'verified',
      ),
      ServiceReport(
        id: 4,
        date: '2025-12-22',
        property: '3402-3474 Copeland Avenue',
        serviceType: 'Snow Plowing',
        startTime: '05:15 AM',
        endTime: '06:30 AM',
        duration: '1h 15m',
        crewSize: 2,
        materialsUsed: 'Rock salt (180 lbs)',
        weatherConditions: ServiceReportWeather(
          temperature: '-6°C',
          conditions: 'Light snow, 8cm accumulation',
        ),
        photos: 6,
        notes: 'Routine clearing. All access routes maintained.',
        status: 'verified',
      ),
      ServiceReport(
        id: 5,
        date: '2025-12-18',
        property: '715 Ducklow Street',
        serviceType: 'Preventive Salting',
        startTime: '10:00 PM',
        endTime: '10:30 PM',
        duration: '30m',
        crewSize: 2,
        materialsUsed: 'Brine pre-treatment',
        weatherConditions: ServiceReportWeather(
          temperature: '-2°C',
          conditions: 'Freezing rain forecasted',
        ),
        photos: 3,
        notes:
            'Preventive application ahead of freezing rain. Focus on slopes and entry points.',
        status: 'verified',
      ),
    ];
  }

  /// Month options for filter (matching web).
  static List<String> getMonthOptions() {
    return ['all', 'January 2026', 'December 2025', 'November 2025'];
  }
}
