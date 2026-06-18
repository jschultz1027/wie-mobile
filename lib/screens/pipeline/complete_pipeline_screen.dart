import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/weather_snapshot.dart';
import '../../models/pipeline_prediction.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class CompletePipelineScreen extends StatefulWidget {
  const CompletePipelineScreen({super.key});

  @override
  State<CompletePipelineScreen> createState() => _CompletePipelineScreenState();
}

class _CompletePipelineScreenState extends State<CompletePipelineScreen> {
  bool _isLoading = false;
  String? _error;
  int _activeStep = 0; // 0: not started, 1: weather, 2: hazard, 3: complete
  HazardInput? _weatherData;
  PredictionResult? _prediction;

  // Demo segment location (Vancouver, BC)
  final Map<String, dynamic> _demoSegment = {
    'segment_id': 'DEMO_UNIFIED_001',
    'property_id': 'DEMO_PROPERTY',
    'latitude': 49.2827,
    'longitude': -123.1207,
    'segment_type': 'driveway',
    'surface_material': 'asphalt',
    'orientation': 'N',
    'shade_index': 0.2,
    'shadow_type': 'mixed',
    'slope': 2.0,
    'drainage_rating': 0.8,
    'elevation': 50.0,
    'cold_air_pooling_index': 0.1,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user == null || !user.isAdmin) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _runCompletePipeline() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _activeStep = 0;
      _weatherData = null;
      _prediction = null;
    });

    try {
      // Step 1: Fetch multi-source weather data
      setState(() => _activeStep = 1);
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('Fetching weather data...');
      final weatherData = await _fetchWeatherData();
      print('Weather data fetched successfully');
      setState(() => _weatherData = weatherData);

      // Step 2: Run hazard engine analysis
      setState(() => _activeStep = 2);
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('Running hazard engine...');
      final prediction = await _runHazardEngine(weatherData);
      print('Prediction completed successfully');
      print('Prediction data: ice_risk_score=${prediction.iceRiskScore}');
      setState(() => _prediction = prediction);

      // Step 3: Complete
      print('Setting step to 3 (complete)');
      setState(() => _activeStep = 3);
      print('Pipeline complete!');

    } catch (e) {
      print('Pipeline error: $e');
      setState(() {
        _error = e.toString();
        _activeStep = 0;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<HazardInput> _fetchWeatherData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Authentication required');
    }

    final lat = _demoSegment['latitude'];
    final lon = _demoSegment['longitude'];

    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/v1/weather-aggregator/hazard-input?latitude=$lat&longitude=$lon'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return HazardInput.fromJson(data);
    } else if (response.statusCode == 401) {
      _handleSessionExpired();
      throw Exception('Session expired');
    } else {
      throw Exception('Failed to fetch weather data: ${response.statusCode}');
    }
  }

  Future<PredictionResult> _runHazardEngine(HazardInput weatherData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Authentication required');
    }

    // Send just the segment data - backend will fetch weather internally
    print('Sending segment data: ${json.encode(_demoSegment)}');
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/v1/predict/segment/unified'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(_demoSegment),
    );

    print('Response status: ${response.statusCode}');
    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        print('Decoded response data: $data');
        return PredictionResult.fromJson(data);
      } catch (e, stackTrace) {
        print('Error parsing prediction result: $e');
        print('Stack trace: $stackTrace');
        print('Response body: ${response.body}');
        throw Exception('Failed to parse prediction result: $e');
      }
    } else if (response.statusCode == 401) {
      _handleSessionExpired();
      throw Exception('Session expired');
    } else if (response.statusCode == 500) {
      print('Backend error: ${response.body}');
      throw Exception('Backend prediction engine error. The prediction model may need additional data or the segment configuration requires adjustment.');
    } else {
      print('Error response: ${response.body}');
      throw Exception('Failed to run hazard engine: ${response.statusCode} - ${response.body}');
    }
  }

  Color _getRiskColor(double risk) {
    if (risk >= 70) return Colors.red;
    if (risk >= 40) return Colors.orange;
    if (risk >= 20) return Colors.yellow.shade700;
    return Colors.green;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow.shade700;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStepIndicator(int step, String title, String description) {
    final isActive = _activeStep == step && _isLoading;
    final isCompleted = _activeStep > step || (_activeStep == step && !_isLoading);
    final isPending = _activeStep < step;

    return Opacity(
      opacity: isPending ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.white,
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Step icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : (isActive ? Colors.blue : Colors.grey.shade200),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : isActive
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            step.toString(),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 12),
            // Step info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            if (isActive && _weatherData != null && step == 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '3 air sources',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            if (isActive && _prediction != null && step == 2)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRiskColor(_prediction!.iceRiskScore).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Risk: ${_prediction!.iceRiskScore.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getRiskColor(_prediction!.iceRiskScore),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDataCard() {
    if (_weatherData == null) return const SizedBox.shrink();

    final weather = _weatherData!.weather;
    final soil = _weatherData!.soil;
    final airTempRaw = weather.airTempRaw;
    final blendedTemp = weather.airTempC;
    
    print('airTempRaw keys: ${airTempRaw.keys.toList()}');
    print('airTempRaw values: $airTempRaw');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.cloud, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Multi-Source Weather',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Blended air temperature
            Center(
              child: Column(
                children: [
                  const Text(
                    'Air Temperature (Blended)',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${blendedTemp.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Provider breakdown
            const Text(
              'Source Breakdown',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildProviderCard(
                    'Env Canada',
                    airTempRaw['env_canada'],
                    Colors.green.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildProviderCard(
                    'Open-Meteo',
                    airTempRaw['open_meteo'],
                    Colors.blue.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildProviderCard(
                    'Visual Crossing',
                    airTempRaw['visual_crossing'],
                    Colors.purple.shade50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Weather details
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildDetailItem(Icons.water_drop, 'Dewpoint', '${weather.dewpointC.toStringAsFixed(1)}°C'),
                _buildDetailItem(Icons.air, 'Wind Speed', '${(weather.windSpeedMs ?? 0).toStringAsFixed(1)} m/s'),
                _buildDetailItem(Icons.cloud_queue, 'Precipitation', weather.precipType),
                _buildDetailItem(Icons.layers, 'Soil Temp', '${soil.soilTempShallowC.toStringAsFixed(1)}°C'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(String name, double? temp, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            temp != null ? '${temp.toStringAsFixed(1)}°C' : 'N/A',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHazardAnalysisCard() {
    if (_prediction == null) return const SizedBox.shrink();

    final groundTemp = _prediction!.groundTemp;
    final pavementTemp = _prediction!.pavementTemp;
    final blackIceRisk = _prediction!.blackIceRisk;
    final iceRiskScore = _prediction!.iceRiskScore;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple.shade700, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Hazard Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Temperature predictions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Temperature Predictions',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Soil (0cm)',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${groundTemp.soilTemp0cm?.toStringAsFixed(1) ?? 'N/A'}°C',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Pavement',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pavementTemp.pavementTemp?.toStringAsFixed(1) ?? 'N/A'}°C',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Confidence: ${(((groundTemp.confidence ?? 0) + (pavementTemp.confidence ?? 0)) / 2 * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Ice risk score
            Row(
              children: [
                const Text(
                  'Ice Risk Score',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRiskColor(iceRiskScore),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${iceRiskScore.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Black ice risk details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Black Ice Risk: ${blackIceRisk.riskScore?.toStringAsFixed(1) ?? 'N/A'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spatial Factor: ${((blackIceRisk.spatialFactor ?? 0) * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            if (blackIceRisk.contributingFactors != null && blackIceRisk.contributingFactors!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Contributing Factors',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: blackIceRisk.contributingFactors!.map((factor) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      factor,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const Divider(height: 24),
            // Salting recommendation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Salting Recommendation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(_prediction!.saltingRecommendation.priorityLevel ?? 'low').withOpacity(0.2),
                    border: Border.all(
                      color: _getPriorityColor(_prediction!.saltingRecommendation.priorityLevel ?? 'low'),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (_prediction!.saltingRecommendation.priorityLevel ?? 'low').toUpperCase(),
                    style: TextStyle(
                      color: _getPriorityColor(_prediction!.saltingRecommendation.priorityLevel ?? 'low'),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSaltingDetail(
              'Salt Score',
              '${_prediction!.saltingRecommendation.saltNeededScore?.toStringAsFixed(1) ?? 'N/A'}/100',
            ),
            if (_prediction!.saltingRecommendation.recommendedAmount != null)
              _buildSaltingDetail(
                'Amount',
                '${_prediction!.saltingRecommendation.recommendedAmount!.toStringAsFixed(1)} kg/100m²',
              ),
            if (_prediction!.saltingRecommendation.estimatedEffectiveDuration != null)
              _buildSaltingDetail(
                'Duration',
                '${_prediction!.saltingRecommendation.estimatedEffectiveDuration!.toStringAsFixed(1)} hours',
              ),
            if (_prediction!.saltingRecommendation.justificationCodes != null && _prediction!.saltingRecommendation.justificationCodes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _prediction!.saltingRecommendation.justificationCodes!.map((code) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      code,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.yellow.shade900,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaltingDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
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
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'Complete Pipeline Demo',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About This Demo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This demo showcases the complete Winter Intelligence Engine pipeline with real-time data from Vancouver, BC.',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Run pipeline button
            if (_activeStep == 0 || _activeStep == 3)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _runCompletePipeline,
                icon: const Icon(Icons.play_arrow),
                label: Text(_activeStep == 3 ? 'Run Again' : 'Run Complete Pipeline'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 24),
            // Error display
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            // Pipeline steps
            if (_activeStep > 0) ...[
              _buildStepIndicator(
                1,
                'Fetch Multi-Source Weather Data',
                'Blending data from 3 air sources and 2 soil sources',
              ),
              const SizedBox(height: 12),
              _buildStepIndicator(
                2,
                'Run Hazard Engine Analysis',
                'Ground temp → Pavement temp → Ice risk',
              ),
              const SizedBox(height: 12),
              _buildStepIndicator(
                3,
                'Generate Actionable Recommendations',
                'Priority-based salting decisions',
              ),
              const SizedBox(height: 24),
            ],
            // Results
            if (_weatherData != null) ...[
              _buildWeatherDataCard(),
              const SizedBox(height: 16),
            ],
            if (_prediction != null) ...[
              _buildHazardAnalysisCard(),
            ],
          ],
        ),
      ),
    );
  }
}
