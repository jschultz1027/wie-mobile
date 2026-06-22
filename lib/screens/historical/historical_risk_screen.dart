import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../models/historical_risk.dart';
import '../../models/winter_hazard.dart';
import '../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class HistoricalRiskScreen extends StatefulWidget {
  const HistoricalRiskScreen({super.key});

  @override
  State<HistoricalRiskScreen> createState() => _HistoricalRiskScreenState();
}

class _HistoricalRiskScreenState extends State<HistoricalRiskScreen> {
  List<Site> _properties = [];
  Site? _selectedProperty;
  bool _isRangeMode = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _dateFrom = DateTime.now().subtract(Duration(days: 7));
  DateTime _dateTo = DateTime.now();
  
  HistoricalRiskData? _historicalData;
  DailySummary? _dailySummary;
  bool _loading = false;
  bool _fetchingData = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final token = StorageService().getToken();
      print('Historical Risk - Token: ${token != null ? "exists (${token.substring(0, 20)}...)" : "null"}');
      
      if (token == null) {
        throw Exception('No authentication token found. Please log in again.');
      }
      
      // Validate token by calling /api/auth/me
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
      
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/v1/properties'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('Historical Risk - Properties response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _properties = data.map((s) => Site.fromJson(s as Map<String, dynamic>)).toList();
          if (_properties.isNotEmpty) {
            _selectedProperty = _properties[0];
          }
          _loading = false;
        });
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
        return;
      } else {
        throw Exception('Failed to load properties: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchHistoricalData() async {
    if (_selectedProperty == null) return;

    setState(() {
      _fetchingData = true;
      _historicalData = null;
      _dailySummary = null;
      _error = null;
    });

    try {
      final token = StorageService().getToken();
      
      if (token == null) {
        throw Exception('No authentication token found. Please log in again.');
      }
      
      // Validate token by calling /api/auth/me
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
      
      String url = '${AppConfig.baseUrl}/api/v1/historical-risk/${_selectedProperty!.id}';

      if (_isRangeMode) {
        final from = DateFormat('yyyy-MM-dd').format(_dateFrom);
        final to = DateFormat('yyyy-MM-dd').format(_dateTo);
        url += '?date_from=$from&date_to=$to';
      } else {
        final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
        url += '?date=$date';
      }

      print('Fetching historical data from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Historical data response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _historicalData = HistoricalRiskData.fromJson(data);
          _fetchingData = false;
        });

        // Also fetch daily summary for single date queries
        if (!_isRangeMode) {
          _fetchDailySummary();
        }
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
        return;
      } else {
        throw Exception('Failed to fetch historical data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _fetchingData = false;
      });
    }
  }

  Future<void> _fetchDailySummary() async {
    if (_selectedProperty == null) return;

    try {
      final token = StorageService().getToken();
      
      if (token == null) return;
      
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final url = '${AppConfig.baseUrl}/api/v1/historical-risk/${_selectedProperty!.id}/summary?date=$date';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _dailySummary = DailySummary.fromJson(data);
        });
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
        return;
      }
    } catch (e) {
      print('Error fetching daily summary: $e');
    }
  }

  Color _getRiskColor(double risk) {
    if (risk >= 80) return Colors.red.shade600;
    if (risk >= 65) return Colors.orange.shade600;
    if (risk >= 40) return Colors.yellow.shade700;
    return Colors.green.shade600;
  }

  Color _getRiskBgColor(double risk) {
    if (risk >= 80) return Colors.red.shade50;
    if (risk >= 65) return Colors.orange.shade50;
    if (risk >= 40) return Colors.yellow.shade50;
    return Colors.green.shade50;
  }

  String _getRiskBadge(double risk) {
    if (risk >= 80) return 'CRITICAL';
    if (risk >= 65) return 'HIGH';
    if (risk >= 40) return 'MODERATE';
    return 'LOW';
  }

  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, h:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _dateFrom : (_isRangeMode ? _dateTo : _selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (_isRangeMode) {
          if (isFromDate) {
            _dateFrom = picked;
          } else {
            _dateTo = picked;
          }
        } else {
          _selectedDate = picked;
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: Text(
          'Historical Risk Scores',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          ScreenHelpAction(
            title: 'Historical Risk',
            message: HelpContent.screenHistoricalRisk,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        SizedBox(height: 16),
                        _buildQueryForm(),
                        SizedBox(height: 16),
                        if (!_isRangeMode && _dailySummary != null && _dailySummary!.dataAvailable)
                          _buildDailySummary(),
                        if (_historicalData != null)
                          _buildHistoricalDataTable()
                        else if (!_fetchingData)
                          _buildHelpText(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, size: 32, color: AppColors.blue600),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historical Risk Scores',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Access past risk data for dispute resolution and audit trails',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQueryForm() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property Selector
          Text('Property', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate900)),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Site>(
                isExpanded: true,
                value: _selectedProperty,
                items: _properties.map((prop) {
                  return DropdownMenuItem(
                    value: prop,
                    child: Text(prop.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedProperty = value);
                },
              ),
            ),
          ),
          SizedBox(height: 16),

          // Query Type Toggle
          Text('Query Type', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate900)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _isRangeMode = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isRangeMode ? AppColors.blue600 : Colors.grey.shade200,
                    foregroundColor: !_isRangeMode ? Colors.white : AppColors.slate900,
                    elevation: 0,
                  ),
                  child: Text('Single Date'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _isRangeMode = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRangeMode ? AppColors.blue600 : Colors.grey.shade200,
                    foregroundColor: _isRangeMode ? Colors.white : AppColors.slate900,
                    elevation: 0,
                  ),
                  child: Text('Date Range'),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Date Inputs
          if (!_isRangeMode) ...[
            Text('Date', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate900)),
            SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context, false),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: AppColors.blue600),
                    SizedBox(width: 8),
                    Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From Date', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate900)),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: AppColors.blue600),
                              SizedBox(width: 8),
                              Expanded(child: Text(DateFormat('MMM d').format(_dateFrom))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To Date', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate900)),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: AppColors.blue600),
                              SizedBox(width: 8),
                              Expanded(child: Text(DateFormat('MMM d').format(_dateTo))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 16),

          // Query Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchingData || _selectedProperty == null ? null : _fetchHistoricalData,
              icon: _fetchingData
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.search),
              label: Text(_fetchingData ? 'Loading...' : 'Query Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary() {
    final summary = _dailySummary!;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
          ),
          SizedBox(height: 16),

          // Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Peak Risk', summary.peakRisk?.toStringAsFixed(1) ?? 'N/A', 
                _getRiskColor(summary.peakRisk ?? 0)),
              _buildStatCard('Average Risk', summary.averageRisk?.toStringAsFixed(1) ?? 'N/A', 
                AppColors.slate900),
              _buildStatCard('Hours High Risk', summary.hoursHighRisk?.toString() ?? '0', 
                Colors.orange.shade600),
              _buildStatCard('Hours Critical', summary.hoursCriticalRisk?.toString() ?? '0', 
                Colors.red.shade600),
            ],
          ),
          SizedBox(height: 16),

          // Recommendation Card
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: summary.serviceNeeded == true ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: summary.serviceNeeded == true ? Colors.red.shade500 : Colors.green.shade500,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  summary.serviceNeeded == true ? Icons.warning : Icons.check_circle,
                  color: summary.serviceNeeded == true ? Colors.red.shade600 : Colors.green.shade600,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.recommendation ?? 'No recommendation',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate900),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Peak Residual: ${summary.peakResidual?.toStringAsFixed(1) ?? 'N/A'}% • '
                        'Dispatch Actions: ${summary.dispatchActions ?? 0} • '
                        'Data Points: ${summary.dataPoints ?? 0}',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalDataTable() {
    final data = _historicalData!;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900),
                ),
                SizedBox(height: 4),
                Text(
                  '${data.totalPoints} data points from ${DateFormat('MMM d').format(DateTime.parse(data.dateFrom))} to ${DateFormat('MMM d, yyyy').format(DateTime.parse(data.dateTo))}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Divider(height: 1),

          if (data.totalPoints == 0)
            Padding(
              padding: EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.trending_up, size: 64, color: Colors.grey.shade300),
                  SizedBox(height: 16),
                  Text(
                    'No Data Available',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate900),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No risk data was recorded for the selected date/period',
                    style: TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: data.dataPoints.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final point = data.dataPoints[index];
                return _buildDataPointCard(point);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDataPointCard(RiskDataPoint point) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateTime(point.timestamp),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate900),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRiskBgColor(point.riskScore),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${point.riskScore.toStringAsFixed(1)} - ${_getRiskBadge(point.riskScore)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getRiskColor(point.riskScore),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPointDetail('Protection', '${point.protection.toStringAsFixed(1)}%'),
              ),
              Expanded(
                child: _buildPointDetail('Residual', '${point.residual.toStringAsFixed(1)}%'),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: point.decisionType == 'FULL_PROPERTY_SALT'
                  ? Colors.blue.shade50
                  : point.decisionType == 'SPOT_SALT'
                      ? Colors.yellow.shade50
                      : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              point.decisionType.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: point.decisionType == 'FULL_PROPERTY_SALT'
                    ? Colors.blue.shade800
                    : point.decisionType == 'SPOT_SALT'
                        ? Colors.yellow.shade800
                        : Colors.grey.shade800,
              ),
            ),
          ),
          if (point.triggerReason.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              point.triggerReason,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate900),
        ),
      ],
    );
  }

  Widget _buildHelpText() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: Colors.blue.shade500, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to Use',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
          ),
          SizedBox(height: 8),
          ...[
            'Select a property and date to view historical risk scores',
            'Use single date mode to see detailed daily summary and prove service was/wasn\'t needed',
            'Use date range mode to analyze trends over multiple days',
            'Risk scores above 65 indicate high risk, above 80 is critical',
          ].map((text) => Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: Colors.blue.shade800, fontSize: 14)),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildError() {
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
              onPressed: _loadProperties,
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
}
