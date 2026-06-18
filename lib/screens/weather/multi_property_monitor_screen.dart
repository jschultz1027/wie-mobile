import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../services/storage_service.dart';
import '../../models/property.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'package:intl/intl.dart';

class MultiPropertyMonitorScreen extends StatefulWidget {
  const MultiPropertyMonitorScreen({super.key});

  @override
  State<MultiPropertyMonitorScreen> createState() => _MultiPropertyMonitorScreenState();
}

class _MultiPropertyMonitorScreenState extends State<MultiPropertyMonitorScreen> {
  List<Property> _properties = [];
  List<PropertySnapshot> _snapshots = [];
  bool _loading = false;
  bool _loadingProperties = false;
  String? _error;
  int _totalSites = 0;
  int _successfulSites = 0;
  int _failedSites = 0;
  String _searchQuery = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadProperties();
    // Auto-refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_properties.isNotEmpty) {
        _loadAllSites();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _loadingProperties = true;
      _error = null;
    });

    try {
      final token = StorageService().getToken();
      
      if (token == null) {
        throw Exception('No authentication token found. Please log in again.');
      }
      
      // Validate token
      final meResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (meResponse.statusCode == 401) {
        _handleSessionExpired();
        return;
      }
      
      final url = _searchQuery.isEmpty
          ? '${AppConfig.baseUrl}/api/v1/properties'
          : '${AppConfig.baseUrl}/api/v1/properties?search=$_searchQuery';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _properties = data.map((p) => Property.fromJson(p)).toList();
          _loadingProperties = false;
        });
        
        // Load weather data for all properties
        if (_properties.isNotEmpty) {
          _loadAllSites();
        }
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
        return;
      } else {
        throw Exception('Failed to load properties: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingProperties = false;
      });
    }
  }

  Future<void> _loadAllSites() async {
    if (_properties.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sites = _properties.map((p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
      }).toList();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/weather-aggregator/weather-properties'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sites': sites}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final snapshots = data['snapshots'] as Map<String, dynamic>;
        final errors = (data['errors'] as Map<String, dynamic>?) ?? {};

        List<PropertySnapshot> snapshotList = [];
        
        for (var property in _properties) {
          final key = '${property.latitude},${property.longitude}';
          final snapshotData = snapshots[key];
          final error = errors[key];

          if (error != null || snapshotData == null) {
            snapshotList.add(PropertySnapshot(
              property: property,
              timestamp: DateTime.now().toIso8601String(),
              airTemperature: 0,
              soilTemp0_7cm: null,
              precipitationIntensity: 0,
              dataQuality: 'unavailable',
              airSource: 'unavailable',
              error: error ?? 'No data available',
            ));
          } else {
            snapshotList.add(PropertySnapshot.fromJson({
              ...snapshotData,
              'property': property.toJson(),
            }));
          }
        }

        setState(() {
          _snapshots = snapshotList;
          _totalSites = data['total_sites'] ?? _properties.length;
          _successfulSites = data['successful'] ?? 0;
          _failedSites = data['failed'] ?? _properties.length;
          _loading = false;
        });
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  PropertySnapshot? _getColdestSite() {
    if (_snapshots.isEmpty) return null;
    return _snapshots.reduce((a, b) => 
      (a.error == null && (b.error != null || a.airTemperature < b.airTemperature)) ? a : b
    );
  }

  PropertySnapshot? _getWarmestSite() {
    if (_snapshots.isEmpty) return null;
    return _snapshots.reduce((a, b) => 
      (a.error == null && (b.error != null || a.airTemperature > b.airTemperature)) ? a : b
    );
  }

  Widget _getQualityIcon(String quality) {
    switch (quality) {
      case 'live':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'cached':
        return const Icon(Icons.check_circle, color: Colors.blue, size: 20);
      case 'degraded':
        return const Icon(Icons.warning, color: Colors.orange, size: 20);
      case 'unavailable':
      default:
        return const Icon(Icons.cancel, color: Colors.red, size: 20);
    }
  }

  Color _getTemperatureColor(double temp) {
    if (temp < -10) return Colors.blue.shade900;
    if (temp < 0) return Colors.blue.shade700;
    if (temp < 10) return Colors.cyan.shade700;
    if (temp < 20) return Colors.green.shade700;
    return Colors.orange.shade700;
  }

  Color _getTemperatureBackgroundColor(double temp) {
    if (temp < -10) return Colors.blue.shade100;
    if (temp < 0) return Colors.blue.shade50;
    if (temp < 10) return Colors.cyan.shade50;
    if (temp < 20) return Colors.green.shade50;
    return Colors.orange.shade50;
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return 'N/A';
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
          'Multi-Property Monitor',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: _loading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAllSites,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProperties();
        },
        child: CustomScrollView(
          slivers: [
            // Header Info
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monitoring ${_properties.length} location${_properties.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Search Bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search properties...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() => _searchQuery = '');
                                  _loadProperties();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (value) {
                        setState(() => _searchQuery = value);
                        _loadProperties();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Stats Cards
            if (_snapshots.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          _totalSites.toString(),
                          Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Online',
                          _successfulSites.toString(),
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Failed',
                          _failedSites.toString(),
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Coldest & Warmest Sites
            if (_snapshots.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildExtremeCard(
                          'Coldest Site',
                          _getColdestSite(),
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildExtremeCard(
                          'Warmest Site',
                          _getWarmestSite(),
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error Message
            if (_error != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: Colors.red.shade500, width: 4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade500),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Error Loading Sites',
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Loading State
            if (_loading && _snapshots.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading sites...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Empty State
            if (!_loading && !_loadingProperties && _snapshots.isEmpty && _error == null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Sites Yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add properties to start monitoring',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            // Sites List
            if (_snapshots.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final snapshot = _snapshots[index];
                      return _buildSiteCard(snapshot);
                    },
                    childCount: _snapshots.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtremeCard(String label, PropertySnapshot? snapshot, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          if (snapshot != null && snapshot.error == null) ...[
            Text(
              snapshot.property.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${snapshot.airTemperature.toStringAsFixed(1)}°C',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
          ] else
            const Text(
              'N/A',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(PropertySnapshot snapshot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.property.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.property.latitude.toStringAsFixed(4)}°N, ${snapshot.property.longitude.abs().toStringAsFixed(4)}°W',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          if (snapshot.error != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  snapshot.error!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            )
          else ...[
            // Temperature Display
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getTemperatureBackgroundColor(snapshot.airTemperature),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Air Temperature',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${snapshot.airTemperature.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _getTemperatureColor(snapshot.airTemperature),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.thermostat,
                    size: 48,
                    color: _getTemperatureColor(snapshot.airTemperature).withOpacity(0.3),
                  ),
                ],
              ),
            ),

            // Soil Temperature
            if (snapshot.soilTemp0_7cm != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Soil Temperature (0-7cm)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.soilTemp0_7cm!.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildDetailRow(
                    'Precipitation',
                    '${snapshot.precipitationIntensity.toStringAsFixed(2)} mm/h',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Data Quality',
                    snapshot.dataQuality,
                    trailing: _getQualityIcon(snapshot.dataQuality),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Source',
                    snapshot.airSource.replaceAll('_', ' ').replaceAll('-', ' '),
                    color: Colors.purple.shade700,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Last Update',
                    _formatTime(snapshot.timestamp),
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Widget? trailing, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color ?? Colors.black87,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ],
    );
  }
}

class PropertySnapshot {
  final Property property;
  final String timestamp;
  final double airTemperature;
  final double? soilTemp0_7cm;
  final double precipitationIntensity;
  final String dataQuality;
  final String airSource;
  final String? error;

  PropertySnapshot({
    required this.property,
    required this.timestamp,
    required this.airTemperature,
    this.soilTemp0_7cm,
    required this.precipitationIntensity,
    required this.dataQuality,
    required this.airSource,
    this.error,
  });

  factory PropertySnapshot.fromJson(Map<String, dynamic> json) {
    return PropertySnapshot(
      property: Property.fromJson(json['property']),
      timestamp: json['timestamp'],
      airTemperature: (json['air_temperature'] ?? 0).toDouble(),
      soilTemp0_7cm: json['soil_temp_0_7cm']?.toDouble(),
      precipitationIntensity: (json['precipitation_intensity'] ?? 0).toDouble(),
      dataQuality: json['data_quality'] ?? 'unavailable',
      airSource: json['air_source'] ?? 'unavailable',
      error: json['error'],
    );
  }
}
