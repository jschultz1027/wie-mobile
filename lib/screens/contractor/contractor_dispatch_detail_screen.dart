import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../models/contractor_assignment.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/app_notification.dart';
import '../auth/login_screen.dart';

/// Contractor Dispatch Detail Screen - On-site workflow (matches web step-by-step)
/// Per zone: 1) Before photo (capture + upload) 2) Do work 3) After photo (capture + upload)
/// Then: 5) Submit report (final notes + equipment)
class ContractorDispatchDetailScreen extends StatefulWidget {
  final int assignmentId;
  final ContractorAssignment? assignment;

  const ContractorDispatchDetailScreen({
    super.key,
    required this.assignmentId,
    this.assignment,
  });

  @override
  State<ContractorDispatchDetailScreen> createState() => _ContractorDispatchDetailScreenState();
}

class _ContractorDispatchDetailScreenState extends State<ContractorDispatchDetailScreen> {
  final ImagePicker _picker = ImagePicker();

  ContractorAssignment? _assignment;
  bool _loading = true;
  TargetZone? _selectedZone;
  XFile? _beforePhoto;
  XFile? _afterPhoto;
  bool _uploadingBefore = false;
  bool _uploadingAfter = false;

  final TextEditingController _finalNotesController = TextEditingController();
  final TextEditingController _equipmentUsedController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignment != null) {
      _assignment = widget.assignment;
      _loading = false;
    } else {
      _fetchAssignment();
    }
  }

  @override
  void dispose() {
    _finalNotesController.dispose();
    _equipmentUsedController.dispose();
    super.dispose();
  }

  Future<void> _fetchAssignment() async {
    final token = StorageService().getToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/assignments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['assignments'] as List<dynamic>? ?? [];
        final matches = list.cast<Map<String, dynamic>>().where((a) => (a['id'] as num).toInt() == widget.assignmentId);
        final match = matches.isEmpty ? null : matches.first;
        if (match != null) {
          setState(() {
            _assignment = ContractorAssignment.fromJson(match);
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      } else if (response.statusCode == 401 && mounted) {
        _handleSessionExpired();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      AppNotification.error(context, 'Failed to load assignment');
    }
  }

  List<TargetZone> get _zones => _assignment?.targetZones ?? [];
  int get _completedCount => _zones.where((z) => z.status == 'completed').length;
  bool get _allZonesComplete => _zones.isNotEmpty && _completedCount == _zones.length;

  Future<void> _uploadBeforePhoto() async {
    if (_selectedZone == null || _beforePhoto == null) return;

    final token = StorageService().getToken();
    if (token == null) return;

    setState(() => _uploadingBefore = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/dispatches/${widget.assignmentId}/zones/${_selectedZone!.zoneId}/complete'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('before_photo', _beforePhoto!.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final beforeUrl = data['before_photo_url'] as String?;
        if (beforeUrl != null) {
          setState(() {
            _selectedZone = TargetZone(
              zoneId: _selectedZone!.zoneId,
              zoneName: _selectedZone!.zoneName,
              status: 'in_progress',
              beforePhotoUrl: beforeUrl,
              afterPhotoUrl: _selectedZone!.afterPhotoUrl,
            );
            _beforePhoto = null;
            _uploadingBefore = false;
          });
          await _refreshAssignment();
          AppNotification.success(context, 'Before photo saved. Complete the work, then take the AFTER photo.');
        }
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
      } else {
        AppNotification.error(context, 'Failed to upload: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingBefore = false);
    }
  }

  Future<void> _uploadAfterPhoto() async {
    if (_selectedZone == null || _afterPhoto == null) return;

    final token = StorageService().getToken();
    if (token == null) return;

    setState(() => _uploadingAfter = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/dispatches/${widget.assignmentId}/zones/${_selectedZone!.zoneId}/complete'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('after_photo', _afterPhoto!.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _selectedZone = null;
          _afterPhoto = null;
          _uploadingAfter = false;
        });
        await _refreshAssignment();
        final data = json.decode(response.body) as Map<String, dynamic>;
        final allDone = data['all_zones_completed'] as bool? ?? false;
        if (allDone) {
          AppNotification.success(context, 'All zones completed! You can now finish the job.');
        } else {
          AppNotification.success(context, 'Zone completed!');
        }
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
      } else {
        AppNotification.error(context, 'Failed to upload: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingAfter = false);
    }
  }

  Future<void> _refreshAssignment() async {
    await _fetchAssignment();
    if (_selectedZone != null && _assignment != null) {
      final matches = _assignment!.targetZones.where((z) => z.zoneId == _selectedZone!.zoneId);
      final updated = matches.isEmpty ? null : matches.first;
      if (updated != null) setState(() => _selectedZone = updated);
    }
  }

  Future<void> _captureBeforePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear);
      if (photo != null && mounted) setState(() => _beforePhoto = photo);
    } catch (e) {
      AppNotification.error(context, 'Camera error: $e');
    }
  }

  Future<void> _captureAfterPhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear);
      if (photo != null && mounted) setState(() => _afterPhoto = photo);
    } catch (e) {
      AppNotification.error(context, 'Camera error: $e');
    }
  }

  Future<void> _submitReport() async {
    if (!_allZonesComplete) {
      AppNotification.warning(context, 'Complete all zone photos before finishing.');
      return;
    }
    if (_finalNotesController.text.trim().isEmpty || _equipmentUsedController.text.trim().isEmpty) {
      AppNotification.warning(context, 'Final notes and equipment used are required.');
      return;
    }

    final token = StorageService().getToken();
    if (token == null) return;

    setState(() => _submitting = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/assignments/${widget.assignmentId}/finish'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'final_notes': _finalNotesController.text.trim(),
          'equipment_used': _equipmentUsedController.text.trim(),
          'application_intensity': 'medium',
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>?;
        if (data?['success'] == true) {
          AppNotification.success(context, 'Job completed and report submitted.');
          Navigator.pop(context);
        } else {
          AppNotification.error(context, data?['message'] ?? 'Could not finish job.');
        }
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
      } else {
        AppNotification.error(context, 'Failed to submit: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, 'Network error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: Text(
          _assignment?.propertyName ?? 'Job Workflow',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assignment == null
              ? const Center(child: Text('Assignment not found'))
              : _zones.isEmpty
                  ? _buildNoZonesView()
                  : RefreshIndicator(
                      onRefresh: _refreshAssignment,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProgressHeader(),
                            const SizedBox(height: 16),
                            _buildZoneList(),
                            if (_selectedZone != null) ...[
                              const SizedBox(height: 16),
                              _buildZonePhotoCard(),
                            ],
                            if (_allZonesComplete) ...[
                              const SizedBox(height: 24),
                              _buildFinalReportCard(),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submitting ? null : _submitReport,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade600,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: _submitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text('Submit Report & Finish Job', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildNoZonesView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 64, color: Colors.orange.shade700),
            const SizedBox(height: 16),
            const Text('No zones defined for this property.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Complete zone photos on the web app, or add zones to this property first.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Job Workflow – 5 Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('1. Check in (done from My Shifts)', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            Text('2. Per zone: Capture BEFORE photo → Upload', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            Text('3. Perform the work on that zone', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            Text('4. Per zone: Capture AFTER photo → Upload', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            Text('5. Submit report (notes + equipment)', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Text(
              '$_completedCount / ${_zones.length} zones completed',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _allZonesComplete ? Colors.green.shade700 : Colors.blue.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneList() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._zones.asMap().entries.map((e) {
              final zone = e.value;
              final idx = e.key + 1;
              final isCompleted = zone.status == 'completed';
              final hasBefore = zone.beforePhotoUrl != null && zone.beforePhotoUrl!.isNotEmpty;
              final isSelected = _selectedZone?.zoneId == zone.zoneId;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isSelected ? Colors.blue.shade50 : (isCompleted ? Colors.green.shade50 : null),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCompleted ? Colors.green : (hasBefore ? Colors.blue : Colors.grey.shade300),
                    child: Text(isCompleted ? '✓' : '$idx', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(zone.zoneName ?? 'Zone ${zone.zoneId}', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                  subtitle: Text(
                    isCompleted ? 'Completed' : (hasBefore ? 'Before done – take AFTER photo' : 'Pending – take BEFORE photo'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: isCompleted ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.chevron_right),
                  onTap: isCompleted ? null : () => setState(() {
                    _selectedZone = zone;
                    _beforePhoto = null;
                    _afterPhoto = null;
                  }),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildZonePhotoCard() {
    final zone = _selectedZone!;
    final hasBeforeSaved = zone.beforePhotoUrl != null && zone.beforePhotoUrl!.isNotEmpty;
    final isStepBefore = !hasBeforeSaved;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStepBefore ? 'Step 2: Before Photo' : 'Step 4: After Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isStepBefore ? Colors.blue.shade700 : Colors.green.shade700),
            ),
            Text(zone.zoneName ?? 'Zone ${zone.zoneId}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 12),

            if (isStepBefore) ...[
              if (zone.beforePhotoUrl != null && zone.beforePhotoUrl!.isNotEmpty)
                const Text('Before photo already saved.', style: TextStyle(color: Colors.green))
              else ...[
                if (_beforePhoto == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _uploadingBefore ? null : _captureBeforePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture Before Photo'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  )
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_beforePhoto!.path), height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _uploadingBefore ? null : () => setState(() => _beforePhoto = null),
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _uploadingBefore ? null : _uploadBeforePhoto,
                          child: _uploadingBefore
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              : const Text('Save Before Photo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ] else ...[
              if (zone.beforePhotoUrl != null && zone.beforePhotoUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Before (saved):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(zone.beforePhotoUrl!, height: 80, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 48)),
                      ),
                    ],
                  ),
                ),
              const Text('Now capture the AFTER photo:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              if (_afterPhoto == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _uploadingAfter ? null : _captureAfterPhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture After Photo'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_afterPhoto!.path), height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _uploadingAfter ? null : () => setState(() => _afterPhoto = null),
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _uploadingAfter ? null : _uploadAfterPhoto,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                        child: _uploadingAfter
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Text('Save After Photo'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinalReportCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Final Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _finalNotesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Final Notes *',
                border: OutlineInputBorder(),
                hintText: 'Observations, challenges, site notes...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _equipmentUsedController,
              decoration: const InputDecoration(
                labelText: 'Equipment Used *',
                border: OutlineInputBorder(),
                hintText: 'e.g. Truck with salter, shovels, de-icer',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
