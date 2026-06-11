import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class AvailabilityCalendarScreen extends StatefulWidget {
  const AvailabilityCalendarScreen({super.key});

  @override
  State<AvailabilityCalendarScreen> createState() => _AvailabilityCalendarScreenState();
}

class _AvailabilityCalendarScreenState extends State<AvailabilityCalendarScreen> {
  List<Contractor> _contractors = [];
  List<int> _selectedContractorIds = [];
  Map<DateTime, List<AvailabilityBlock>> _events = {};
  bool _loading = false;
  String? _error;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _loadContractors();
  }

  Future<void> _loadContractors() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = StorageService().getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/v1/admin/contractors'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        List<dynamic> data;
        
        // Handle both List and Map responses
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData.containsKey('contractors')) {
          data = responseData['contractors'];
        } else if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'];
        } else {
          data = [];
        }
        
        setState(() {
          _contractors = data.map((c) => Contractor.fromJson(c)).toList();
          _loading = false;
        });
        
        // Load availability for all contractors
        if (_contractors.isNotEmpty) {
          _selectedContractorIds = _contractors.map((c) => c.id).toList();
          _loadAvailability();
        }
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
        return;
      } else {
        throw Exception('Failed to load contractors: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAvailability() async {
    print('=== _loadAvailability called ===');
    
    if (_selectedContractorIds.isEmpty) {
      setState(() {
        _events = {};
      });
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

      // Fetch availability for selected contractors
      Map<DateTime, List<AvailabilityBlock>> allEvents = {};
      Set<int> processedBlockIds = {}; // Track processed block IDs to avoid duplicates
      
      for (int contractorId in _selectedContractorIds) {
        final response = await http.get(
          Uri.parse('${AppConfig.baseUrl}/api/v1/admin/contractors/$contractorId/availability'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        print('Availability API response for contractor $contractorId: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('Availability blocks for contractor $contractorId: ${data.length} blocks');
          print('Raw data: ${json.encode(data)}');
          
          for (var blockData in data) {
            final block = AvailabilityBlock.fromJson(blockData, contractorId);
            
            // Check for duplicates
            if (processedBlockIds.contains(block.id)) {
              print('⚠️ DUPLICATE DETECTED: Block ID ${block.id} already processed, skipping');
              continue;
            }
            processedBlockIds.add(block.id);
            
            final blockDate = DateTime.parse(block.windowStart);
            final dateKey = DateTime(blockDate.year, blockDate.month, blockDate.day);
            
            print('Adding block: contractor=$contractorId, id=${block.id}, date=$dateKey');
            
            if (!allEvents.containsKey(dateKey)) {
              allEvents[dateKey] = [];
            }
            allEvents[dateKey]!.add(block);
          }
        } else if (response.statusCode == 401) {
          _handleSessionExpired();
          return;
        } else {
          print('Availability API error for contractor $contractorId (${response.statusCode}): ${response.body}');
        }
      }

      setState(() {
        _events = allEvents;
        _loading = false;
      });
      
      print('=== Final events summary ===');
      print('Total events loaded: ${allEvents.length} dates with data');
      allEvents.forEach((date, blocks) {
        print('  Date $date: ${blocks.length} blocks');
        for (var block in blocks) {
          print('    - Contractor ${block.contractorId}, Block ID ${block.id}');
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleSessionExpired() async {
    await StorageService().clearAll();
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer_off, color: AppColors.error),
            SizedBox(width: 12),
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

  void _showContractorSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Contractors',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedContractorIds = _contractors.map((c) => c.id).toList();
                          });
                          setState(() {});
                          _loadAvailability();
                        },
                        child: Text('Select All'),
                      ),
                      SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedContractorIds = [];
                          });
                          setState(() {});
                          _loadAvailability();
                        },
                        child: Text('Clear All'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _contractors.length,
                      itemBuilder: (context, index) {
                        final contractor = _contractors[index];
                        final isSelected = _selectedContractorIds.contains(contractor.id);
                        
                        return CheckboxListTile(
                          title: Text(contractor.fullName),
                          subtitle: Text(contractor.email),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                _selectedContractorIds.add(contractor.id);
                              } else {
                                _selectedContractorIds.remove(contractor.id);
                              }
                            });
                            setState(() {});
                            _loadAvailability();
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<AvailabilityBlock> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  int _getEventCount(DateTime day) {
    return _getEventsForDay(day).length;
  }

  void _showDayDetailsModal(DateTime day) {
    final blocks = _getEventsForDay(day);
    if (blocks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.blue600.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: AppColors.blue600,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(day),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            DateFormat('MMMM d, yyyy').format(day),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.blue600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '${blocks.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Divider(height: 1),
              
              // Contractor list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: blocks.length,
                  itemBuilder: (context, index) {
                    final block = blocks[index];
                    final contractor = _contractors.firstWhere(
                      (c) => c.id == block.contractorId,
                      orElse: () => Contractor(
                        id: block.contractorId,
                        fullName: 'Unknown',
                        email: '',
                      ),
                    );
                    
                    final startTime = DateTime.parse(block.windowStart);
                    final endTime = DateTime.parse(block.windowEnd);
                    final duration = endTime.difference(startTime);
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getStatusColor(block.status).withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            // Could show more details or actions
                          },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _getStatusColor(block.status),
                                            _getStatusColor(block.status).withOpacity(0.7),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          contractor.fullName.substring(0, 1).toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            contractor.fullName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.slate900,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            contractor.email,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(block.status),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        block.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.blue600.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time, size: 20, color: AppColors.blue600),
                                      SizedBox(width: 8),
                                      Text(
                                        '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.slate900,
                                        ),
                                      ),
                                      Spacer(),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.blue600.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.schedule, size: 14, color: AppColors.blue600),
                                            SizedBox(width: 4),
                                            Text(
                                              '${duration.inHours}h ${duration.inMinutes % 60}m',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.blue600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (block.notes != null && block.notes!.isNotEmpty) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.notes, size: 16, color: Colors.grey.shade600),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            block.notes!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'on-shift':
        return Colors.orange;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Availability Calendar',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showContractorSelector,
            tooltip: 'Filter Contractors',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading ? null : _loadAvailability,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && _contractors.isEmpty
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
                        onPressed: _loadContractors,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Selected Contractors Count
                    if (_selectedContractorIds.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: AppColors.blue400.withOpacity(0.1),
                        child: Row(
                          children: [
                            Icon(Icons.people, color: AppColors.blue600, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Showing ${_selectedContractorIds.length} contractor${_selectedContractorIds.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.blue600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Calendar
                    TableCalendar<AvailabilityBlock>(
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
                        holidayTextStyle: TextStyle(color: Colors.red.shade700),
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
                        formatButtonTextStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        titleTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        // Show modal with contractor details
                        _showDayDetailsModal(selectedDay);
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (events.isEmpty) return SizedBox();
                          final count = events.length;
                          return Positioned(
                            right: 1,
                            bottom: 1,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.blue600, AppColors.blue600.withOpacity(0.8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.blue600.withOpacity(0.4),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Center(
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Instruction message below calendar
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 56,
                              color: AppColors.blue600.withOpacity(0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Tap on a date',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.slate900,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'to view available contractors',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.blue600, AppColors.blue600.withOpacity(0.8)],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.blue600.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '3',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Badge shows available contractors',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class Contractor {
  final int id;
  final String fullName;
  final String email;

  Contractor({
    required this.id,
    required this.fullName,
    required this.email,
  });

  factory Contractor.fromJson(Map<String, dynamic> json) {
    return Contractor(
      id: json['id'],
      fullName: json['full_name'] ?? json['email'],
      email: json['email'],
    );
  }
}

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
      id: json['id'],
      contractorId: contractorId,
      windowStart: json['window_start'],
      windowEnd: json['window_end'],
      status: json['status'],
      notes: json['notes'],
    );
  }
}
