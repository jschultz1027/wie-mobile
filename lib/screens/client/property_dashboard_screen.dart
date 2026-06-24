/**
 * PROPERTY DASHBOARD - Client-facing real-time safety view.
 * Matches web /property-dashboard.
 *
 * - Fetch all properties and risk data; show list with risk score, peak 24h/48h, protection.
 * - Tap a property to open full detail (hero card, 6 metrics, zone table, View Portal, etc.).
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/app_notification.dart';
import '../../navigation/home_screen_actions.dart';
import '../auth/login_screen.dart';
import '../support/support_ticket_screen.dart';

class PropertyDashboardScreen extends StatefulWidget {
  const PropertyDashboardScreen({super.key});

  @override
  State<PropertyDashboardScreen> createState() => _PropertyDashboardScreenState();
}

class _PropertyDashboardScreenState extends State<PropertyDashboardScreen> {
  List<_SiteItem> _properties = [];
  final Map<int, _PropertyRiskData> _riskByPropertyId = {};
  bool _loadingProperties = true;
  String? _error;

  _SiteItem? _selectedSite;
  _PropertyRiskData? _riskData;
  bool _loading = false;
  bool _showTechnicalDetails = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final token = StorageService().getToken();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (token == null || token.isEmpty || user == null) {
      if (mounted) _handleSessionExpired();
      return;
    }
    setState(() {
      _error = null;
      _loadingProperties = true;
      _riskByPropertyId.clear();
    });
    try {
      final base = AppConfig.baseUrl;
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final res = await http.get(
        Uri.parse('$base/api/v1/properties'),
        headers: headers,
      );
      if (res.statusCode == 401 && mounted) {
        _handleSessionExpired();
        return;
      }
      if (res.statusCode != 200) throw Exception('Properties: ${res.statusCode}');
      final list = jsonDecode(res.body) is List
          ? (jsonDecode(res.body) as List)
              .map((e) => _SiteItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : <_SiteItem>[];
      if (!mounted) return;
      setState(() {
        _properties = list;
        _loadingProperties = false;
      });
      for (final p in list) {
        final data = await _fetchRiskDataForProperty(p.id, base, headers);
        if (mounted && data != null) {
          setState(() => _riskByPropertyId[p.id] = data);
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _loadingProperties = false;
        _error = e.toString();
      });
    }
  }

  /// Fetches risk data for one property; returns null on error.
  Future<_PropertyRiskData?> _fetchRiskDataForProperty(
    int propertyId,
    String base,
    Map<String, String> headers,
  ) async {
    try {
      final hazardRes = await http.get(
        Uri.parse('$base/api/v1/engine/hazard/property/$propertyId/current'),
        headers: headers,
      );
      final protectionRes = await http.get(
        Uri.parse('$base/api/salt/protection/property/$propertyId?include_zones=true'),
        headers: headers,
      );

      if (hazardRes.statusCode != 200) return null;
      final hazard = jsonDecode(hazardRes.body) as Map<String, dynamic>;
      final riskCurrent = (hazard['risk_score_current'] as num?)?.toDouble() ?? 0.0;
      final highest24h = (hazard['highest_24h'] as num?)?.toDouble();
      final highest48h = (hazard['highest_48h'] as num?)?.toDouble();
      final highest7days = (hazard['highest_7days'] as num?)?.toDouble();

      double protectionPct = 0;
      double hoursSinceSalt = 0;
      if (protectionRes.statusCode == 200) {
        final prot = jsonDecode(protectionRes.body) as Map<String, dynamic>;
        protectionPct = (prot['property_protection'] as num?)?.toDouble() ?? 0;
        hoursSinceSalt = (prot['hours_since_full_salt'] as num?)?.toDouble() ?? 999;
      }
      final protectionRemaining = (36 - hoursSinceSalt).clamp(0.0, 999.0);
      final protectionStatus = _protectionStatus(protectionPct);
      final trend = _determineTrend(riskCurrent);

      final zoneScores = <_ZoneRiskRow>[];
      final rawZones = hazard['zone_risk_scores'] as List? ?? [];
      final zoneProtections = <int, Map<String, dynamic>>{};
      if (protectionRes.statusCode == 200) {
        final prot = jsonDecode(protectionRes.body) as Map<String, dynamic>;
        for (final zp in (prot['zone_protections'] as List? ?? [])) {
          final m = zp as Map<String, dynamic>;
          final zid = m['zone_id'] as int?;
          if (zid != null) {
            zoneProtections[zid] = {
              'protection': (m['protection'] as num?)?.toDouble() ?? 0,
              'hours_since_treatment': (m['hours_since_treatment'] as num?)?.toDouble() ?? 0,
            };
          }
        }
      }
      for (final z in rawZones) {
        final zm = z as Map<String, dynamic>;
        final zid = zm['zone_id'] as int? ?? 0;
        final zp = zoneProtections[zid];
        zoneScores.add(_ZoneRiskRow(
          zoneId: zid,
          zoneName: zm['zone_name'] as String? ?? '',
          riskScore: (zm['risk_score'] as num?)?.toDouble() ?? 0,
          highest24h: (zm['highest_24h'] as num?)?.toDouble(),
          highest48h: (zm['highest_48h'] as num?)?.toDouble(),
          protectionLevel: (zp?['protection'] as num?)?.toDouble() ?? 0,
          protectionRemainingHours: (zp?['hours_since_treatment'] != null)
              ? (36.0 - (zp!['hours_since_treatment'] as num).toDouble()).clamp(0.0, 999.0)
              : 0.0,
          priority: zm['priority'] as String? ?? 'P2',
        ));
      }
      zoneScores.sort((a, b) {
        final p24a = a.highest24h ?? 0;
        final p24b = b.highest24h ?? 0;
        if (p24b != p24a) return (p24b - p24a).sign.toInt();
        final p48a = a.highest48h ?? 0;
        final p48b = b.highest48h ?? 0;
        return (p48b - p48a).sign.toInt();
      });

      return _PropertyRiskData(
        propertyId: propertyId,
        overallRisk: riskCurrent,
        protectionStatus: protectionStatus,
        protectionRemainingHours: protectionRemaining.round(),
        iceFormationRisk: _categorizeRisk(riskCurrent),
        trend: trend,
        monitoringFrequency: 'Continuous',
        zoneRiskScores: zoneScores,
        highest24h: highest24h ?? riskCurrent,
        highest48h: highest48h ?? riskCurrent,
        highest7days: highest7days ?? riskCurrent,
      );
    } catch (_) {
      return null;
    }
  }

  String _protectionStatus(double pct) {
    if (pct >= 60) return 'ACTIVE';
    if (pct >= 30) return 'LOW';
    return 'NONE';
  }

  String _determineTrend(double risk) {
    if (risk > 70) return 'INCREASING';
    if (risk < 40) return 'DECREASING';
    return 'STABLE';
  }

  String _categorizeRisk(double risk) {
    if (risk < 30) return 'Low';
    if (risk < 60) return 'Moderate';
    if (risk < 80) return 'High';
    return 'Severe';
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

  Future<void> _fetchRiskData(int propertyId) async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) return;
    final base = AppConfig.baseUrl;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (mounted) setState(() => _loading = true);
    final data = await _fetchRiskDataForProperty(propertyId, base, headers);
    if (mounted) {
      setState(() {
        _riskData = data;
        _loading = false;
        if (data != null) _riskByPropertyId[propertyId] = data;
      });
    }
  }

  void _selectProperty(_SiteItem site) {
    final cached = _riskByPropertyId[site.id];
    setState(() {
      _selectedSite = site;
      _riskData = cached;
      _loading = cached == null;
      _error = null;
    });
    if (cached == null) _fetchRiskData(site.id);
  }

  void _backToPropertyList() {
    setState(() {
      _selectedSite = null;
      _riskData = null;
    });
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
        title: const Text(
          'Property Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          ScreenHelpAction(
            title: 'Property Dashboard',
            message: HelpContent.screenPropertyDashboard,
          ),
        ],
      ),
      body: _selectedSite == null ? _buildPropertySelectionView() : _buildPropertyDetailView(),
    );
  }

  Widget _buildPropertySelectionView() {
    if (_loadingProperties && _properties.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text('Loading properties...'),
          ],
        ),
      );
    }
    if (_error != null && _properties.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadAll, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'All properties – tap for full dashboard',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          ..._properties.map((site) => _buildPropertySummaryCard(site)),
        ],
      ),
    );
  }

  Widget _buildPropertySummaryCard(_SiteItem site) {
    final data = _riskByPropertyId[site.id];
    final status = data != null
        ? _dispatchStatus(data.overallRisk, data.protectionRemainingHours.toDouble())
        : 'MONITORING';
    final statusColor = _dispatchStatusColor(status);
    final statusLabel = _dispatchStatusLabel(status);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _selectProperty(site),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (site.address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            site.address,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (data != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (data != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _summaryChip('Risk', '${data.overallRisk.round()}', _riskColor(data.overallRisk)),
                    _summaryChip('Peak 24h', '${data.highest24h.round()}', _riskColor(data.highest24h)),
                    _summaryChip('Peak 48h', '${data.highest48h.round()}', _riskColor(data.highest48h)),
                    _summaryChip('7d', '${data.highest7days.round()}', _riskColor(data.highest7days)),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Loading risk data...',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              if (data != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.shield, size: 14, color: _protectionRemainingColor(data.protectionRemainingHours.toDouble())),
                    Text(
                      _protectionLabel(data.protectionStatus),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Text(
                      '~${data.protectionRemainingHours}h left',
                      style: TextStyle(fontSize: 12, color: _protectionRemainingColor(data.protectionRemainingHours.toDouble())),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPropertyDetailView() {
    final site = _selectedSite!;
    return RefreshIndicator(
      onRefresh: () async => _fetchRiskData(site.id),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(site),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      SizedBox(height: 16),
                      Text('Loading property data...'),
                    ],
                  ),
                ),
              )
            else if (_riskData != null) ...[
              const SizedBox(height: 16),
              _buildHeroCard(site),
              const SizedBox(height: 16),
              _buildSixMetrics(),
              if (_riskData!.zoneRiskScores.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildZoneTable(),
              ],
              const SizedBox(height: 16),
              _buildViewPortalCard(site),
              const SizedBox(height: 12),
              _buildClientActions(),
              const SizedBox(height: 12),
              _buildTechnicalDetails(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_SiteItem site) {
    final status = _riskData != null
        ? _dispatchStatus(_riskData!.overallRisk, _riskData!.protectionRemainingHours.toDouble())
        : 'MONITORING';
    final statusColor = _dispatchStatusColor(status);
    final statusLabel = _dispatchStatusLabel(status);
    final statusIcon = _dispatchStatusIcon(status);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _backToPropertyList,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to property list',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (site.address.isNotEmpty)
                        Text(
                          site.address,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
                if (_riskData != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(statusIcon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusLabel,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Property ID: ${site.id}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  String _dispatchStatus(double risk, double remaining) {
    if (risk >= 60 && remaining < 12) return 'DISPATCH_TRIGGERED';
    if (risk >= 30 || (risk >= 20 && remaining < 18)) return 'STANDBY';
    return 'MONITORING';
  }

  String _dispatchStatusLabel(String s) {
    if (s == 'DISPATCH_TRIGGERED') return 'Dispatch Triggered';
    if (s == 'STANDBY') return 'Standby';
    return 'Monitoring';
  }

  Color _dispatchStatusColor(String s) {
    if (s == 'DISPATCH_TRIGGERED') return Colors.red;
    if (s == 'STANDBY') return Colors.amber;
    return Colors.green;
  }

  String _dispatchStatusIcon(String s) {
    if (s == 'DISPATCH_TRIGGERED') return '🔴';
    if (s == 'STANDBY') return '🟡';
    return '🟢';
  }

  Color _riskColor(double risk) {
    if (risk < 30) return Colors.green;
    if (risk < 60) return Colors.amber;
    if (risk < 80) return Colors.orange;
    return Colors.red;
  }

  Color _riskBgColor(double risk) {
    if (risk < 30) return Colors.green.shade50;
    if (risk < 60) return Colors.amber.shade50;
    if (risk < 80) return Colors.orange.shade50;
    return Colors.red.shade50;
  }

  Color _riskBorderColor(double risk) {
    if (risk < 30) return Colors.green.shade200;
    if (risk < 60) return Colors.amber.shade200;
    if (risk < 80) return Colors.orange.shade200;
    return Colors.red.shade200;
  }

  String _riskLabel(double risk) {
    if (risk < 30) return 'LOW RISK';
    if (risk < 60) return 'MODERATE RISK';
    if (risk < 80) return 'HIGH RISK';
    return 'SEVERE RISK';
  }

  String _protectionLabel(String status) {
    if (status == 'ACTIVE') return 'Protected';
    if (status == 'LOW') return 'Limited Protection';
    return 'Unprotected';
  }

  Color _protectionRemainingColor(double hours) {
    if (hours > 18) return Colors.green.shade700;
    if (hours > 8) return Colors.amber.shade700;
    return Colors.red.shade700;
  }

  String _trendLabel(String trend) {
    if (trend == 'INCREASING') return 'Increasing Risk (Next 12–24h)';
    if (trend == 'DECREASING') return 'Decreasing Risk (Next 12–24h)';
    return 'Stable Conditions';
  }

  IconData _trendIcon(String trend) {
    if (trend == 'INCREASING') return Icons.trending_up;
    if (trend == 'DECREASING') return Icons.trending_down;
    return Icons.trending_flat;
  }

  Widget _buildHeroCard(_SiteItem site) {
    final d = _riskData!;
    final bg = _riskBgColor(d.overallRisk);
    final border = _riskBorderColor(d.overallRisk);
    final textColor = _riskColor(d.overallRisk);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            site.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${d.overallRisk.round()}',
                style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: textColor, height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '/ 100',
                  style: TextStyle(fontSize: 22, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _riskLabel(d.overallRisk),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.shield, size: 28, color: _protectionRemainingColor(d.protectionRemainingHours.toDouble())),
                    const SizedBox(height: 4),
                    Text('Protection', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text(
                      _protectionLabel(d.protectionStatus),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _protectionRemainingColor(d.protectionRemainingHours.toDouble())),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 56, color: border.withOpacity(0.6)),
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.schedule, size: 28, color: _protectionRemainingColor(d.protectionRemainingHours.toDouble())),
                    const SizedBox(height: 4),
                    Text('Remaining', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text(
                      d.protectionRemainingHours > 0 ? '~${d.protectionRemainingHours}h' : 'None',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _protectionRemainingColor(d.protectionRemainingHours.toDouble())),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Monitoring: ${d.monitoringFrequency}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSixMetrics() {
    final d = _riskData!;
    final metrics = [
      _MetricItem('Ice Risk', Icons.ac_unit, d.iceFormationRisk, null),
      _MetricItem('Peak 24h', Icons.trending_up, d.highest24h.round().toString(), _riskColor(d.highest24h)),
      _MetricItem('Peak 48h', Icons.trending_up, d.highest48h.round().toString(), _riskColor(d.highest48h)),
      _MetricItem('7-Day High', Icons.calendar_today, d.highest7days.round().toString(), _riskColor(d.highest7days)),
      _MetricItem('Protection', Icons.shield, _protectionLabel(d.protectionStatus), null),
      _MetricItem('Trend', _trendIcon(d.trend), _trendLabel(d.trend), null),
    ];

    const gap = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2×3 on phones, 3×2 on wider screens — equal width and height per row
        final crossCount = constraints.maxWidth >= 600 ? 3 : 2;
        final rowCount = (metrics.length / crossCount).ceil();

        return Column(
          children: [
            for (var row = 0; row < rowCount; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < crossCount; col++) ...[
                      if (col > 0) const SizedBox(width: gap),
                      Expanded(
                        child: _buildMetricCard(
                          metrics[row * crossCount + col],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(_MetricItem m) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(m.icon, size: 22, color: AppColors.blue600),
            const SizedBox(height: 8),
            Text(
              m.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              m.value,
              style: TextStyle(
                fontSize: m.label == 'Trend' ? 12 : 17,
                fontWeight: FontWeight.bold,
                color: m.valueColor ?? Colors.grey.shade800,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneTable() {
    final zones = _riskData!.zoneRiskScores;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zone Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Zone')),
                  DataColumn(label: Text('Risk')),
                  DataColumn(label: Text('24h')),
                  DataColumn(label: Text('48h')),
                  DataColumn(label: Text('Protection')),
                  DataColumn(label: Text('Remaining')),
                ],
                rows: List.generate(zones.length, (i) {
                  final z = zones[i];
                  final isTop = i < 2;
                  return DataRow(
                    color: WidgetStateProperty.all(isTop ? Colors.amber.shade50 : null),
                    cells: [
                      DataCell(Text(z.zoneName, overflow: TextOverflow.ellipsis)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _riskColor(z.riskScore),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${z.riskScore.round()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      )),
                      DataCell(Text('${(z.highest24h ?? 0).round()}')),
                      DataCell(Text('${(z.highest48h ?? 0).round()}')),
                      DataCell(Text(z.protectionLevel >= 60 ? 'High' : z.protectionLevel >= 30 ? 'Medium' : 'Low')),
                      DataCell(Text('~${z.protectionRemainingHours.round()}h')),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewPortalCard(_SiteItem site) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.blue600.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'View Detailed Property Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Access comprehensive zone maps, service history, and detailed risk analysis on your home screen.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => HomeScreenActions.goHome(context),
                icon: const Icon(Icons.home),
                label: const Text('Go to Home'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () {
                  AppNotification.info(context, 'View Safety Report – open in web for full report');
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue600),
                child: const Text('View Safety Report'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportTicketScreen()),
                  );
                },
                child: const Text('Contact Support'),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  AppNotification.info(context, 'View Safety Report – open in web for full report');
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue600),
                child: const Text('View Safety Report'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportTicketScreen()),
                  );
                },
                child: const Text('Contact Support'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTechnicalDetails() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => setState(() => _showTechnicalDetails = !_showTechnicalDetails),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    _showTechnicalDetails ? 'Hide' : 'Show',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                  ),
                  const Text(' technical details'),
                ],
              ),
              if (_showTechnicalDetails) ...[
                const SizedBox(height: 12),
                Text(
                  'Risk and protection are calculated using surface temperature trends, ground temperature, '
                  'and prior treatment effectiveness. The system continuously monitors weather conditions '
                  'and updates risk assessments every 15 minutes.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          TextButton(onPressed: () => _selectedSite != null ? _fetchRiskData(_selectedSite!.id) : null, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SiteItem {
  final int id;
  final String name;
  final String address;

  _SiteItem({required this.id, required this.name, required this.address});

  factory _SiteItem.fromJson(Map<String, dynamic> json) {
    return _SiteItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }
}

class _PropertyRiskData {
  final int propertyId;
  final double overallRisk;
  final String protectionStatus;
  final int protectionRemainingHours;
  final String iceFormationRisk;
  final String trend;
  final String monitoringFrequency;
  final List<_ZoneRiskRow> zoneRiskScores;
  final double highest24h;
  final double highest48h;
  final double highest7days;

  _PropertyRiskData({
    required this.propertyId,
    required this.overallRisk,
    required this.protectionStatus,
    required this.protectionRemainingHours,
    required this.iceFormationRisk,
    required this.trend,
    required this.monitoringFrequency,
    required this.zoneRiskScores,
    required this.highest24h,
    required this.highest48h,
    required this.highest7days,
  });
}

class _ZoneRiskRow {
  final int zoneId;
  final String zoneName;
  final double riskScore;
  final double? highest24h;
  final double? highest48h;
  final double protectionLevel;
  final double protectionRemainingHours;
  final String priority;

  _ZoneRiskRow({
    required this.zoneId,
    required this.zoneName,
    required this.riskScore,
    this.highest24h,
    this.highest48h,
    required this.protectionLevel,
    required this.protectionRemainingHours,
    required this.priority,
  });
}

class _MetricItem {
  final String label;
  final IconData icon;
  final String value;
  final Color? valueColor;
  _MetricItem(this.label, this.icon, this.value, this.valueColor);
}
