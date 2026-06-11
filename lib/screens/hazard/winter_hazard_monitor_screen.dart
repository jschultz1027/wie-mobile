import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../models/winter_hazard.dart';
import '../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_notification.dart';
import '../auth/login_screen.dart';

class WinterHazardMonitorScreen extends StatefulWidget {
  const WinterHazardMonitorScreen({super.key});

  @override
  State<WinterHazardMonitorScreen> createState() => _WinterHazardMonitorScreenState();
}

class _WinterHazardMonitorScreenState extends State<WinterHazardMonitorScreen> {
  List<Site> _sites = [];
  Site? _selectedSite;
  WinterHazardResponse? _hazardData;
  ForecastResponse? _forecastData;
  bool _loading = false;
  String? _error;
  bool _autoRefresh = true;
  DateTime? _lastUpdated;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final token = await StorageService().getToken();
    if (token == null) {
      setState(() {
        _error = 'Please log in to access the Winter Hazard Monitor';
        _loading = false;
      });
      return;
    }
    
    // Validate token by calling /api/auth/me
    try {
      print('Validating token with /api/auth/me...');
      final meResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('Token validation response: ${meResponse.statusCode}');
      
      if (meResponse.statusCode == 401) {
        _handleSessionExpired();
        return;
      } else if (meResponse.statusCode != 200) {
        print('Token validation failed: ${meResponse.body}');
      }
    } catch (e) {
      print('Token validation error: $e');
    }
    
    _loadSites();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSites() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final token = await StorageService().getToken();
      print('Loading sites with token: ${token != null ? "Present (${token.substring(0, 20)}...)" : "Missing"}');
      print('Full token length: ${token?.length ?? 0} characters');
      if (token != null && token.length > 20) {
        print('Token start: ${token.substring(0, 50)}');
        print('Token end: ${token.substring(token.length - 30)}');
      }
      
      final url = '${AppConfig.baseUrl}/api/v1/properties';
      print('Making request to: $url');
      
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      print('Request headers: ${headers.keys.join(", ")}');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Sites response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Error response body: ${response.body}');
        print('Error response headers: ${response.headers}');
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _sites = data.map((s) => Site.fromJson(s as Map<String, dynamic>)).toList();
          if (_sites.isNotEmpty) {
            _selectedSite = _sites[0];
          }
          _loading = false;
        });

        if (_selectedSite != null) {
          _loadHazardData();
        }
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
        return;
      } else {
        print('Failed with status ${response.statusCode}');
        print('Error response body: ${response.body}');
        throw Exception('Failed to load sites: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('401')) {
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

  Future<void> _loadHazardData() async {
    if (_selectedSite == null) return;

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final token = await StorageService().getToken();
      print('Loading hazard data for site ${_selectedSite!.id} with token: ${token != null ? "Present" : "Missing"}');

      // Fetch current hazard and forecast in parallel
      final responses = await Future.wait([
        http.get(
          Uri.parse('${AppConfig.baseUrl}/api/v1/engine/hazard/property/${_selectedSite!.id}/current'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
        http.get(
          Uri.parse('${AppConfig.baseUrl}/api/v1/engine/hazard/property/${_selectedSite!.id}/forecast?hours=168'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      ]);

      print('Hazard data response status: current=${responses[0].statusCode}, forecast=${responses[1].statusCode}');
      
      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final hazardJson = jsonDecode(responses[0].body);
        final forecastJson = jsonDecode(responses[1].body);

        setState(() {
          _hazardData = WinterHazardResponse.fromJson(hazardJson);
          _forecastData = ForecastResponse.fromJson(forecastJson);
          _lastUpdated = DateTime.now();
          _loading = false;
        });

        // Setup auto-refresh
        _refreshTimer?.cancel();
        if (_autoRefresh) {
          _refreshTimer = Timer.periodic(Duration(minutes: 2), (_) => _loadHazardData());
        }
      } else {
        // Check for specific status codes
        if (responses[0].statusCode == 401 || responses[1].statusCode == 401) {
          throw Exception('Authentication failed. Please log in again.');
        }
        throw Exception('Failed to load hazard data: ${responses[0].statusCode}, ${responses[1].statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('Authentication failed')) {
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

  Color _getRiskBandColor(String band) {
    switch (band) {
      case 'LOW':
        return Colors.green.shade600;
      case 'MODERATE':
        return Colors.yellow.shade700;
      case 'HIGH':
        return Colors.orange.shade600;
      case 'CRITICAL':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getRiskBandBgColor(String band) {
    switch (band) {
      case 'LOW':
        return Colors.green.shade100;
      case 'MODERATE':
        return Colors.yellow.shade100;
      case 'HIGH':
        return Colors.orange.shade100;
      case 'CRITICAL':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'P0':
        return Colors.red.shade500;
      case 'P1':
        return Colors.orange.shade500;
      case 'P2':
        return Colors.yellow.shade600;
      default:
        return Colors.grey.shade500;
    }
  }

  String _formatTimestamp(String timestamp) {
    final date = DateTime.parse(timestamp);
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Winter Hazard Monitor',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading ? null : () => _checkAuthAndLoad(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      final isAuthError = _error!.contains('Authentication') || _error!.contains('log in');
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAuthError ? Icons.lock_outline : Icons.error_outline,
                size: 64,
                color: isAuthError ? AppColors.blue600 : AppColors.error,
              ),
              SizedBox(height: 16),
              Text(
                isAuthError ? 'Authentication Required' : 'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isAuthError ? AppColors.blue600 : AppColors.error,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              SizedBox(height: 24),
              if (isAuthError)
                ElevatedButton.icon(
                  onPressed: () async {
                    // Clear the error first
                    setState(() => _error = null);
                    
                    // Logout and redirect to login
                    await StorageService().clearAll();
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                      AppNotification.warning(context, 'Please log in again');
                    }
                  },
                  icon: Icon(Icons.logout),
                  label: Text('Logout & Re-login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue600,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _checkAuthAndLoad(),
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading && _hazardData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.blue600),
            SizedBox(height: 16),
            Text('Loading hazard data...', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (_sites.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: AppColors.textMuted),
              SizedBox(height: 16),
              Text(
                'No Properties Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              SizedBox(height: 8),
              Text(
                'Contact your administrator to add properties.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHazardData,
      color: AppColors.blue600,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Site Selector
            _buildSiteSelector(),
            SizedBox(height: 16),

            if (_hazardData != null) ...[
              // Risk Overview Card
              _buildRiskOverviewCard(),
              SizedBox(height: 16),

              // Temperature Analysis (V2)
              if (_hazardData!.airTemperature != null && _hazardData!.surfaceTemperature != null) ...[
                _buildTemperatureAnalysisCard(),
                SizedBox(height: 16),
              ],

              // Zone Risk Breakdown
              if (_hazardData!.zoneRiskScores.isNotEmpty) ...[
                _buildZoneRiskBreakdown(),
                SizedBox(height: 16),
              ],

              // Risk Drivers
              if (_hazardData!.riskDrivers.isNotEmpty) ...[
                _buildRiskDriversCard(),
                SizedBox(height: 16),
              ],

              // Forecast Chart
              if (_forecastData != null) ...[
                _buildForecastChart(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSiteSelector() {
    if (_sites.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blue600,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue600.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Site>(
                value: _selectedSite,
                isExpanded: true,
                dropdownColor: AppColors.slate900,
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                items: _sites.map((site) {
                  return DropdownMenuItem<Site>(
                    value: site,
                    child: Text(
                      site.name,
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (site) {
                  setState(() => _selectedSite = site);
                  _loadHazardData();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskOverviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Risk Assessment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRiskBandBgColor(_hazardData!.hazardRiskBand),
                  border: Border.all(color: _getRiskBandColor(_hazardData!.hazardRiskBand), width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _hazardData!.hazardRiskBand,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getRiskBandColor(_hazardData!.hazardRiskBand),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Risk Score',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _hazardData!.riskScoreCurrent.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: _getRiskBandColor(_hazardData!.hazardRiskBand),
                        ),
                      ),
                      Text(
                        'out of 100',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Last Assessment',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _formatTimestamp(_hazardData!.timestamp),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate900),
                        textAlign: TextAlign.center,
                      ),
                      if (_lastUpdated != null) ...[
                        SizedBox(height: 4),
                        Text(
                          '${DateTime.now().difference(_lastUpdated!).inSeconds}s ago',
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          SizedBox(height: 12),

          Text(
            'Property ID: ${_hazardData!.propertyId}',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (_selectedSite != null) ...[
            SizedBox(height: 4),
            Text(
              'Location: ${_selectedSite!.name}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemperatureAnalysisCard() {
    final coolingDelta = _hazardData!.airTemperature! - _hazardData!.surfaceTemperature!;
    final isCooling = coolingDelta > 1.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Temperature Analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Engine A V2',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('Air Temp', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      SizedBox(height: 4),
                      Text(
                        '${_hazardData!.airTemperature!.toStringAsFixed(1)}°C',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate900),
                      ),
                      Text('Measured', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('Surface', style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text(
                        '${_hazardData!.surfaceTemperature!.toStringAsFixed(1)}°C',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                      ),
                      Text('Est. V2', style: TextStyle(fontSize: 9, color: Colors.blue.shade600)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCooling ? Colors.orange.shade50 : Colors.green.shade50,
                    border: Border.all(
                      color: isCooling ? Colors.orange.shade300 : Colors.green.shade300,
                      width: isCooling ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isCooling ? 'Cooling' : 'Effect',
                        style: TextStyle(
                          fontSize: 10,
                          color: isCooling ? Colors.orange.shade700 : Colors.green.shade700,
                          fontWeight: isCooling ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${coolingDelta > 0 ? '-' : '+'}${coolingDelta.abs().toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isCooling ? Colors.orange.shade700 : Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'Surface',
                        style: TextStyle(
                          fontSize: 9,
                          color: isCooling ? Colors.orange.shade600 : Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_hazardData!.moisturePotential != null || _hazardData!.environmentalMultiplier != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                if (_hazardData!.moisturePotential != null)
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Moisture:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          Text(
                            '${(_hazardData!.moisturePotential! * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate900),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_hazardData!.moisturePotential != null && _hazardData!.environmentalMultiplier != null)
                  SizedBox(width: 8),
                if (_hazardData!.environmentalMultiplier != null)
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Env Factor:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          Text(
                            '${_hazardData!.environmentalMultiplier!.toStringAsFixed(2)}×',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _hazardData!.environmentalMultiplier! > 1.1 ? Colors.orange.shade600 : AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],

          if (isCooling) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clear Sky Cooling Detected: Surface temperature is significantly lower than air temperature. Increased black ice risk.',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoneRiskBreakdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zone Risk Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          SizedBox(height: 16),

          ..._hazardData!.zoneRiskScores.map((zone) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(zone.priority),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        zone.priority,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.zoneName,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate900),
                          ),
                          Text(
                            'Zone ID: ${zone.zoneId}',
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          zone.riskScore.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _getRiskBandColor(zone.riskBand),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getRiskBandBgColor(zone.riskBand),
                            border: Border.all(color: _getRiskBandColor(zone.riskBand)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            zone.riskBand,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _getRiskBandColor(zone.riskBand),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRiskDriversCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Risk Drivers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hazardData!.riskDrivers.map((driver) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  driver,
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastChart() {
    // Take first 72 hours (3 days) for mobile display
    final chartData = _forecastData!.riskScoreForecast.take(72).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '72-Hour Risk Forecast',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          SizedBox(height: 8),
          Text(
            'Peak: ${_forecastData!.peakRiskScore.toStringAsFixed(1)} at hour ${_forecastData!.peakRiskHour}',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          SizedBox(height: 20),

          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 12,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}h',
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => AppColors.slate900,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: EdgeInsets.all(8),
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final hour = spot.x.toInt();
                        final score = spot.y.toInt();
                        return LineTooltipItem(
                          'Hour: $hour\nRisk: $score',
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.riskScore);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.blue600,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.blue600.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
