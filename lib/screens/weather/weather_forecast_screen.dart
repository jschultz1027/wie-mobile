import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';

class WeatherForecastScreen extends StatefulWidget {
  const WeatherForecastScreen({super.key});

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  List<ForecastSnapshot> _forecast = [];
  bool _loading = false;
  String? _error;
  int _hours = 24;

  // Vancouver, BC coordinates
  final double latitude = 49.2827;
  final double longitude = -123.1207;
  final String locationName = "Vancouver, BC";

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/weather-aggregator/weather-forecast?latitude=$latitude&longitude=$longitude&hours=$_hours',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _forecast = data.map((f) => ForecastSnapshot.fromJson(f)).toList();
          _loading = false;
        });
      } else {
        throw Exception('Failed to load forecast: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<ForecastSnapshot> _getFreezeRiskHours() {
    return _forecast.where((f) {
      return f.airTemperature < 0 || (f.soilTemp0_7cm != null && f.soilTemp0_7cm! < 0);
    }).toList();
  }

  double _getMinAirTemp() {
    if (_forecast.isEmpty) return 0;
    return _forecast.map((f) => f.airTemperature).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxAirTemp() {
    if (_forecast.isEmpty) return 0;
    return _forecast.map((f) => f.airTemperature).reduce((a, b) => a > b ? a : b);
  }

  double _getTotalPrecip() {
    if (_forecast.isEmpty) return 0;
    return _forecast.map((f) => f.precipitationIntensity).reduce((a, b) => a + b);
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('EEE, MMM d\nh:mm a').format(dateTime);
  }

  String _formatShortTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
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
          'Weather Forecast',
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
            onPressed: _loading ? null : _loadForecast,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadForecast,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$locationName (${latitude.toStringAsFixed(4)}°N, ${longitude.abs().toStringAsFixed(4)}°W)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Time Range Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _hours,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 6, child: Text('6 Hours')),
                            DropdownMenuItem(value: 12, child: Text('12 Hours')),
                            DropdownMenuItem(value: 24, child: Text('24 Hours')),
                            DropdownMenuItem(value: 48, child: Text('48 Hours')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _hours = value);
                              _loadForecast();
                            }
                          },
                        ),
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
                              'Error Loading Forecast',
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

            // Freeze Risk Alert
            if (_forecast.isNotEmpty && _getFreezeRiskHours().isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: Colors.yellow.shade600, width: 4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_down, color: Colors.yellow.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Freeze Risk Detected',
                              style: TextStyle(
                                color: Colors.yellow.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_getFreezeRiskHours().length} hour(s) with sub-zero temperatures expected',
                              style: TextStyle(
                                color: Colors.yellow.shade800,
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

            // Summary Stats
            if (_forecast.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Min Temp',
                          '${_getMinAirTemp().toStringAsFixed(1)}°C',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Max Temp',
                          '${_getMaxAirTemp().toStringAsFixed(1)}°C',
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Total Precip',
                          '${_getTotalPrecip().toStringAsFixed(1)} mm',
                          Colors.cyan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Freeze Hours',
                          '${_getFreezeRiskHours().length}/${_forecast.length}',
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Temperature Chart
            if (_forecast.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
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
                      const Text(
                        'Temperature Forecast',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 250,
                        child: _buildTemperatureChart(),
                      ),
                    ],
                  ),
                ),
              ),

            // Hourly Details
            if (_forecast.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
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
                      const Text(
                        'Hourly Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._forecast.map((f) => _buildHourlyCard(f)).toList(),
                    ],
                  ),
                ),
              ),

            // Loading State
            if (_loading && _forecast.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading forecast...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
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
              fontSize: 10,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart() {
    // Limit to every 3 hours for clarity on mobile
    final step = (_forecast.length / 8).ceil();
    final filteredForecast = <ForecastSnapshot>[];
    for (int i = 0; i < _forecast.length; i += step) {
      filteredForecast.add(_forecast[i]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: filteredForecast.length * 80.0,
        height: 250,
        child: CustomPaint(
          painter: TemperatureChartPainter(filteredForecast),
        ),
      ),
    );
  }

  Widget _buildHourlyCard(ForecastSnapshot forecast) {
    final time = DateTime.parse(forecast.timestamp);
    final isFreeze = forecast.airTemperature < 0 || 
                     (forecast.soilTemp0_7cm != null && forecast.soilTemp0_7cm! < 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFreeze ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: isFreeze 
            ? Border.all(color: Colors.blue.shade200)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateTime(time),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isFreeze)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'FREEZE RISK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  Icons.thermostat,
                  'Air',
                  '${forecast.airTemperature.toStringAsFixed(1)}°C',
                  forecast.airTemperature < 0 ? Colors.blue : Colors.grey,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  Icons.grass,
                  'Soil',
                  forecast.soilTemp0_7cm != null 
                      ? '${forecast.soilTemp0_7cm!.toStringAsFixed(1)}°C'
                      : 'N/A',
                  (forecast.soilTemp0_7cm != null && forecast.soilTemp0_7cm! < 0) 
                      ? Colors.blue 
                      : Colors.grey,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  Icons.water_drop,
                  'Precip',
                  '${forecast.precipitationIntensity.toStringAsFixed(2)} mm/h',
                  Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  Icons.air,
                  'Wind',
                  '${forecast.windSpeed.toStringAsFixed(1)} m/s',
                  Colors.grey,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  Icons.cloud,
                  'Cloud',
                  '${forecast.cloudCover.toStringAsFixed(0)}%',
                  Colors.grey,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class ForecastSnapshot {
  final String timestamp;
  final double airTemperature;
  final double? soilTemp0_7cm;
  final double? soilTemp7_28cm;
  final double precipitationIntensity;
  final String? precipitationType;
  final double windSpeed;
  final double cloudCover;

  ForecastSnapshot({
    required this.timestamp,
    required this.airTemperature,
    this.soilTemp0_7cm,
    this.soilTemp7_28cm,
    required this.precipitationIntensity,
    this.precipitationType,
    required this.windSpeed,
    required this.cloudCover,
  });

  factory ForecastSnapshot.fromJson(Map<String, dynamic> json) {
    return ForecastSnapshot(
      timestamp: json['timestamp'],
      airTemperature: (json['air_temperature'] ?? 0).toDouble(),
      soilTemp0_7cm: json['soil_temp_0_7cm']?.toDouble(),
      soilTemp7_28cm: json['soil_temp_7_28cm']?.toDouble(),
      precipitationIntensity: (json['precipitation_intensity'] ?? 0).toDouble(),
      precipitationType: json['precipitation_type'],
      windSpeed: (json['wind_speed'] ?? 0).toDouble(),
      cloudCover: (json['cloud_cover'] ?? 0).toDouble(),
    );
  }
}

class TemperatureChartPainter extends CustomPainter {
  final List<ForecastSnapshot> forecast;

  TemperatureChartPainter(this.forecast);

  @override
  void paint(Canvas canvas, Size size) {
    if (forecast.isEmpty) return;

    final paint = Paint()..strokeWidth = 2;
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Find min/max for scaling
    final allTemps = [
      ...forecast.map((f) => f.airTemperature),
      ...forecast.where((f) => f.soilTemp0_7cm != null).map((f) => f.soilTemp0_7cm!),
    ];
    final minTemp = allTemps.reduce((a, b) => a < b ? a : b) - 2;
    final maxTemp = allTemps.reduce((a, b) => a > b ? a : b) + 2;
    final tempRange = maxTemp - minTemp;

    final barWidth = 30.0;
    final spacing = 20.0;
    final chartHeight = size.height - 80;
    final chartTop = 20.0;

    // Draw grid lines
    paint.color = Colors.grey.shade200;
    paint.strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = chartTop + (chartHeight * i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
      
      // Draw temperature labels
      final temp = maxTemp - (tempRange * i / 4);
      textPainter.text = TextSpan(
        text: '${temp.toInt()}°',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - 6));
    }

    // Draw bars for each forecast point
    for (int i = 0; i < forecast.length; i++) {
      final f = forecast[i];
      final x = (barWidth + spacing) * i + spacing;

      // Draw air temperature bar
      final airHeight = ((f.airTemperature - minTemp) / tempRange) * chartHeight;
      final airY = chartTop + chartHeight - airHeight;
      
      paint.color = f.airTemperature < 0 ? Colors.blue.shade400 : Colors.blue.shade600;
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, airY, barWidth * 0.45, airHeight),
          const Radius.circular(4),
        ),
        paint,
      );

      // Draw soil temperature bar (if available)
      if (f.soilTemp0_7cm != null) {
        final soilHeight = ((f.soilTemp0_7cm! - minTemp) / tempRange) * chartHeight;
        final soilY = chartTop + chartHeight - soilHeight;
        
        paint.color = f.soilTemp0_7cm! < 0 ? Colors.orange.shade400 : Colors.orange.shade600;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + barWidth * 0.55, soilY, barWidth * 0.45, soilHeight),
            const Radius.circular(4),
          ),
          paint,
        );
      }

      // Draw temperature value on top of air bar
      textPainter.text = TextSpan(
        text: '${f.airTemperature.toInt()}°',
        style: TextStyle(
          color: Colors.blue.shade900,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 5, airY - 18));

      // Draw time label
      final time = DateTime.parse(f.timestamp);
      final timeStr = DateFormat('HH:mm').format(time);
      textPainter.text = TextSpan(
        text: timeStr,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 5, chartTop + chartHeight + 8));

      // Draw date label (for first item or when day changes)
      if (i == 0 || DateTime.parse(forecast[i - 1].timestamp).day != time.day) {
        final dateStr = DateFormat('MMM d').format(time);
        textPainter.text = TextSpan(
          text: dateStr,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - 5, chartTop + chartHeight + 25));
      }
    }

    // Draw legend
    final legendY = size.height - 15;
    
    paint.color = Colors.blue.shade600;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, legendY, 12, 12),
        const Radius.circular(2),
      ),
      paint,
    );
    textPainter.text = TextSpan(
      text: 'Air Temp',
      style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(26, legendY - 1));

    paint.color = Colors.orange.shade600;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(90, legendY, 12, 12),
        const Radius.circular(2),
      ),
      paint,
    );
    textPainter.text = TextSpan(
      text: 'Soil Temp',
      style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(106, legendY - 1));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
