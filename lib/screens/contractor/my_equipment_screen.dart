import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:toastification/toastification.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import 'video_player_screen.dart';

class MyEquipmentScreen extends StatefulWidget {
  const MyEquipmentScreen({super.key});

  @override
  State<MyEquipmentScreen> createState() => _MyEquipmentScreenState();
}

class _MyEquipmentScreenState extends State<MyEquipmentScreen> {
  List<EquipmentItem> _equipment = [];
  bool _loading = false;
  String? _error;
  bool _showAddModal = false;
  String? _activeType;
  bool _saving = false;
  int? _editingId; // Track which equipment is being edited

  // Form states for Truck
  bool _truckPlowBlade = false;
  bool _truckSalter = false;
  int _truckUnits = 1;
  File? _truckVideo;

  // Form states for ATV
  bool _atvPlowBlade = false;
  bool _atvSalter = false;
  int _atvUnits = 1;
  File? _atvVideo;

  // Form states for Sidewalk Salter
  int _sidewalkUnits = 1;
  File? _sidewalkVideo;

  // Form states for Manual
  bool _manualBucketSalting = false;
  bool _manualShoveling = false;
  int _manualUnits = 1;

  // Form states for Snowblower
  int _snowblowerUnits = 1;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = StorageService().getToken();
      
      if (token == null || token.isEmpty) {
        _handleSessionExpired();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/equipment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        // Token expired - handle gracefully
        _handleSessionExpired();
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _equipment = data.map((item) => EquipmentItem.fromJson(item)).toList();
          _loading = false;
        });
      } else {
        throw Exception('Failed to load equipment: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        final File videoFile = File(video.path);
        final fileSize = await videoFile.length();
        
        // Check file size (max 200MB)
        if (fileSize > 200 * 1024 * 1024) {
          _showSnackBar('Video file must be less than 200MB', isError: true);
          return;
        }

        setState(() {
          if (_activeType == 'truck') {
            _truckVideo = videoFile;
          } else if (_activeType == 'atv') {
            _atvVideo = videoFile;
          } else if (_activeType == 'sidewalk_salter') {
            _sidewalkVideo = videoFile;
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error picking video: $e', isError: true);
    }
  }

  Future<void> _saveEquipment() async {
    if (_activeType == null) return;

    setState(() => _saving = true);

    try {
      final token = StorageService().getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }

      // Prepare equipment data
      final Map<String, dynamic> equipmentData = {
        'equipment_type': _activeType,
        'units': 1,
        'has_plow_blade': false,
        'has_salter': false,
        'hand_bucket_salting': false,
        'hand_shoveling': false,
      };

      // Add id if editing
      if (_editingId != null) {
        equipmentData['id'] = _editingId;
      }

      File? videoFile;

      switch (_activeType) {
        case 'truck':
          equipmentData['units'] = _truckUnits;
          equipmentData['has_plow_blade'] = _truckPlowBlade;
          equipmentData['has_salter'] = _truckSalter;
          videoFile = _truckVideo;
          break;
        case 'atv':
          equipmentData['units'] = _atvUnits;
          equipmentData['has_plow_blade'] = _atvPlowBlade;
          equipmentData['has_salter'] = _atvSalter;
          videoFile = _atvVideo;
          break;
        case 'sidewalk_salter':
          equipmentData['units'] = _sidewalkUnits;
          videoFile = _sidewalkVideo;
          break;
        case 'manual':
          equipmentData['units'] = _manualUnits;
          equipmentData['hand_bucket_salting'] = _manualBucketSalting;
          equipmentData['hand_shoveling'] = _manualShoveling;
          break;
        case 'snowblower':
          equipmentData['units'] = _snowblowerUnits;
          break;
      }

      // Save equipment (POST handles both create and update)
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/equipment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(equipmentData),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save equipment');
      }

      final savedEquipment = json.decode(response.body);

      // Upload video if present (only for new videos)
      if (videoFile != null && savedEquipment['id'] != null) {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/equipment/${savedEquipment['id']}/video'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(await http.MultipartFile.fromPath('file', videoFile.path));

        final uploadResponse = await request.send();
        if (uploadResponse.statusCode != 200) {
          throw Exception('Failed to upload video');
        }
      }

      _showSnackBar(_editingId != null ? 'Equipment updated successfully!' : 'Equipment saved successfully!');
      setState(() {
        _showAddModal = false;
        _activeType = null;
        _saving = false;
      });
      _resetForm();
      await _loadEquipment();
    } catch (e) {
      setState(() => _saving = false);
      _showSnackBar('Failed to save equipment: $e', isError: true);
    }
  }

  Future<void> _deleteEquipment(int equipmentId, String equipmentType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Equipment'),
        content: Text('Are you sure you want to delete this ${equipmentType.replaceAll('_', ' ')} equipment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = StorageService().getToken();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/v1/contractors/equipment/$equipmentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showSnackBar('Equipment deleted successfully!');
        await _loadEquipment();
      } else {
        throw Exception('Failed to delete equipment');
      }
    } catch (e) {
      _showSnackBar('Failed to delete equipment: $e', isError: true);
    }
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _truckPlowBlade = false;
      _truckSalter = false;
      _truckUnits = 1;
      _truckVideo = null;
      _atvPlowBlade = false;
      _atvSalter = false;
      _atvUnits = 1;
      _atvVideo = null;
      _sidewalkUnits = 1;
      _sidewalkVideo = null;
      _manualBucketSalting = false;
      _manualShoveling = false;
      _manualUnits = 1;
      _snowblowerUnits = 1;
    });
  }

  void _editEquipment(EquipmentItem item) {
    setState(() {
      _editingId = item.id;
      _activeType = item.equipmentType;
      _showAddModal = true;

      // Populate form based on equipment type
      switch (item.equipmentType) {
        case 'truck':
          _truckUnits = item.units;
          _truckPlowBlade = item.hasPlowBlade;
          _truckSalter = item.hasSalter;
          break;
        case 'atv':
          _atvUnits = item.units;
          _atvPlowBlade = item.hasPlowBlade;
          _atvSalter = item.hasSalter;
          break;
        case 'sidewalk_salter':
          _sidewalkUnits = item.units;
          break;
        case 'manual':
          _manualUnits = item.units;
          _manualBucketSalting = item.handBucketSalting;
          _manualShoveling = item.handShoveling;
          break;
        case 'snowblower':
          _snowblowerUnits = item.units;
          break;
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    toastification.show(
      context: context,
      type: isError ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topCenter,
    );
  }

  Future<void> _handleSessionExpired() async {
    setState(() {
      _loading = false;
      _error = null;
    });

    // Clear auth data
    await StorageService().clearAll();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    // Show friendly dialog
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Session Expired'),
          ],
        ),
        content: const Text(
          'Your session has expired for security reasons. Please log in again to continue.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate back to login and clear all routes
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log In Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
          backgroundColor: AppColors.slate900,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: const AppMenuButton(),
          title: const Text(
            'My Equipment',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          actions: [
            ScreenHelpAction(
              title: 'My Equipment',
              message: HelpContent.screenMyEquipment,
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                setState(() {
                  _showAddModal = true;
                  _activeType = null;
                });
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadEquipment,
          child: _buildBody(),
        ),
    );
  }

  Widget _buildBody() {
    if (_loading && _equipment.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Error Loading Equipment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadEquipment,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_equipment.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 24),
              Text(
                'No Equipment Added',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Get started by adding your first equipment',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAddModal = true;
                    _activeType = null;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Equipment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Equipment Inventory',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_equipment.length} ${_equipment.length == 1 ? 'item' : 'items'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._equipment.map((item) => _buildEquipmentCard(item)).toList(),
          ],
        ),
        if (_showAddModal) _buildAddEquipmentModal(),
      ],
    );
  }

  Widget _buildEquipmentCard(EquipmentItem item) {
    IconData icon;
    Color color;

    switch (item.equipmentType) {
      case 'truck':
        icon = Icons.local_shipping;
        color = Colors.blue;
        break;
      case 'atv':
        icon = Icons.air;
        color = Colors.green;
        break;
      case 'sidewalk_salter':
        icon = Icons.ac_unit;
        color = Colors.cyan;
        break;
      case 'manual':
        icon = Icons.person;
        color = Colors.grey;
        break;
      case 'snowblower':
        icon = Icons.ac_unit;
        color = Colors.purple;
        break;
      default:
        icon = Icons.build;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.equipmentType.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.units} ${item.units == 1 ? 'unit' : 'units'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.verified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 3),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.yellow.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Features
          if (item.hasPlowBlade || item.hasSalter || item.handBucketSalting || item.handShoveling)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (item.hasPlowBlade)
                    _buildFeatureChip('Plow Blade', Colors.blue),
                  if (item.hasSalter)
                    _buildFeatureChip('Salter', Colors.green),
                  if (item.handBucketSalting)
                    _buildFeatureChip('Hand Bucket Salting', Colors.orange),
                  if (item.handShoveling)
                    _buildFeatureChip('Hand Shoveling', Colors.purple),
                ],
              ),
            ),

          // Video
          if (item.videoUrl != null)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoUrl: item.videoUrl!,
                      title: '${item.equipmentType.replaceAll('_', ' ').toUpperCase()} Video',
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    const Text(
                      'View Video',
                      style: TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 14, color: Colors.blue.shade300),
                  ],
                ),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editEquipment(item),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteEquipment(item.id!, item.equipmentType),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddEquipmentModal() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _editingId != null ? 'Edit Equipment' : 'Add Equipment',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _showAddModal = false;
                          _activeType = null;
                        });
                        _resetForm();
                      },
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _activeType == null
                    ? _buildEquipmentTypeSelector()
                    : _buildEquipmentForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentTypeSelector() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Select Equipment Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        _buildEquipmentTypeButton(
          'Truck',
          'Plow trucks with attachments',
          Icons.local_shipping,
          Colors.blue,
          'truck',
        ),
        const SizedBox(height: 12),
        _buildEquipmentTypeButton(
          'ATV',
          'All-terrain vehicles',
          Icons.air,
          Colors.green,
          'atv',
        ),
        const SizedBox(height: 12),
        _buildEquipmentTypeButton(
          'Sidewalk Salter',
          'Push salter for sidewalks',
          Icons.ac_unit,
          Colors.cyan,
          'sidewalk_salter',
        ),
        const SizedBox(height: 12),
        _buildEquipmentTypeButton(
          'Manual',
          'Hand tools and shoveling',
          Icons.person,
          Colors.grey,
          'manual',
        ),
        const SizedBox(height: 12),
        _buildEquipmentTypeButton(
          'Snowblower',
          'Powered snowblowers',
          Icons.ac_unit,
          Colors.purple,
          'snowblower',
        ),
      ],
    );
  }

  Widget _buildEquipmentTypeButton(
    String title,
    String description,
    IconData icon,
    Color color,
    String type,
  ) {
    return InkWell(
      onTap: () {
        setState(() => _activeType = type);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentForm() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Type header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _activeType!.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_editingId == null)
                      TextButton(
                        onPressed: () {
                          setState(() => _activeType = null);
                        },
                        child: const Text('Change Type'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Units
              const Text(
                'Number of Units',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: _activeType == 'truck' ? _truckUnits.toString() :
                        _activeType == 'atv' ? _atvUnits.toString() :
                        _activeType == 'sidewalk_salter' ? _sidewalkUnits.toString() :
                        _activeType == 'manual' ? _manualUnits.toString() :
                        _snowblowerUnits.toString(),
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Enter number of units',
                ),
                onChanged: (value) {
                  final units = int.tryParse(value) ?? 1;
                  setState(() {
                    if (_activeType == 'truck') _truckUnits = units;
                    else if (_activeType == 'atv') _atvUnits = units;
                    else if (_activeType == 'sidewalk_salter') _sidewalkUnits = units;
                    else if (_activeType == 'manual') _manualUnits = units;
                    else if (_activeType == 'snowblower') _snowblowerUnits = units;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Truck/ATV attachments
              if (_activeType == 'truck' || _activeType == 'atv') ...[
                const Text(
                  'Attachments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Plow Blade'),
                  value: _activeType == 'truck' ? _truckPlowBlade : _atvPlowBlade,
                  onChanged: (value) {
                    setState(() {
                      if (_activeType == 'truck') {
                        _truckPlowBlade = value!;
                      } else {
                        _atvPlowBlade = value!;
                      }
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text(_activeType == 'truck' ? 'Truck Salter' : 'ATV Salter'),
                  value: _activeType == 'truck' ? _truckSalter : _atvSalter,
                  onChanged: (value) {
                    setState(() {
                      if (_activeType == 'truck') {
                        _truckSalter = value!;
                      } else {
                        _atvSalter = value!;
                      }
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Manual services
              if (_activeType == 'manual') ...[
                const Text(
                  'Services Offered',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Hand Bucket Salting'),
                  value: _manualBucketSalting,
                  onChanged: (value) {
                    setState(() => _manualBucketSalting = value!);
                  },
                ),
                CheckboxListTile(
                  title: const Text('Hand Shoveling'),
                  value: _manualShoveling,
                  onChanged: (value) {
                    setState(() => _manualShoveling = value!);
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Video upload
              if (_activeType != 'manual' && _activeType != 'snowblower') ...[
                const Text(
                  'Video Verification *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                _buildVideoUploadSection(),
              ],
            ],
          ),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAddModal = false;
                    _activeType = null;
                  });
                  _resetForm();
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _saving ? null : _saveEquipment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(_editingId != null ? 'Update Equipment' : 'Save Equipment'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoUploadSection() {
    File? video;
    if (_activeType == 'truck') video = _truckVideo;
    else if (_activeType == 'atv') video = _atvVideo;
    else if (_activeType == 'sidewalk_salter') video = _sidewalkVideo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (video != null) ...[
            Icon(Icons.videocam, size: 48, color: Colors.green.shade600),
            const SizedBox(height: 8),
            Text(
              video.path.split('/').last,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_activeType == 'truck') _truckVideo = null;
                  else if (_activeType == 'atv') _atvVideo = null;
                  else if (_activeType == 'sidewalk_salter') _sidewalkVideo = null;
                });
              },
              child: const Text('Remove video', style: TextStyle(color: Colors.red)),
            ),
          ] else ...[
            Icon(Icons.upload, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'Upload a video of your equipment',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _pickVideo,
              child: const Text('Choose Video'),
            ),
            const SizedBox(height: 8),
            Text(
              'Max 200MB, MP4, MOV, or AVI',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

class EquipmentItem {
  final int? id;
  final String equipmentType;
  final int units;
  final bool hasPlowBlade;
  final bool hasSalter;
  final bool handBucketSalting;
  final bool handShoveling;
  final String? videoUrl;
  final bool verified;

  EquipmentItem({
    this.id,
    required this.equipmentType,
    required this.units,
    required this.hasPlowBlade,
    required this.hasSalter,
    required this.handBucketSalting,
    required this.handShoveling,
    this.videoUrl,
    required this.verified,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    return EquipmentItem(
      id: json['id'],
      equipmentType: json['equipment_type'],
      units: json['units'] ?? 1,
      hasPlowBlade: json['has_plow_blade'] ?? false,
      hasSalter: json['has_salter'] ?? false,
      handBucketSalting: json['hand_bucket_salting'] ?? false,
      handShoveling: json['hand_shoveling'] ?? false,
      videoUrl: json['video_url'],
      verified: json['verified'] ?? false,
    );
  }
}
