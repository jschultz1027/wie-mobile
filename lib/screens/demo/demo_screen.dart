import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../models/property_report.dart';
import '../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  PropertyReport? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user == null || !user.isAdmin) {
        Navigator.of(context).pop();
        return;
      }
      _loadDemo();
    });
  }

  Future<void> _loadDemo() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Get token
      final token = await StorageService().getToken();
      
      print('Demo screen - Loading demo data...');
      print('Token present: ${token != null}');
      
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/demo/property'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('Demo response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _report = PropertyReport.fromJson(data);
          _loading = false;
        });
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
        return;
      } else {
        print('Demo error response: ${response.body}');
        throw Exception('Failed to load demo: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _getRiskColor(double score) {
    if (score >= 80) return Colors.red.shade600;
    if (score >= 60) return Colors.orange.shade600;
    if (score >= 40) return Colors.yellow.shade700;
    return Colors.green.shade600;
  }

  Color _getRiskBgColor(double score) {
    if (score >= 80) return Colors.red.shade100;
    if (score >= 60) return Colors.orange.shade100;
    if (score >= 40) return Colors.yellow.shade100;
    return Colors.green.shade100;
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'critical':
        return Icons.warning;
      case 'high':
        return Icons.error_outline;
      case 'medium':
        return Icons.ac_unit;
      default:
        return Icons.check_circle;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'critical':
        return Colors.red.shade600;
      case 'high':
        return Colors.orange.shade600;
      case 'medium':
        return Colors.yellow.shade700;
      default:
        return Colors.green.shade600;
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: Text(
          'WIE Demo',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _loading ? Icons.refresh : Icons.refresh,
              color: Colors.white,
            ),
            onPressed: _loading ? null : _loadDemo,
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
                'Error',
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
                onPressed: _loadDemo,
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

    if (_loading && _report == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.blue600),
            SizedBox(height: 16),
            Text('Generating predictions...', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (_report == null) {
      return Center(
        child: Text('No data available', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDemo,
      color: AppColors.blue600,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overview Card
            _buildOverviewCard(),
            SizedBox(height: 16),
            
            // Cold Streak Status
            if (_report!.coldStreakStatus.active) ...[
              _buildColdStreakCard(),
              SizedBox(height: 16),
            ],
            
            // Segments
            ..._report!.segments.map((segment) => Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _buildSegmentCard(segment),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final date = DateTime.parse(_report!.timestamp);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Property: ${_report!.propertyId}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '📍 Vancouver, BC (49.2827°N, 123.1207°W)',
                      style: TextStyle(fontSize: 12, color: AppColors.blue600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getRiskBgColor(_report!.overallRiskScore),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Risk: ${_report!.overallRiskScore.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getRiskColor(_report!.overallRiskScore),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Recommended Actions
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended Actions',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate900),
                ),
                SizedBox(height: 12),
                ..._report!.recommendedActions.map((action) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(fontSize: 13, color: AppColors.slate900)),
                      Expanded(
                        child: Text(
                          action,
                          style: TextStyle(fontSize: 13, color: AppColors.slate900),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColdStreakCard() {
    final status = _report!.coldStreakStatus;
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.ac_unit, color: Colors.blue.shade700, size: 20),
              SizedBox(width: 8),
              Text(
                '❄️ Cold Streak Active',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Duration: ${status.durationHours?.toStringAsFixed(0) ?? 'N/A'}h | '
            'Freeze Depth: ${status.freezeDepthCm?.toStringAsFixed(1) ?? 'N/A'}cm | '
            'Salt Reduction: ${status.saltingReductionFactor != null ? (status.saltingReductionFactor! * 100).toStringAsFixed(0) : 'N/A'}%',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(SegmentPrediction segment) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.segmentId,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ice Risk: ${segment.iceRiskScore.toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              Icon(
                _getPriorityIcon(segment.saltingRecommendation.priorityLevel),
                color: _getPriorityColor(segment.saltingRecommendation.priorityLevel),
                size: 24,
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Temperatures
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Pavement',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${segment.pavementTemp.pavementTemp.toStringAsFixed(1)}°C',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Ground (0cm)',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${segment.groundTemp.soilTemp0cm.toStringAsFixed(1)}°C',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Black Ice',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                      SizedBox(height: 4),
                      Text(
                        segment.blackIceRisk.blackIceRiskScore.toStringAsFixed(0),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Salting Recommendation
          Container(
            padding: EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Salt Needed:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getRiskBgColor(segment.saltingRecommendation.saltNeededScore),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        segment.saltingRecommendation.saltNeededScore.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _getRiskColor(segment.saltingRecommendation.saltNeededScore),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Priority:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    Text(
                      segment.saltingRecommendation.priorityLevel.toUpperCase(),
                      style: TextStyle(fontSize: 13, color: AppColors.slate900),
                    ),
                  ],
                ),
                if (segment.saltingRecommendation.recommendedAmount != null) ...[
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${segment.saltingRecommendation.recommendedAmount} kg/100m²',
                        style: TextStyle(fontSize: 13, color: AppColors.slate900),
                      ),
                    ],
                  ),
                ],
                if (segment.saltingRecommendation.justificationCodes.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Justifications:',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                  SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: segment.saltingRecommendation.justificationCodes.map((code) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          code.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
