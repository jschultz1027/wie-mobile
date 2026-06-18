import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/dispatch_queue.dart';
import '../../providers/auth_provider.dart';
import '../../services/dispatch_queue_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_notification.dart';
import '../auth/login_screen.dart';

/// Admin Dispatch Queue. Matches web: /dispatch-queue.
class DispatchQueueScreen extends StatefulWidget {
  const DispatchQueueScreen({super.key});

  @override
  State<DispatchQueueScreen> createState() => _DispatchQueueScreenState();
}

class _DispatchQueueScreenState extends State<DispatchQueueScreen> {
  final DispatchQueueService _service = DispatchQueueService();

  List<DispatchQueueItem> _dispatches = [];
  DispatchBucketCounts _bucketCounts = DispatchBucketCounts();
  bool _loading = true;
  String? _error;
  String _assignmentFilter = '';
  String _bucketFilter = '';
  String _workTypeFilter = '';

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
      final result = await _service.getDispatchQueue(
        assignmentStatus: _assignmentFilter.isEmpty ? null : _assignmentFilter,
        bucket: _bucketFilter.isEmpty ? null : _bucketFilter,
        workType: _workTypeFilter.isEmpty ? null : _workTypeFilter,
      );
      if (mounted) {
        setState(() {
          _dispatches = result.dispatches;
          _bucketCounts = result.bucketCounts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final isUnauthorized = e is DispatchQueueException && e.isUnauthorized || e.toString().contains('401');
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
    Provider.of<AuthProvider>(context, listen: false).logout();
    setState(() {
      _loading = false;
      _error = 'Session expired. Please log in again.';
    });
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.timer_off, color: AppColors.error), SizedBox(width: 12), Text('Session expired')]),
        content: const Text('Your session has expired. Please log in again to continue.'),
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

  void _openAssignSheet(DispatchQueueItem dispatch) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignContractorSheet(
        dispatchId: dispatch.id,
        propertyName: dispatch.propertyName,
        service: _service,
        onAssign: (contractorId) async {
          Navigator.pop(ctx);
          try {
            await _service.assignContractor(dispatch.id, contractorId);
            if (mounted) {
              AppNotification.success(context, 'Contractor assigned successfully');
              _load();
            }
          } catch (e) {
            if (mounted) AppNotification.error(context, e.toString());
          }
        },
      ),
    );
  }

  Future<void> _unassign(DispatchQueueItem dispatch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unassign Contractor?'),
        content: const Text('Are you sure you want to unassign this contractor from this dispatch?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Unassign')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.unassignContractor(dispatch.id);
      if (mounted) {
        AppNotification.success(context, 'Contractor unassigned');
        _load();
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, e.toString());
    }
  }

  Color _bucketColor(String? bucket) {
    switch (bucket) {
      case '24h': return Colors.red;
      case '48h': return Colors.orange;
      case '72h': return Colors.amber;
      case '7d': return AppColors.blue600;
      default: return Colors.grey;
    }
  }

  Color _riskColor(double? risk) {
    if (risk == null) return Colors.grey;
    if (risk >= 80) return Colors.red;
    if (risk >= 60) return Colors.orange;
    if (risk >= 40) return Colors.amber;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user != null && !auth.user!.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.of(context).pop(); });
      return Scaffold(drawer: const AppDrawer(), appBar: AppBar(title: const Text('Dispatch Queue')), body: const Center(child: Text('Admin only')));
    }

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text('Dispatch Queue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Manage property assignments and contractor dispatches', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      _buildErrorBanner(),
                      const SizedBox(height: 12),
                    ],
                    _buildBucketSummary(),
                    const SizedBox(height: 16),
                    _buildFilters(),
                    const SizedBox(height: 16),
                    if (_dispatches.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('No dispatches found matching your filters', style: TextStyle(color: Colors.grey.shade600))))
                    else
                      ..._dispatches.map(_buildDispatchCard),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
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

  Widget _buildBucketSummary() {
    return Row(
      children: [
        Expanded(child: _bucketCard('≤ 24h', _bucketCounts.unassigned24h, Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _bucketCard('24-48h', _bucketCounts.unassigned24_48h, Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _bucketCard('48-72h', _bucketCounts.unassigned48_72h, Colors.amber)),
        const SizedBox(width: 8),
        Expanded(child: _bucketCard('3-7d', _bucketCounts.unassigned3_7d, AppColors.blue600)),
      ],
    );
  }

  Widget _bucketCard(String label, int count, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text('Unassigned', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
          children: [
            Text('Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _assignmentFilter.isEmpty ? 'all' : _assignmentFilter,
                    decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'unassigned', child: Text('Unassigned')),
                      DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                      DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    ],
                    onChanged: (v) { setState(() => _assignmentFilter = v == 'all' ? '' : v!); _load(); },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _bucketFilter.isEmpty ? 'all' : _bucketFilter,
                    decoration: InputDecoration(labelText: 'Bucket', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: '24h', child: Text('≤ 24h')),
                      DropdownMenuItem(value: '48h', child: Text('24-48h')),
                      DropdownMenuItem(value: '72h', child: Text('48-72h')),
                      DropdownMenuItem(value: '7d', child: Text('3-7d')),
                    ],
                    onChanged: (v) { setState(() => _bucketFilter = v == 'all' ? '' : v!); _load(); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _workTypeFilter.isEmpty ? 'all' : _workTypeFilter,
                    decoration: InputDecoration(labelText: 'Work type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'full_service', child: Text('Full Service')),
                      DropdownMenuItem(value: 'spot_salt', child: Text('Spot Salt')),
                      DropdownMenuItem(value: 'check', child: Text('Check')),
                      DropdownMenuItem(value: 'revisit', child: Text('Revisit')),
                    ],
                    onChanged: (v) { setState(() => _workTypeFilter = v == 'all' ? '' : v!); _load(); },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(onPressed: () { setState(() { _assignmentFilter = ''; _bucketFilter = ''; _workTypeFilter = ''; }); _load(); }, icon: const Icon(Icons.clear_all, size: 18), label: const Text('Reset')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDispatchCard(DispatchQueueItem d) {
    final isAssigned = d.assignedContractorName != null && d.assignedContractorName!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Text(d.propertyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (d.propertyAddress.isNotEmpty) Text(d.propertyAddress, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                _chip(d.projectedDispatchBucket ?? '-', _bucketColor(d.projectedDispatchBucket)),
                const SizedBox(width: 6),
                _chip('${(d.currentRiskScore ?? d.riskScoreOverall)?.toStringAsFixed(0) ?? '-'}', _riskColor(d.currentRiskScore ?? d.riskScoreOverall)),
                if (d.dispatchType != null) ...[
                  const SizedBox(width: 6),
                  _chip(
                    d.dispatchType == 'initial' ? 'Initial' : 'Subsequent',
                    d.dispatchType == 'initial' ? AppColors.blue600 : AppColors.warning,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (d.projectedDispatchEtaHours != null) Text('ETA ${d.projectedDispatchEtaHours!.toStringAsFixed(1)}h', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(width: 12),
                Text(d.workType ?? '-', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                if (d.dispatchType == 'subsequent' && d.currentSaltEffectiveness != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Salt: ${d.currentSaltEffectiveness!.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: d.currentSaltEffectiveness! <= 25
                          ? AppColors.warning
                          : d.currentSaltEffectiveness! <= 50
                              ? Colors.orange.shade700
                              : AppColors.success,
                    ),
                  ),
                ],
                const Spacer(),
                if (isAssigned)
                  Text(d.assignedContractorName!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isAssigned)
                  TextButton(
                    onPressed: () => _unassign(d),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Unassign'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _openAssignSheet(d),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Assign'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.blue600),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// Bottom sheet to pick a contractor for a dispatch.
class _AssignContractorSheet extends StatefulWidget {
  final int dispatchId;
  final String propertyName;
  final DispatchQueueService service;
  final void Function(int contractorId) onAssign;

  const _AssignContractorSheet({
    required this.dispatchId,
    required this.propertyName,
    required this.service,
    required this.onAssign,
  });

  @override
  State<_AssignContractorSheet> createState() => _AssignContractorSheetState();
}

class _AssignContractorSheetState extends State<_AssignContractorSheet> {
  List<ContractorMatch> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.service.getContractorMatches(widget.dispatchId).then((list) {
      if (mounted) setState(() { _matches = list; _loading = false; });
    }).catchError((e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Assign contractor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Text(
            widget.propertyName,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : _matches.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('No contractor matches found', style: TextStyle(color: Colors.grey.shade600)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _matches.length,
                            itemBuilder: (context, i) {
                              final m = _matches[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(m.contractorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${m.tierLevel} · Match ${m.matchScore.toStringAsFixed(0)}% · ${m.availabilityStatus}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  trailing: FilledButton(
                                    onPressed: () => widget.onAssign(m.contractorId),
                                    style: FilledButton.styleFrom(backgroundColor: AppColors.blue600),
                                    child: const Text('Assign'),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
