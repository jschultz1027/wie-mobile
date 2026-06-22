import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/refresh_icon_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../models/weather_snapshot.dart';
import 'package:http/http.dart' as http;

class WeatherAggregatorScreen extends StatefulWidget {
  const WeatherAggregatorScreen({super.key});

  @override
  State<WeatherAggregatorScreen> createState() => _WeatherAggregatorScreenState();
}

class _WeatherAggregatorScreenState extends State<WeatherAggregatorScreen> {
  HazardInput? _hazardInput;
  bool _loading = false;
  String? _error;
  bool _showRawValues = false;
  Timer? _refreshTimer;

  // Vancouver, BC coordinates
  final double latitude = 49.2827;
  final double longitude = -123.1207;
  final String locationName = "Vancouver, BC";

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh every 1 minute
    _refreshTimer = Timer.periodic(Duration(minutes: 1), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/weather-aggregator/hazard-input?latitude=$latitude&longitude=$longitude&max_age_minutes=15',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _hazardInput = HazardInput.fromJson(data);
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

  // Calculate confidence based on standard deviation
  Map<String, dynamic> _calculateConfidence(Map<String, double?> rawValues) {
    final values = rawValues.values.where((v) => v != null).map((v) => v!).toList();
    
    if (values.isEmpty) {
      return {'confidence': 'NO DATA', 'color': AppColors.textMuted, 'activeCount': 0};
    }
    if (values.length == 1) {
      return {'confidence': 'SINGLE', 'color': Colors.yellow.shade700, 'activeCount': 1};
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);

    if (stdDev < 1.0) {
      return {'confidence': 'HIGH', 'color': AppColors.success, 'activeCount': values.length};
    }
    if (stdDev < 2.0) {
      return {'confidence': 'MEDIUM', 'color': Colors.yellow.shade700, 'activeCount': values.length};
    }
    return {'confidence': 'LOW', 'color': AppColors.error, 'activeCount': values.length};
  }

  List<Widget> _getActiveSourceBadges(Map<String, String> sourceTimestamps) {
    final sourceNames = {
      'env_canada': 'Env Canada',
      'open_meteo': 'Open-Meteo',
      'visual_crossing': 'Visual Crossing',
      'tomorrow_io': 'Tomorrow.io',
      'era5_land': 'Historical',
    };

    final active = sourceTimestamps.entries.toList();
    
    if (active.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'No sources',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      ];
    }

    return active.map((entry) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          sourceNames[entry.key] ?? entry.key,
          style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600),
        ),
      );
    }).toList();
  }

  String _formatTime(String timestamp) {
    final date = DateTime.parse(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weather Aggregator',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '$locationName • ${latitude.toFixed(4)}°N, ${longitude.abs().toFixed(4)}°W',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ScreenHelpAction(
            title: 'Weather Aggregator',
            message: HelpContent.screenWeatherAggregator,
          ),
          RefreshIconButton(
            loading: _loading,
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              SizedBox(height: 16),
              Text(
                'Error Loading Data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.error),
              ),
              SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
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

    if (_loading && _hazardInput == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.blue600),
            SizedBox(height: 16),
            Text('Loading weather data...', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (_hazardInput == null) {
      return Center(
        child: Text('No data available', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.blue600,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(),
            SizedBox(height: 16),
            
            // Temperature Cards
            _buildAirTemperatureCard(),
            SizedBox(height: 16),
            _buildSoilTemperatureCard(),
            SizedBox(height: 16),
            
            // Precipitation & Wind Card
            _buildPrecipitationCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Row(
                children: [
                  Icon(Icons.layers, color: AppColors.blue600, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Multi-Source Data Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _showRawValues = !_showRawValues),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showRawValues ? Icons.visibility_off : Icons.visibility,
                        size: 14,
                        color: Colors.purple.shade700,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _showRawValues ? 'Hide' : 'Show',
                        style: TextStyle(fontSize: 11, color: Colors.purple.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Status Info
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last Update', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                SizedBox(height: 4),
                Text(
                  _formatTime(_hazardInput!.weather.timestamp),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Weather Sources', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _getActiveSourceBadges(_hazardInput!.weather.sourceTimestamps),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Soil Sources', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _getActiveSourceBadges(_hazardInput!.soil.sourceTimestamps),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAirTemperatureCard() {
    final conf = _calculateConfidence(_hazardInput!.weather.airTempRaw);
    final tempDiff = _hazardInput!.weather.tempPlus2hC - _hazardInput!.weather.airTempC;
    final arrow = tempDiff > 0.5 ? '↑' : tempDiff < -0.5 ? '↓' : '→';
    final trend = tempDiff > 0.5 ? 'Warming' : tempDiff < -0.5 ? 'Cooling' : 'Stable';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue600, AppColors.blue500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue600.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
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
              Row(
                children: [
                  Icon(Icons.thermostat, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Air Temperature',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  conf['confidence'],
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: conf['color']),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          Text(
            '${_hazardInput!.weather.airTempC.toStringAsFixed(1)}°C',
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            'Blended from ${conf['activeCount']} source(s)',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          
          if (_showRawValues) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📊 Raw Values:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  SizedBox(height: 8),
                  ..._hazardInput!.weather.airTempRaw.entries
                      .where((e) => e.value != null)
                      .map((e) => Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${e.key.replaceAll('_', ' ')}: ${e.value!.toStringAsFixed(1)}°C',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          )),
                ],
              ),
            ),
          ],
          
          SizedBox(height: 16),
          Divider(color: Colors.white30),
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dew Point', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    SizedBox(height: 4),
                    Text(
                      '${_hazardInput!.weather.dewpointC.toStringAsFixed(1)}°C',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wet Bulb', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    SizedBox(height: 4),
                    Text(
                      _hazardInput!.weather.wetBulbC != null
                          ? '${_hazardInput!.weather.wetBulbC!.toStringAsFixed(1)}°C'
                          : 'N/A',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          Divider(color: Colors.white30),
          SizedBox(height: 16),
          
          Row(
            children: [
              Icon(Icons.trending_down, size: 16, color: Colors.white70),
              SizedBox(width: 6),
              Text('2-Hour Forecast (for RCI)', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '${_hazardInput!.weather.tempPlus2hC.toStringAsFixed(1)}°C  $arrow ${tempDiff.abs().toStringAsFixed(1)}°C ($trend)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSoilTemperatureCard() {
    final conf = _calculateConfidence(_hazardInput!.soil.soilTempRaw);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade600, Colors.orange.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade600.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
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
              Row(
                children: [
                  Icon(Icons.layers, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Soil Temperature',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  conf['confidence'],
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: conf['color']),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          Text('Shallow (0-10cm) - Blended', style: TextStyle(fontSize: 12, color: Colors.white70)),
          SizedBox(height: 8),
          Text(
            '${_hazardInput!.soil.soilTempShallowC.toStringAsFixed(1)}°C',
            style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            'Blended from ${conf['activeCount']} source(s)',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          
          if (_showRawValues) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📊 Raw Values:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  SizedBox(height: 8),
                  ..._hazardInput!.soil.soilTempRaw.entries
                      .where((e) => e.value != null)
                      .map((e) => Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${e.key.replaceAll('_', ' ')}: ${e.value!.toStringAsFixed(1)}°C',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          )),
                ],
              ),
            ),
          ],
          
          if (_hazardInput!.soil.soilTemp10To40cmC != null) ...[
            SizedBox(height: 16),
            Divider(color: Colors.white30),
            SizedBox(height: 12),
            Text('Mid (10-40cm)', style: TextStyle(fontSize: 12, color: Colors.white70)),
            SizedBox(height: 4),
            Text(
              '${_hazardInput!.soil.soilTemp10To40cmC!.toStringAsFixed(1)}°C',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
          
          if (_hazardInput!.soil.soilTemp40To100cmC != null) ...[
            SizedBox(height: 12),
            Divider(color: Colors.white30),
            SizedBox(height: 12),
            Text('Deep (40-100cm)', style: TextStyle(fontSize: 12, color: Colors.white70)),
            SizedBox(height: 4),
            Text(
              '${_hazardInput!.soil.soilTemp40To100cmC!.toStringAsFixed(1)}°C',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrecipitationCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade600, Colors.purple.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade600.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Precipitation & Wind',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Type', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    SizedBox(height: 4),
                    Text(
                      _hazardInput!.weather.precipType.toUpperCase(),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rate', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    SizedBox(height: 4),
                    Text(
                      '${_hazardInput!.weather.precipRateMmh.toStringAsFixed(1)} mm/h',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          Divider(color: Colors.white30),
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wind Speed', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    SizedBox(height: 4),
                    Text(
                      _hazardInput!.weather.windSpeedMs != null
                          ? '${_hazardInput!.weather.windSpeedMs!.toStringAsFixed(1)} m/s'
                          : 'N/A',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloud Cover', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    SizedBox(height: 4),
                    Text(
                      _hazardInput!.weather.cloudCoverPct != null
                          ? '${_hazardInput!.weather.cloudCoverPct!.toStringAsFixed(0)}%'
                          : 'N/A',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on double {
  String toFixed(int decimals) => toStringAsFixed(decimals);
}
