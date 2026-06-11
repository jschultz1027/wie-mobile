import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../models/contractor_assignment.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/contractor_assignment_service.dart';
import '../../utils/app_notification.dart';
import '../auth/login_screen.dart';
import 'contractor_dispatch_detail_screen.dart';

/// Contractor Dispatches Screen - Shift Management & Assignment List
/// Matches web: /contractor-dispatches
class ContractorDispatchesScreen extends StatefulWidget {
  const ContractorDispatchesScreen({super.key});

  @override
  State<ContractorDispatchesScreen> createState() => _ContractorDispatchesScreenState();
}

class _ContractorDispatchesScreenState extends State<ContractorDispatchesScreen> {
  final ContractorAssignmentService _assignmentService = ContractorAssignmentService();
  
  List<ContractorAssignment> _assignments = [];
  ShiftStatus? _currentShift;
  bool _loading = true;
  String? _error;
  String? _actionLoading;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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

  Future<void> _loadData() async {
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

    await Future.wait([
      _loadAssignments(),
      _loadCurrentShift(),
    ]);
  }

  Future<void> _loadAssignments() async {
    try {
      final assignments = await _assignmentService.getAssignments();
      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _error = null;
        _loading = false;
      });
    } on ContractorAssignmentException catch (e) {
      if (e.isUnauthorized && mounted) {
        _handleSessionExpired();
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCurrentShift() async {
    final token = StorageService().getToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/shifts/current'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentShift = ShiftStatus.fromJson(data);
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _currentShift = null;
        });
      }
    } catch (e) {
      // Shift not found is okay
      setState(() {
        _currentShift = null;
      });
    }
  }

  Future<void> _startShift() async {
    setState(() => _actionLoading = 'start-shift');
    final token = StorageService().getToken();
    if (token == null) {
      AppNotification.error(context, 'No authentication token found');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/shifts/start'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentShift = ShiftStatus.fromJson(data);
        });
        AppNotification.success(context, 'Shift Started! Safe travels. Stay focused and work safely.');
        await _loadData();
      } else {
        final error = json.decode(response.body);
        AppNotification.error(context, error['detail'] ?? 'Failed to start shift');
      }
    } catch (e) {
      AppNotification.error(context, 'Network error: $e');
    } finally {
      setState(() => _actionLoading = null);
    }
  }

  Future<void> _endShift() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('End Shift?'),
          ],
        ),
        content: Text('Are you sure you want to end your shift?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Yes, End Shift', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading = 'end-shift');
    final token = StorageService().getToken();
    if (token == null) {
      AppNotification.error(context, 'No authentication token found');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/shifts/end'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentShift = null;
        });
        
        final completed = data['total_properties_completed'] ?? 0;
        final zones = data['total_zones_completed'] ?? 0;
        final distance = data['total_distance_km'] ?? 0.0;
        
        AppNotification.success(
          context,
          'Shift Ended!\nProperties: $completed\nZones: $zones\nDistance: ${distance.toStringAsFixed(1)} km',
        );
        await _loadData();
      } else {
        final error = json.decode(response.body);
        AppNotification.error(context, error['detail'] ?? 'Failed to end shift');
      }
    } catch (e) {
      AppNotification.error(context, 'Network error: $e');
    } finally {
      setState(() => _actionLoading = null);
    }
  }

  Future<void> _checkIn(ContractorAssignment assignment) async {
    final assignmentId = assignment.id;
    if (_currentShift == null) {
      AppNotification.warning(context, 'Please start your shift before checking in to a property.');
      return;
    }

    setState(() => _actionLoading = 'checkin-$assignmentId');
    final token = StorageService().getToken();
    if (token == null) {
      AppNotification.error(context, 'No authentication token found');
      return;
    }

    try {
      // Get current GPS location from device (if permission granted)
      double? latitude;
      double? longitude;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.deniedForever) {
          AppNotification.warning(
            context,
            'Location permission is permanently denied. Enable it in system settings to include GPS on check-in.',
          );
        } else if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (e) {
        // If GPS fails, we still attempt check-in without coordinates
        debugPrint('GPS error during check-in: $e');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/shifts/assignments/$assignmentId/checkin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 200) {
        AppNotification.success(context, 'Checked In! Opening zones for you to work on...');
        await Future.delayed(Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContractorDispatchDetailScreen(assignmentId: assignmentId, assignment: assignment),
            ),
          ).then((_) => _loadData());
        }
      } else {
        final error = json.decode(response.body);
        if (error['detail']?.toString().toLowerCase().contains('already checked in') == true) {
          AppNotification.info(context, 'Already checked in. Opening zones...');
          await Future.delayed(Duration(milliseconds: 1500));
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContractorDispatchDetailScreen(assignmentId: assignmentId, assignment: assignment),
              ),
            ).then((_) => _loadData());
          }
        } else {
          AppNotification.error(context, error['detail'] ?? 'Check-in failed');
        }
      }
    } catch (e) {
      AppNotification.error(context, 'Network error: $e');
    } finally {
      setState(() => _actionLoading = null);
    }
  }

  Future<void> _checkOut(int assignmentId) async {
    setState(() => _actionLoading = 'checkout-$assignmentId');
    final token = StorageService().getToken();
    if (token == null) {
      AppNotification.error(context, 'No authentication token found');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/shifts/assignments/$assignmentId/checkout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        AppNotification.success(context, 'Property Completed! Moving to next assignment.');
        await _loadData();
      } else {
        final error = json.decode(response.body);
        final isZoneError = error['detail']?.toString().toLowerCase().contains('zone') == true;
        AppNotification.error(
          context,
          isZoneError ? 'Incomplete Zones' : 'Check-Out Failed',
        );
      }
    } catch (e) {
      AppNotification.error(context, 'Network error: $e');
    } finally {
      setState(() => _actionLoading = null);
    }
  }

  Future<void> _navigateToProperty(ContractorAssignment assignment) async {
    if (assignment.propertyLatitude == null || assignment.propertyLongitude == null) {
      AppNotification.warning(
        context,
        'GPS coordinates not available for this property. Please check the property address manually.',
      );
      return;
    }

    try {
      // Try Google Maps URL first (works on both Android and iOS)
      final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${assignment.propertyLatitude},${assignment.propertyLongitude}',
      );
      
      try {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // If Google Maps fails, try Apple Maps (iOS) or geo: scheme (Android)
        try {
          final appleMapsUrl = Uri.parse(
            'https://maps.apple.com/?daddr=${assignment.propertyLatitude},${assignment.propertyLongitude}',
          );
          await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
          return;
        } catch (e2) {
          // Last resort: geo: scheme (works on Android)
          try {
            final geoUrl = Uri.parse(
              'geo:${assignment.propertyLatitude},${assignment.propertyLongitude}?q=${assignment.propertyLatitude},${assignment.propertyLongitude}(${Uri.encodeComponent(assignment.propertyName)})',
            );
            await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
          } catch (e3) {
            AppNotification.error(
              context,
              'Could not open navigation app. Please install Google Maps or Apple Maps.',
            );
          }
        }
      }
    } catch (e) {
      AppNotification.error(
        context,
        'Failed to open navigation: ${e.toString()}',
      );
    }
  }

  Future<void> _reorderAssignment(int assignmentId, bool moveUp) async {
    final index = _assignments.indexWhere((a) => a.id == assignmentId);
    if (index == -1) return;

    final newIndex = moveUp ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= _assignments.length) return;

    // Update UI immediately
    final assignment = _assignments.removeAt(index);
    _assignments.insert(newIndex, assignment);
    setState(() {});

    // Send to backend
    final token = StorageService().getToken();
    if (token == null) return;

    try {
      final assignmentIds = _assignments.map((a) => a.id).toList();
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/shifts/assignments/reorder'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'assignment_ids': assignmentIds,
        }),
      );
    } catch (e) {
      // Revert on error
      await _loadAssignments();
      AppNotification.error(context, 'Failed to reorder assignments');
    }
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final pendingAssignments = _assignments
        .where((a) =>
            a.status == 'assigned' ||
            a.status == 'in_progress' ||
            a.status == 'pending')
        .toList();
    final completedAssignments = _assignments.where((a) => a.status == 'completed').toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Shifts',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
      body: _loading && _assignments.isEmpty
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shift Control Card
                        _buildShiftControlCard(),
                        SizedBox(height: 16),

                        // Pending Assignments
                        if (pendingAssignments.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Today\'s Assignments (${pendingAssignments.length})',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Tap arrows to reorder',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          ...pendingAssignments.asMap().entries.map((entry) {
                            final index = entry.key;
                            final assignment = entry.value;
                            return _buildAssignmentCard(assignment, index + 1, true);
                          }),
                          SizedBox(height: 24),
                        ],

                        // Completed Assignments
                        if (completedAssignments.isNotEmpty) ...[
                          Text(
                            'Completed Today (${completedAssignments.length})',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          ...completedAssignments.map((assignment) => _buildCompletedCard(assignment)),
                        ],

                        // Empty State
                        if (_assignments.isEmpty)
                          Container(
                            padding: EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                                SizedBox(height: 16),
                                Text(
                                  'No Assignments',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'You don\'t have any assignments yet. Check back later.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildShiftControlCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: _currentShift == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to start?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Begin your shift to start working on assignments',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _actionLoading == 'start-shift' ? null : _startShift,
                      icon: Icon(Icons.play_arrow),
                      label: Text(_actionLoading == 'start-shift' ? 'Starting...' : 'Start Shift'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.timer, color: Colors.green, size: 24),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shift Active',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    _formatDuration(_currentShift!.durationMinutes),
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _actionLoading == 'end-shift' ? null : _endShift,
                        icon: Icon(Icons.stop, size: 18),
                        label: Text(_actionLoading == 'end-shift' ? 'Ending...' : 'End Shift'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Completed',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Text(
                              '${_currentShift!.completedCount} / ${_currentShift!.assignmentsCount}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade300),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Properties',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Text(
                              '${_currentShift!.totalPropertiesCompleted}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAssignmentCard(ContractorAssignment assignment, int sequenceNumber, bool isPending) {
    final isCheckedIn = assignment.actualStart != null;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sequence Number
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.blue400.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$sequenceNumber',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.blue600),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Reorder buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_upward, size: 16),
                      onPressed: sequenceNumber > 1
                          ? () => _reorderAssignment(assignment.id, true)
                          : null,
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      iconSize: 16,
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_downward, size: 16),
                      onPressed: sequenceNumber < _assignments.length
                          ? () => _reorderAssignment(assignment.id, false)
                          : null,
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      iconSize: 16,
                    ),
                  ],
                ),
                SizedBox(width: 8),
                // Property Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.propertyName,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              assignment.propertyAddress,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            label: Text(assignment.serviceType),
                            labelStyle: TextStyle(fontSize: 11),
                            padding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Text(
                            '${assignment.zonesCompleted}/${assignment.zonesTotal} zones',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          if (isCheckedIn) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Checked In',
                                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isCheckedIn) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToProperty(assignment),
                      icon: Icon(Icons.navigation, size: 18),
                      label: Text('Navigate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue600,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _currentShift == null || _actionLoading?.startsWith('checkin') == true
                          ? null
                          : () => _checkIn(assignment),
                      icon: Icon(Icons.pin_drop, size: 18),
                      label: Text(_actionLoading == 'checkin-${assignment.id}' ? 'Checking In...' : 'Start Work'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContractorDispatchDetailScreen(assignmentId: assignment.id, assignment: assignment),
                          ),
                        ).then((_) => _loadData());
                      },
                      icon: Icon(Icons.checklist, size: 18),
                      label: Text('Work on Zones'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _actionLoading?.startsWith('checkout') == true
                          ? null
                          : () => _checkOut(assignment.id),
                      icon: Icon(Icons.check_circle, size: 18),
                      label: Text(_actionLoading == 'checkout-${assignment.id}' ? 'Checking Out...' : 'Check Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(ContractorAssignment assignment) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 32, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.propertyName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    assignment.propertyAddress,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '✓ All ${assignment.zonesTotal} zones completed',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shift Status Model
class ShiftStatus {
  final int shiftId;
  final int contractorId;
  final DateTime startTime;
  final String status;
  final int durationMinutes;
  final int totalPropertiesCompleted;
  final int assignmentsCount;
  final int completedCount;
  final int pendingCount;

  ShiftStatus({
    required this.shiftId,
    required this.contractorId,
    required this.startTime,
    required this.status,
    required this.durationMinutes,
    required this.totalPropertiesCompleted,
    required this.assignmentsCount,
    required this.completedCount,
    required this.pendingCount,
  });

  factory ShiftStatus.fromJson(Map<String, dynamic> json) {
    return ShiftStatus(
      shiftId: json['shift_id'] as int,
      contractorId: json['contractor_id'] as int,
      startTime: DateTime.parse(json['start_time'] as String),
      status: json['status'] as String,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      totalPropertiesCompleted: json['total_properties_completed'] as int? ?? 0,
      assignmentsCount: json['assignments_count'] as int? ?? 0,
      completedCount: json['completed_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
    );
  }
}
