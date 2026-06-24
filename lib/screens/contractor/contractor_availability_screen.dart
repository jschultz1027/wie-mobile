import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/refresh_icon_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_notification.dart';
import '../auth/login_screen.dart';

/// Contractor Availability Screen - Manage your own availability calendar
/// Matches web: /contractor-availability
class ContractorAvailabilityScreen extends StatefulWidget {
  const ContractorAvailabilityScreen({super.key});

  @override
  State<ContractorAvailabilityScreen> createState() => _ContractorAvailabilityScreenState();
}

class _ContractorAvailabilityScreenState extends State<ContractorAvailabilityScreen> {
  List<AvailabilityBlock> _blocks = [];
  Map<DateTime, List<AvailabilityBlock>> _events = {};
  bool _loading = false;
  String? _error;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    
    if (user == null) {
      _handleSessionExpired();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = StorageService().getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Calculate date range: 1 year back to 1 year forward
      final now = DateTime.now();
      final startDate = DateTime(now.year - 1, now.month, now.day);
      final endDate = DateTime(now.year + 1, now.month, now.day);

      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/availability/${user.id}?start_date=${startDate.toIso8601String()}&end_date=${endDate.toIso8601String()}'
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> blocksData = data['blocks'] ?? [];
        
        setState(() {
          _blocks = blocksData
              .map((b) => AvailabilityBlock.fromJson(b, user.id))
              .toList();
          
          // Build events map
          _events = {};
          for (var block in _blocks) {
            final blockDate = DateTime.parse(block.windowStart);
            final dateKey = DateTime(blockDate.year, blockDate.month, blockDate.day);
            
            if (!_events.containsKey(dateKey)) {
              _events[dateKey] = [];
            }
            _events[dateKey]!.add(block);
          }
          
          _loading = false;
        });
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
      } else {
        throw Exception('Failed to load availability: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('authentication token')) {
        if (mounted) _handleSessionExpired();
        return;
      }
      if (mounted) {
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
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Session Expired'),
          ],
        ),
        content: Text(
          'Your session has expired. Please log in again to continue.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Log In Again'),
          ),
        ],
      ),
    );
  }

  List<AvailabilityBlock> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _createBlock(DateTime date, String status, String? notes, {TimeOfDay? startTime, TimeOfDay? endTime}) async {
    final token = StorageService().getToken();
    if (token == null) {
      AppNotification.error(context, 'No authentication token found');
      return;
    }

    try {
      // Build window_start and window_end
      String windowStart;
      String windowEnd;
      
      if (startTime != null && endTime != null) {
        // Partial day
        final startDateTime = DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute);
        final endDateTime = DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);
        windowStart = startDateTime.toIso8601String();
        windowEnd = endDateTime.toIso8601String();
      } else {
        // Full day (8 AM to 5 PM)
        final startDateTime = DateTime(date.year, date.month, date.day, 8, 0);
        final endDateTime = DateTime(date.year, date.month, date.day, 17, 0);
        windowStart = startDateTime.toIso8601String();
        windowEnd = endDateTime.toIso8601String();
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/availability'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'window_start': windowStart,
          'window_end': windowEnd,
          'status': status,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadAvailability();
        if (mounted) {
          AppNotification.success(context, 'Availability block created successfully');
        }
      } else {
        final error = json.decode(response.body);
        AppNotification.error(context, error['detail'] ?? 'Failed to create block');
      }
    } catch (e) {
      AppNotification.error(context, 'Failed to create block: $e');
    }
  }

  Future<void> _deleteBlock(int blockId) async {
    final token = StorageService().getToken();
    if (token == null) {
      AppNotification.error(context, 'No authentication token found');
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/v1/availability/$blockId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadAvailability();
        if (mounted) {
          AppNotification.success(context, 'Availability block deleted');
        }
      } else {
        AppNotification.error(context, 'Failed to delete block');
      }
    } catch (e) {
      AppNotification.error(context, 'Failed to delete block: $e');
    }
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    final timeLabel = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : 'Select';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            alignment: Alignment.center,
          ),
          child: Text(
            timeLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartEndTimeRow({
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required Future<void> Function() onPickStart,
    required Future<void> Function() onPickEnd,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTimeField(
            label: 'Start',
            time: startTime,
            onTap: onPickStart,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTimeField(
            label: 'End',
            time: endTime,
            onTap: onPickEnd,
          ),
        ),
      ],
    );
  }

  void _showCreateBlockModal(DateTime date) {
    String selectedStatus = 'unavailable';
    bool isPartialDay = false;
    TimeOfDay? startTime = TimeOfDay(hour: 8, minute: 0);
    TimeOfDay? endTime = TimeOfDay(hour: 17, minute: 0);
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create Availability Block',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(date),
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              SizedBox(height: 16),
              Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text('✓ Available'),
                      selected: selectedStatus == 'available',
                      onSelected: (selected) {
                        setModalState(() => selectedStatus = 'available');
                      },
                      selectedColor: Colors.green,
                      labelStyle: TextStyle(color: selectedStatus == 'available' ? Colors.white : Colors.black),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text('🚫 Unavailable'),
                      selected: selectedStatus == 'unavailable',
                      onSelected: (selected) {
                        setModalState(() => selectedStatus = 'unavailable');
                      },
                      selectedColor: Colors.red,
                      labelStyle: TextStyle(color: selectedStatus == 'unavailable' ? Colors.white : Colors.black),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              CheckboxListTile(
                title: Text('Partial Day (Custom Hours)'),
                value: isPartialDay,
                onChanged: (value) {
                  setModalState(() => isPartialDay = value ?? false);
                },
              ),
              if (isPartialDay) ...[
                const SizedBox(height: 8),
                _buildStartEndTimeRow(
                  startTime: startTime,
                  endTime: endTime,
                  onPickStart: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: startTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setModalState(() => startTime = time);
                    }
                  },
                  onPickEnd: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: endTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setModalState(() => endTime = time);
                    }
                  },
                ),
              ],
              SizedBox(height: 16),
              Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: 'e.g., Vacation, Equipment maintenance...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _createBlock(
                      date,
                      selectedStatus,
                      notesController.text.isEmpty ? null : notesController.text,
                      startTime: isPartialDay ? startTime : null,
                      endTime: isPartialDay ? endTime : null,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue600,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Create Block', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayDetailsModal(DateTime day) {
    final blocks = _getEventsForDay(day);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(day),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (blocks.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No availability blocks', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showCreateBlockModal(day);
                        },
                        child: Text('Create Block'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...blocks.map((block) => _buildBlockCard(block)),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showCreateBlockModal(day);
                },
                icon: Icon(Icons.add),
                label: Text('Add Block'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCard(AvailabilityBlock block) {
    final startTime = DateTime.parse(block.windowStart);
    final endTime = DateTime.parse(block.windowEnd);
    final isAvailable = block.status == 'available';
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 4,
          height: double.infinity,
          decoration: BoxDecoration(
            color: isAvailable ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          isAvailable ? '✓ Available' : '🚫 Unavailable',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
            ),
            if (block.notes != null && block.notes!.isNotEmpty) ...[
              SizedBox(height: 4),
              Text(block.notes!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Delete Block?'),
                content: Text('Are you sure you want to delete this availability block?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await _deleteBlock(block.id);
              if (mounted) Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleMassSelect(String period) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    String selectedStatus = 'unavailable';
    bool isPartialDay = false;
    TimeOfDay? startTime = TimeOfDay(hour: 8, minute: 0);
    TimeOfDay? endTime = TimeOfDay(hour: 17, minute: 0);
    final notesController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Mass Selection - ${period == 'week' ? 'This Week' : 'This Month'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set availability for all days:'),
                SizedBox(height: 16),
                Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Available'),
                        selected: selectedStatus == 'available',
                        onSelected: (selected) {
                          setDialogState(() => selectedStatus = 'available');
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Unavailable'),
                        selected: selectedStatus == 'unavailable',
                        onSelected: (selected) {
                          setDialogState(() => selectedStatus = 'unavailable');
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                CheckboxListTile(
                  title: Text('Partial Day'),
                  value: isPartialDay,
                  onChanged: (value) {
                    setDialogState(() => isPartialDay = value ?? false);
                  },
                ),
                if (isPartialDay) ...[
                  const SizedBox(height: 8),
                  _buildStartEndTimeRow(
                    startTime: startTime,
                    endTime: endTime,
                    onPickStart: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: startTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() => startTime = time);
                      }
                    },
                    onPickEnd: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: endTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() => endTime = time);
                      }
                    },
                  ),
                ],
                SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'status': selectedStatus,
                  'isPartialDay': isPartialDay,
                  'startTime': startTime,
                  'endTime': endTime,
                  'notes': notesController.text,
                });
              },
              child: Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    // Calculate date range
    DateTime startDate;
    DateTime endDate;
    if (period == 'week') {
      startDate = _focusedDay.subtract(Duration(days: _focusedDay.weekday % 7));
      endDate = startDate.add(Duration(days: 6));
    } else {
      startDate = DateTime(_focusedDay.year, _focusedDay.month, 1);
      endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    }

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Creating blocks...'),
          ],
        ),
      ),
    );

    int successCount = 0;
    for (var date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
      try {
        await _createBlock(
          date,
          result['status'],
          result['notes']?.isEmpty ?? true ? null : result['notes'],
          startTime: result['isPartialDay'] ? result['startTime'] : null,
          endTime: result['isPartialDay'] ? result['endTime'] : null,
        );
        successCount++;
      } catch (e) {
        print('Error creating block for ${date}: $e');
      }
    }

    if (mounted) {
      Navigator.pop(context); // Close progress dialog
      AppNotification.success(context, 'Created $successCount blocks');
    }
  }

  Future<void> _handleMassDelete(String period) async {
    // Calculate date range
    DateTime startDate;
    DateTime endDate;
    if (period == 'week') {
      // Week starts on Sunday
      final weekday = _focusedDay.weekday % 7; // 0 = Sunday, 1 = Monday, etc.
      startDate = _focusedDay.subtract(Duration(days: weekday));
      endDate = startDate.add(Duration(days: 6));
    } else {
      // Month
      startDate = DateTime(_focusedDay.year, _focusedDay.month, 1);
      endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    }

    // Find all blocks in this range
    final blocksToDelete = _blocks.where((block) {
      final blockDate = DateTime.parse(block.windowStart);
      final blockDay = DateTime(blockDate.year, blockDate.month, blockDate.day);
      return blockDay.isAfter(startDate.subtract(Duration(days: 1))) &&
          blockDay.isBefore(endDate.add(Duration(days: 1)));
    }).toList();

    if (blocksToDelete.isEmpty) {
      AppNotification.info(
        context,
        'No availability blocks found in ${period == 'week' ? 'this week' : 'this month'}.',
      );
      return;
    }

    final unavailableCount = blocksToDelete.where((b) => b.status == 'unavailable').length;
    final availableCount = blocksToDelete.where((b) => b.status == 'available').length;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Delete All Blocks?'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to delete ${blocksToDelete.length} availability block(s) from ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}.',
              ),
              SizedBox(height: 12),
              Text(
                'This action cannot be undone!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blocks to be deleted:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text('• $unavailableCount Unavailable blocks'),
                    Text('• $availableCount Available blocks'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting ${blocksToDelete.length} blocks...'),
          ],
        ),
      ),
    );

    int successCount = 0;
    int failedCount = 0;

    for (final block in blocksToDelete) {
      try {
        await _deleteBlock(block.id);
        successCount++;
      } catch (e) {
        failedCount++;
        print('Error deleting block ${block.id}: $e');
      }
    }

    if (mounted) {
      Navigator.pop(context); // Close progress dialog
      if (successCount > 0) {
        AppNotification.success(
          context,
          'Successfully deleted $successCount block${successCount != 1 ? 's' : ''}',
        );
      }
      if (failedCount > 0) {
        AppNotification.error(
          context,
          'Failed to delete $failedCount block${failedCount != 1 ? 's' : ''}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unavailableCount = _blocks.where((b) => b.status == 'unavailable').length;
    final availableCount = _blocks.where((b) => b.status == 'available').length;

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: Text(
          'My Availability',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          ScreenHelpAction(
            title: 'My Availability',
            message: HelpContent.screenMyAvailability,
          ),
          RefreshIconButton(
            loading: _loading,
            onPressed: _loadAvailability,
          ),
        ],
      ),
      body: _loading && _blocks.isEmpty
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Error: $_error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAvailability,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Stats
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.grey.shade50,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard('Unavailable', unavailableCount, Colors.red),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard('Available', availableCount, Colors.green),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard('Total', _blocks.length, Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    // Mass action buttons
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleMassSelect('week'),
                                  icon: Icon(Icons.calendar_today, size: 16),
                                  label: Text('Mark Week'),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleMassSelect('month'),
                                  icon: Icon(Icons.calendar_month, size: 16),
                                  label: Text('Mark Month'),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleMassDelete('week'),
                                  icon: Icon(Icons.clear, size: 16, color: Colors.red),
                                  label: Text('Clear Week', style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleMassDelete('month'),
                                  icon: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  label: Text('Clear Month', style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Calendar
                    Expanded(
                      child: TableCalendar<AvailabilityBlock>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        calendarFormat: _calendarFormat,
                        eventLoader: _getEventsForDay,
                        startingDayOfWeek: StartingDayOfWeek.sunday,
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: true,
                          weekendTextStyle: TextStyle(color: Colors.red.shade700),
                          selectedDecoration: BoxDecoration(
                            color: AppColors.blue600,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: AppColors.blue400.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: BoxDecoration(
                            color: AppColors.blue600,
                            shape: BoxShape.circle,
                          ),
                          markersMaxCount: 1,
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: true,
                          titleCentered: true,
                          formatButtonShowsNext: false,
                          formatButtonDecoration: BoxDecoration(
                            color: AppColors.blue600,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          formatButtonTextStyle: TextStyle(color: Colors.white, fontSize: 12),
                          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          _showDayDetailsModal(selectedDay);
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                        },
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return SizedBox();
                            final hasAvailable = events.any((e) => e.status == 'available');
                            final hasUnavailable = events.any((e) => e.status == 'unavailable');
                            
                            return Positioned(
                              right: 1,
                              bottom: 1,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: hasUnavailable ? Colors.red : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

/// Availability Block Model
class AvailabilityBlock {
  final int id;
  final int contractorId;
  final String windowStart;
  final String windowEnd;
  final String status;
  final String? notes;

  AvailabilityBlock({
    required this.id,
    required this.contractorId,
    required this.windowStart,
    required this.windowEnd,
    required this.status,
    this.notes,
  });

  factory AvailabilityBlock.fromJson(Map<String, dynamic> json, int contractorId) {
    return AvailabilityBlock(
      id: json['id'] as int,
      contractorId: contractorId,
      windowStart: json['window_start'] as String,
      windowEnd: json['window_end'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }
}
