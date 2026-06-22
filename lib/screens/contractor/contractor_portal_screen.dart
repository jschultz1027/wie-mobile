import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/refresh_icon_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/contractor_assignment.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/contractor_assignment_service.dart';
import '../auth/login_screen.dart';
import 'contractor_payments_screen.dart';
import 'contractor_dispatch_detail_screen.dart';

/// Contractor Portal - Dispatch Queue. Matches web: /contractor-portal.
/// Shows assigned properties, filtering, sorting, and actions.
class ContractorPortalScreen extends StatefulWidget {
  const ContractorPortalScreen({super.key});

  @override
  State<ContractorPortalScreen> createState() => _ContractorPortalScreenState();
}

class _ContractorPortalScreenState extends State<ContractorPortalScreen> {
  final ContractorAssignmentService _service = ContractorAssignmentService();
  List<ContractorAssignment> _assignments = [];
  bool _loading = true;
  String? _error;

  // Filtering and sorting
  String _selectedWindow = 'ALL'; // ALL, 72h, 48h, 24h, 12h, 6h, DISPATCH_NOW
  String _sortBy = 'urgency'; // urgency, risk, name

  // Availability status
  String _availabilityStatus = 'AVAILABLE'; // AVAILABLE, LIMITED, UNAVAILABLE

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = StorageService().getToken();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (token == null || token.isEmpty || user == null) {
      if (mounted) _handleSessionExpired();
      return;
    }
    if (user.role != 'contractor' && user.role != 'worker') {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final assignments = await _service.getAssignments();
      if (mounted) {
        setState(() {
          _assignments = assignments;
          _loading = false;
        });
      }
    } on ContractorAssignmentException catch (e) {
      if (e.isUnauthorized && mounted) {
        _handleSessionExpired();
        return;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _handleSessionExpired() async {
    await StorageService().clearAll();
    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  List<ContractorAssignment> _getFilteredAndSorted() {
    List<ContractorAssignment> filtered = List<ContractorAssignment>.from(_assignments);

    // Filter by time window
    if (_selectedWindow != 'ALL') {
      if (_selectedWindow == 'DISPATCH_NOW') {
        filtered = <ContractorAssignment>[
          for (final a in filtered)
            if (a.dispatchStatus == 'DISPATCH') a
        ];
      } else {
        final hours = int.tryParse(_selectedWindow.replaceAll('h', '')) ?? 72;
        filtered = <ContractorAssignment>[
          for (final a in filtered)
            if (a.urgencyHours <= hours) a
        ];
      }
    }

    // Sort
    filtered.sort((ContractorAssignment a, ContractorAssignment b) {
      if (_sortBy == 'urgency') {
        return a.urgencyHours.compareTo(b.urgencyHours);
      } else if (_sortBy == 'risk') {
        final aRisk = a.riskScore ?? 0;
        final bRisk = b.riskScore ?? 0;
        return bRisk.compareTo(aRisk);
      } else if (_sortBy == 'name') {
        return a.propertyName.compareTo(b.propertyName);
      }
      return 0;
    });

    return filtered;
  }

  MaterialColor _getStatusColor(String status) {
    switch (status) {
      case 'DISPATCH':
        return Colors.red;
      case 'STANDBY':
        return Colors.orange;
      case 'MONITORING':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  MaterialColor _getRiskColor(double? risk) {
    if (risk == null) return Colors.grey;
    if (risk < 40) return Colors.green;
    if (risk < 60) return Colors.yellow;
    if (risk < 80) return Colors.orange;
    return Colors.red;
  }

  MaterialColor _getAvailabilityColor(String status) {
    switch (status) {
      case 'AVAILABLE':
        return Colors.green;
      case 'LIMITED':
        return Colors.orange;
      case 'UNAVAILABLE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user != null && auth.user!.role != 'contractor' && auth.user!.role != 'worker') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(title: const Text('Contractor Portal')),
        body: const Center(child: Text('Contractor only')),
      );
    }

    final filteredAssignments = _getFilteredAndSorted();

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'Dispatch Queue',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          ScreenHelpAction(
            title: 'Contractor Portal',
            message: HelpContent.screenContractorPortal,
          ),
          RefreshIconButton(
            loading: _loading,
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error loading assignments',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with My Earnings button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Dispatch Queue',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Properties assigned to you',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ContractorPaymentsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.account_balance_wallet, size: 18),
                              label: const Text('My Earnings'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Availability Status Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Availability Status',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _getAvailabilityColor(_availabilityStatus).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _getAvailabilityColor(_availabilityStatus),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _availabilityStatus == 'AVAILABLE'
                                              ? Icons.check_circle
                                              : _availabilityStatus == 'LIMITED'
                                                  ? Icons.warning
                                                  : Icons.cancel,
                                          color: _getAvailabilityColor(_availabilityStatus),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _availabilityStatus == 'AVAILABLE'
                                              ? 'Available for Dispatch'
                                              : _availabilityStatus == 'LIMITED'
                                                  ? 'Limited Availability'
                                                  : 'Unavailable',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: _getAvailabilityColor(_availabilityStatus),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildAvailabilityButton('AVAILABLE', Colors.green),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildAvailabilityButton('LIMITED', Colors.orange),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildAvailabilityButton('UNAVAILABLE', Colors.red),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Note: This status is currently manual. Future updates will enable automatic queue dispatch based on your availability.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Time Window Filter
                        const Text(
                          'Time Window',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['ALL', '72h', '48h', '24h', '12h', '6h', 'DISPATCH_NOW']
                                .map((window) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(window == 'DISPATCH_NOW' ? 'DISPATCH NOW' : window),
                                        selected: _selectedWindow == window,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _selectedWindow = window;
                                            });
                                          }
                                        },
                                        selectedColor: window == 'DISPATCH_NOW'
                                            ? Colors.red.shade100
                                            : Colors.blue.shade100,
                                        checkmarkColor: window == 'DISPATCH_NOW'
                                            ? Colors.red.shade700
                                            : Colors.blue.shade700,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Sort Controls
                        const Text(
                          'Sort by',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSortButton('urgency', 'Urgency'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSortButton('risk', 'Risk'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSortButton('name', 'Name'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Summary Stats
                        if (_assignments.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Total',
                                  '${_assignments.length}',
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Dispatch',
                                  '${_assignments.where((ContractorAssignment a) => a.dispatchStatus == 'DISPATCH').length}',
                                  Colors.red,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Standby',
                                  '${_assignments.where((ContractorAssignment a) => a.dispatchStatus == 'STANDBY').length}',
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Monitor',
                                  '${_assignments.where((ContractorAssignment a) => a.dispatchStatus == 'MONITORING').length}',
                                  Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Assignments List
                        if (filteredAssignments.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No properties in this time window',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredAssignments.length,
                            itemBuilder: (context, index) {
                              final assignment = filteredAssignments[index];
                              return _buildAssignmentCard(assignment);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildAvailabilityButton(String status, MaterialColor color) {
    final isSelected = _availabilityStatus == status;
    return InkWell(
      onTap: () {
        setState(() {
          _availabilityStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          status == 'AVAILABLE'
              ? 'Available'
              : status == 'LIMITED'
                  ? 'Limited'
                  : 'Unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(String value, String label) {
    final isSelected = _sortBy == value;
    return InkWell(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(ContractorAssignment assignment) {
    final statusColor = _getStatusColor(assignment.dispatchStatus);
    final riskColor = _getRiskColor(assignment.riskScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Property Name and Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.propertyName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              assignment.propertyAddress,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    assignment.dispatchStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Risk and Protection Row
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        'Risk',
                        assignment.riskScore?.toStringAsFixed(0) ?? '-',
                        riskColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailItem(
                        'Protection',
                        assignment.protectionLabel,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Urgency and Zones Row
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        'Urgency',
                        '${assignment.urgencyHours}h',
                        Colors.orange,
                        icon: Icons.access_time,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailItem(
                        'Zones',
                        '${assignment.zonesCompleted}/${assignment.zonesTotal}',
                        Colors.purple,
                        icon: Icons.map,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ContractorDispatchDetailScreen(
                            assignmentId: assignment.id,
                            assignment: assignment,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: assignment.dispatchStatus == 'DISPATCH'
                          ? Colors.red.shade600
                          : assignment.dispatchStatus == 'STANDBY'
                              ? Colors.orange.shade600
                              : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      assignment.dispatchStatus == 'DISPATCH'
                          ? 'START JOB'
                          : assignment.dispatchStatus == 'STANDBY'
                              ? 'VIEW DETAILS'
                              : 'NO ACTION',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, MaterialColor color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
