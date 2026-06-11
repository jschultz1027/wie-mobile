import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/contractor_admin.dart';
import '../../providers/auth_provider.dart';
import '../../services/contractor_management_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_notification.dart';
import '../auth/login_screen.dart';

/// Admin Contractor Management. Matches web: /contractor-management.
class ContractorManagementScreen extends StatefulWidget {
  const ContractorManagementScreen({super.key});

  @override
  State<ContractorManagementScreen> createState() => _ContractorManagementScreenState();
}

class _ContractorManagementScreenState extends State<ContractorManagementScreen> {
  final ContractorManagementService _service = ContractorManagementService();

  List<AdminContractor> _contractors = [];
  bool _loading = true;
  String? _error;
  String _tierFilter = '';
  String _availabilityFilter = '';
  bool? _complianceFilter;
  AdminContractor? _selectedContractor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) {
      if (mounted) _handleSessionExpired();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getContractors(
        tier: _tierFilter.isEmpty ? null : _tierFilter,
        availability: _availabilityFilter.isEmpty ? null : _availabilityFilter,
        complianceOk: _complianceFilter,
      );
      if (mounted) {
        setState(() {
          _contractors = result.contractors;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final isUnauthorized = e is ContractorManagementException && e.isUnauthorized ||
            e.toString().contains('401');
        if (isUnauthorized) {
          _handleSessionExpired();
          return;
        }
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleSessionExpired() async {
    await StorageService().clearAll();
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    setState(() {
      _loading = false;
      _error = 'Session expired. Please log in again.';
    });
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              Navigator.of(context).pop();
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

  void _clearFilters() {
    setState(() {
      _tierFilter = '';
      _availabilityFilter = '';
      _complianceFilter = null;
    });
    _load();
  }

  Color _tierColor(String? tier) {
    switch (tier) {
      case 'expert': return Colors.purple;
      case 'certified': return AppColors.blue600;
      case 'verified': return AppColors.success;
      case 'novice': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Color _availabilityColor(String? status) {
    switch (status) {
      case 'available': return AppColors.success;
      case 'limited': return Colors.orange;
      case 'offline': return Colors.grey;
      case 'on_route': return AppColors.blue600;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user != null && !auth.user!.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Contractor Management')),
        body: const Center(child: Text('Admin only')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Contractor Management',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Manage and view all contractor profiles, availability, and performance',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        if (_error != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 12),
                        ],
                        _buildFilters(),
                        const SizedBox(height: 16),
                        if (_contractors.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'No contractors found matching your filters',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        else
                          ..._contractors.map((c) => _buildContractorCard(c)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                if (_selectedContractor != null) _buildDetailOverlay(),
              ],
            ),
    );
  }

  Widget _buildDetailOverlay() {
    final c = _selectedContractor!;
    return GestureDetector(
      onTap: () => setState(() => _selectedContractor = null),
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (c.companyName != null && c.companyName!.isNotEmpty)
                            Text(c.companyName!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _chip(c.tierLevel ?? 'novice', _tierColor(c.tierLevel)),
                              _chip(c.availabilityStatus ?? 'unknown', _availabilityColor(c.availabilityStatus)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedContractor = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {}, // prevent tap from closing when tapping content
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Contact'),
                          _detailRow(Icons.email, c.email),
                          if (c.phone != null && c.phone!.isNotEmpty) _detailRow(Icons.phone, c.phone!),
                          if (c.homeBaseCity != null && c.homeBaseCity!.isNotEmpty) _detailRow(Icons.location_on, c.homeBaseCity!),
                          const SizedBox(height: 16),
                          _sectionTitle('Capacity & Work'),
                          Row(
                            children: [
                              Expanded(child: _capacityCard('Today', c.capacityTodayRemaining ?? 0, AppColors.blue600)),
                              const SizedBox(width: 8),
                              Expanded(child: _capacityCard('Next 24h', c.capacityNext24hRemaining ?? 0, Colors.indigo)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _capacityCard('Active', c.activeAssignmentsCount, AppColors.success)),
                              const SizedBox(width: 8),
                              Expanded(child: _capacityCard('Upcoming', c.upcomingDispatchesCount, Colors.purple)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _sectionTitle('Equipment'),
                          if (c.equipmentTags != null && c.equipmentTags!.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: c.equipmentTags!.map((e) => Chip(label: Text(e), backgroundColor: AppColors.blue600.withOpacity(0.2))).toList(),
                            )
                          else
                            Text('No equipment listed', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                          const SizedBox(height: 16),
                          _sectionTitle('Compliance'),
                          _complianceRow('Insurance', c.insuranceStatus),
                          _complianceRow('Training', c.courseStatus),
                          _complianceRow('Banking', c.bankingStatus),
                          const SizedBox(height: 16),
                          _sectionTitle('Performance'),
                          _perfRow('Accept rate', (c.acceptRate ?? 0).toStringAsFixed(1)),
                          _perfRow('On-time rate', (c.onTimeRate ?? 0).toStringAsFixed(1)),
                          _perfRow('Jobs', '${c.totalJobsCompleted ?? 0} / ${c.totalJobsAssigned ?? 0}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _capacityCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _complianceRow(String label, String? status) {
    final ok = status == 'verified';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (ok ? AppColors.success : Colors.red).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text((status ?? 'unknown').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ok ? AppColors.success : Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _perfRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
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
          children: [
            Text('Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tierFilter.isEmpty ? 'all' : _tierFilter,
                    decoration: InputDecoration(
                      labelText: 'Tier',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Tiers')),
                      DropdownMenuItem(value: 'expert', child: Text('Expert')),
                      DropdownMenuItem(value: 'certified', child: Text('Certified')),
                      DropdownMenuItem(value: 'verified', child: Text('Verified')),
                      DropdownMenuItem(value: 'novice', child: Text('Novice')),
                    ],
                    onChanged: (v) {
                      setState(() => _tierFilter = (v == 'all') ? '' : v!);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _availabilityFilter.isEmpty ? 'all' : _availabilityFilter,
                    decoration: InputDecoration(
                      labelText: 'Availability',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'available', child: Text('Available')),
                      DropdownMenuItem(value: 'limited', child: Text('Limited')),
                      DropdownMenuItem(value: 'offline', child: Text('Offline')),
                      DropdownMenuItem(value: 'on_route', child: Text('On Route')),
                    ],
                    onChanged: (v) {
                      setState(() => _availabilityFilter = (v == 'all') ? '' : v!);
                      _load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _complianceFilter == null ? 'all' : _complianceFilter.toString(),
                    decoration: InputDecoration(
                      labelText: 'Compliance',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'true', child: Text('Compliant Only')),
                      DropdownMenuItem(value: 'false', child: Text('Issues Only')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _complianceFilter = v == 'all' ? null : (v == 'true');
                      });
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractorCard(AdminContractor c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => setState(() => _selectedContractor = c),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        if (c.homeBaseCity != null && c.homeBaseCity!.isNotEmpty)
                          Text(c.homeBaseCity!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(c.tierLevel ?? 'novice', _tierColor(c.tierLevel)),
                      _chip(c.availabilityStatus ?? 'unknown', _availabilityColor(c.availabilityStatus)),
                      _chip(c.isCompliant ? 'Compliant' : 'Issues', c.isCompliant ? AppColors.success : Colors.red),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Today: ${c.capacityTodayRemaining ?? 0}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('24h: ${c.capacityNext24hRemaining ?? 0}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('Accept: ${(c.acceptRate ?? 0).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('On-time: ${(c.onTimeRate ?? 0).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${c.activeAssignmentsCount} active • ${c.upcomingDispatchesCount} upcoming', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _selectedContractor = c),
                        child: const Text('View Details'),
                      ),
                      if (c.activeAssignmentsCount > 0)
                        FilledButton.icon(
                          onPressed: () {
                            AppNotification.info(context, 'Live tracking for ${c.fullName} — use web admin for live map');
                          },
                          icon: const Icon(Icons.location_on, size: 18),
                          label: const Text('Live'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedContractor != null && !_contractors.any((c) => c.id == _selectedContractor!.id)) {
      _selectedContractor = null;
    }
  }
}
