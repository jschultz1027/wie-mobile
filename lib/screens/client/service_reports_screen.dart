import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/service_report.dart';
import '../../providers/auth_provider.dart';
import '../../services/service_reports_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_notification.dart';
import '../auth/login_screen.dart';

/// Client Past Service Reports. Matches web /service-reports.
class ServiceReportsScreen extends StatefulWidget {
  const ServiceReportsScreen({super.key});

  @override
  State<ServiceReportsScreen> createState() => _ServiceReportsScreenState();
}

class _ServiceReportsScreenState extends State<ServiceReportsScreen> {
  List<ServiceReport> _reports = [];
  String _filterProperty = 'all';
  String _filterMonth = 'all';
  List<String> _propertyOptions = [];
  List<String> _monthOptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _loading = true;
      _reports = ServiceReportsService.getMockReports();
      _propertyOptions = ['all', ..._reports.map((r) => r.property).toSet().toList()..sort()];
      _monthOptions = ServiceReportsService.getMonthOptions();
      _loading = false;
    });
  }

  List<ServiceReport> get _filteredReports {
    return _reports.where((r) {
      if (_filterProperty != 'all' && r.property != _filterProperty) return false;
      if (_filterMonth != 'all') {
        final d = DateTime.tryParse(r.date);
        if (d == null) return true;
        final monthYear = '${_monthName(d.month)} ${d.year}';
        if (monthYear != _filterMonth) return false;
      }
      return true;
    }).toList();
  }

  String _monthName(int month) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month - 1];
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekday = days[d.weekday - 1];
    return '$weekday, ${_monthName(d.month)} ${d.day}, ${d.year}';
  }

  int get _thisMonthCount =>
      _reports.where((r) => r.date.startsWith('2026-01')).length;
  int get _propertiesServiced => _reports.map((r) => r.property).toSet().length;

  /// Black-ice instances: services performed when atmospheric temperature was > 0°C
  static double? _parseTempC(String t) {
    final match = RegExp(r'-?\d+\.?\d*').firstMatch(t);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
  }
  int get _blackIceCount =>
      _reports.where((r) => (_parseTempC(r.weatherConditions.temperature) ?? -999) > 0).length;

  Future<void> _handleSessionExpired() async {
    await StorageService().clearAll();
    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: AppColors.error),
            SizedBox(width: 12),
            Text('Session expired'),
          ],
        ),
        content: const Text(
          'Your session has expired. Please log in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user != null && !auth.user!.isClient) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(title: const Text('Past Service Reports')),
        body: const Center(child: Text('Client only')),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'Past Service Reports',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _load(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Review completed service history with detailed reports',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCards(),
                    const SizedBox(height: 16),
                    _buildFilters(),
                    const SizedBox(height: 16),
                    ..._filteredReports.map(_buildReportCard),
                    if (_filteredReports.isEmpty) _buildEmptyState(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final countPerRow = w > 400 ? 4 : (w > 280 ? 2 : 2);
        final cardWidth = (w - 8.0 * (countPerRow - 1)) / countPerRow;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: cardWidth.clamp(70.0, double.infinity),
              child: _summaryCard(
                'Total Services',
                '${_reports.length}',
                AppColors.blue600,
              ),
            ),
            SizedBox(
              width: cardWidth.clamp(70.0, double.infinity),
              child: _summaryCard(
                'This Month',
                '$_thisMonthCount',
                AppColors.success,
              ),
            ),
            SizedBox(
              width: cardWidth.clamp(70.0, double.infinity),
              child: _summaryCard(
                'Black-ice instances detected & protected',
                '$_blackIceCount',
                AppColors.roleAdmin,
              ),
            ),
            SizedBox(
              width: cardWidth.clamp(70.0, double.infinity),
              child: _summaryCard(
                'Properties',
                '$_propertiesServiced',
                Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, Color accentColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withOpacity(0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                if (width < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPropertyDropdown(),
                      const SizedBox(height: 10),
                      _buildMonthDropdown(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildPropertyDropdown(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMonthDropdown(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyDropdown() {
    return DropdownButtonFormField<String>(
      value: _filterProperty,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Property',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
      selectedItemBuilder: (context) => [
        const Text('All Properties', overflow: TextOverflow.ellipsis, maxLines: 1),
        ..._propertyOptions
            .where((v) => v != 'all')
            .map((v) => Text(v, overflow: TextOverflow.ellipsis, maxLines: 1)),
      ],
      items: [
        const DropdownMenuItem(
          value: 'all',
          child: Text('All Properties', overflow: TextOverflow.ellipsis),
        ),
        ..._propertyOptions
            .where((v) => v != 'all')
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(
                  v,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
      ],
      onChanged: (v) => setState(() => _filterProperty = v ?? 'all'),
    );
  }

  Widget _buildMonthDropdown() {
    return DropdownButtonFormField<String>(
      value: _filterMonth,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Month',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
      selectedItemBuilder: (context) => _monthOptions
          .map((v) => Text(
                v == 'all' ? 'All Months' : v,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ))
          .toList(),
      items: _monthOptions
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text(
                v == 'all' ? 'All Months' : v,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _filterMonth = v ?? 'all'),
    );
  }

  Widget _buildReportCard(ServiceReport report) {
    final statusColor =
        report.isVerified ? AppColors.success : AppColors.blue600;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    report.serviceType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          report.isVerified ? '✓ Verified' : 'Completed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    AppNotification.info(context, 'Download PDF available on web');
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('PDF'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.blue600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatDate(report.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.property,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${report.startTime} - ${report.endTime} (${report.duration})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Service Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Crew: ${report.crewSize} · ${report.materialsUsed}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${report.photos} photos',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.blue600.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Weather',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${report.weatherConditions.temperature} · ${report.weatherConditions.conditions}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: Colors.amber.shade700,
                    width: 4,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Service Notes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.notes,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.description, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No Reports Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No service reports match your current filters.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
