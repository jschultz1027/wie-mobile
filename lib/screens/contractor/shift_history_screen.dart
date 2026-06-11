import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/shift_history.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/shift_history_service.dart';
import '../auth/login_screen.dart';

/// Contractor Shift History. Matches web: /shift-history.
/// Shows summary cards, filters (status, month), and list of past shifts.
class ShiftHistoryScreen extends StatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> {
  final ShiftHistoryService _service = ShiftHistoryService();
  List<ShiftHistoryItem> _shifts = [];
  bool _loading = true;
  String? _error;

  String _filterStatus = 'all'; // all, completed, active
  String _filterMonth = 'all'; // all or 0-11

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
    if (user.role != 'contractor') {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getHistory(limit: 50);
      if (mounted) {
        setState(() {
          _shifts = list;
          _loading = false;
        });
      }
    } on ShiftHistoryException catch (e) {
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

  List<ShiftHistoryItem> get _filteredShifts {
    return _shifts.where((s) {
      if (_filterStatus != 'all' && s.status != _filterStatus) return false;
      if (_filterMonth != 'all') {
        final shiftMonth = s.startTime.month - 1; // 0-based for comparison
        if (shiftMonth != int.tryParse(_filterMonth)) return false;
      }
      return true;
    }).toList();
  }

  static String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _formatTime(DateTime d) {
    final h = d.hour;
    final m = d.minute;
    final am = h < 12;
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${hour}:${m.toString().padLeft(2, '0')} ${am ? 'AM' : 'PM'}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'active':
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredShifts;
    final completed = filtered.where((s) => s.status == 'completed').toList();
    final totalHours = completed.fold<int>(0, (sum, s) => sum + (s.durationMinutes ~/ 60));
    final totalProperties = completed.fold<int>(0, (sum, s) => sum + s.totalPropertiesCompleted);

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
          'Shift History',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _shifts.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.blue600),
                    ),
                    SizedBox(height: 16),
                    Text('Loading shifts...'),
                  ],
                ),
              )
            : _error != null && _shifts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page header
                        Text(
                          'Shift History',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'View your completed shifts and activity',
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.3),
                        ),
                        const SizedBox(height: 24),
                        // Summary section label
                        Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                label: 'Shifts',
                                value: '${filtered.length}',
                                unit: '',
                                icon: Icons.event_note,
                                color: AppColors.blue600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SummaryCard(
                                label: 'Hours worked',
                                value: '$totalHours',
                                unit: 'h',
                                icon: Icons.schedule,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SummaryCard(
                                label: 'Properties',
                                value: '$totalProperties',
                                unit: '',
                                icon: Icons.location_on,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Filter section
                        Text(
                          'Filter by',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Status', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      DropdownButtonFormField<String>(
                                        value: _filterStatus,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                        isExpanded: true,
                                        items: const [
                                          DropdownMenuItem(value: 'all', child: Text('All statuses')),
                                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                                          DropdownMenuItem(value: 'active', child: Text('Active')),
                                        ],
                                        onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Month', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      DropdownButtonFormField<String>(
                                        value: _filterMonth,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                        isExpanded: true,
                                        items: [
                                          const DropdownMenuItem(value: 'all', child: Text('All months')),
                                          ...List.generate(12, (i) {
                                            const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
                                            return DropdownMenuItem(value: '$i', child: Text(months[i]));
                                          }),
                                        ],
                                        onChanged: (v) => setState(() => _filterMonth = v ?? 'all'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // List section
                        Text(
                          filtered.isEmpty ? 'Shifts' : 'Your shifts (${filtered.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                              child: Column(
                                children: [
                                  Icon(Icons.event_busy, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No shifts found',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No shifts match your filters. Try changing status or month.',
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filtered.map((shift) => _ShiftCard(
                                shift: shift,
                                formatDate: _formatDate,
                                formatTime: _formatTime,
                                formatDuration: _formatDuration,
                                statusColor: _statusColor,
                              )),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value + unit,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final ShiftHistoryItem shift;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;
  final String Function(int) formatDuration;
  final Color Function(String) statusColor;

  const _ShiftCard({
    required this.shift,
    required this.formatDate,
    required this.formatTime,
    required this.formatDuration,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(shift.status);
    final timeLine = shift.endTime != null
        ? '${formatTime(shift.startTime)} – ${formatTime(shift.endTime!)} · ${formatDuration(shift.durationMinutes)}'
        : '${formatTime(shift.startTime)} – In progress';
    final statsLine = '${shift.totalPropertiesCompleted} properties · ${shift.totalZonesCompleted} zones · ${shift.totalDistanceKm.toStringAsFixed(1)} km';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: date + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  formatDate(shift.startTime),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Text(
                    shift.status == 'completed' ? 'Completed' : 'Active',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Shift #${shift.shiftId}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
            // Time line
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeLine,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats: properties · zones · km
            Row(
              children: [
                Icon(Icons.assignment, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statsLine,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
