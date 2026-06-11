import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/property.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/dispatch_service.dart';
import '../auth/login_screen.dart';
import '../../services/zone_manager_service.dart';

/// Dispatch Intelligence (DI Engine) - Admin only.
/// Property selector, engine health, Run Dispatch Engine, decision result.
/// Matches web: /dispatch-management.
class DispatchIntelligenceScreen extends StatefulWidget {
  const DispatchIntelligenceScreen({super.key});

  @override
  State<DispatchIntelligenceScreen> createState() => _DispatchIntelligenceScreenState();
}

class _DispatchIntelligenceScreenState extends State<DispatchIntelligenceScreen> {
  final DispatchService _dispatchApi = DispatchService();
  final ZoneManagerService _propertyApi = ZoneManagerService();

  List<Property> _properties = [];
  Property? _selectedProperty;
  DispatchHealthResponse? _health;
  bool _loading = true;
  bool _running = false;
  String? _error;
  Map<String, dynamic>? _lastDecision;
  String? _decisionError;
  List<dynamic> _history = [];
  List<dynamic> _alerts = [];
  Map<String, dynamic>? _analytics;
  bool _dashboardLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _propertyApi.getPropertiesPaginated(page: 1, pageSize: 100),
        _dispatchApi.getHealth(),
      ]);
      final res = results[0] as dynamic;
      final items = res.items as List<Property>;
      setState(() {
        _properties = items;
        _health = results[1] as DispatchHealthResponse;
        _selectedProperty = items.isNotEmpty ? items.first : null;
        _loading = false;
      });
      if (items.isNotEmpty) _loadDashboard();
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

  Future<void> _loadDashboard() async {
    if (_selectedProperty == null) return;
    setState(() => _dashboardLoading = true);
    try {
      final results = await Future.wait([
        _dispatchApi.getHistory(_selectedProperty!.id, limit: 10),
        _dispatchApi.getAlerts(_selectedProperty!.id, activeOnly: true),
        _dispatchApi.getAnalytics(_selectedProperty!.id, days: 30),
      ]);
      if (mounted) {
        setState(() {
          _history = results[0] as List<dynamic>;
          _alerts = results[1] as List<dynamic>;
          _analytics = results[2] as Map<String, dynamic>?;
          _dashboardLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        if (mounted) _handleSessionExpired();
        return;
      }
      if (mounted) setState(() => _dashboardLoading = false);
    }
  }

  Future<void> _runDispatchEngine() async {
    if (_selectedProperty == null) return;
    final propertyId = _selectedProperty!.id;
    setState(() {
      _running = true;
      _decisionError = null;
      _lastDecision = null;
    });
    try {
      final currentRisk = await _dispatchApi.getCurrentHazard(propertyId);
      final forecastRaw = await _dispatchApi.getHazardForecast(propertyId, hours: 48);
      final protectionData = await _dispatchApi.getSaltProtection(propertyId, includeZones: true);

      Map<String, double> riskZones = {};
      if (currentRisk['zone_risk_scores'] is List) {
        for (var z in currentRisk['zone_risk_scores'] as List) {
          final id = z['zone_id'];
          final score = (z['risk_score'] as num?)?.toDouble() ?? 0.0;
          if (id != null) riskZones['Z-$id'] = score;
        }
      }

      List forecastList = [];
      if (forecastRaw is List) {
        forecastList = forecastRaw;
      } else if (forecastRaw is Map) {
        forecastList = (forecastRaw['risk_score_forecast'] ?? forecastRaw['forecast']) as List? ?? [];
      }

      dynamic forecast12h = forecastList.isNotEmpty ? forecastList.first : null;
      dynamic forecast24h = forecastList.length > 1 ? forecastList[1] : (forecastList.isNotEmpty ? forecastList.last : null);
      for (var f in forecastList) {
        final h = (f is Map ? f['hours_ahead'] : null) as int?;
        if (h == 12) forecast12h = f;
        if (h == 24) forecast24h = f;
      }

      Map<String, double> risk12hZones = {};
      Map<String, double> risk24hZones = {};
      if (forecast12h is Map && forecast12h['zone_risk_scores'] is List) {
        for (var z in forecast12h['zone_risk_scores'] as List) {
          final id = z['zone_id'];
          if (id != null) risk12hZones['Z-$id'] = (z['risk_score'] as num?)?.toDouble() ?? 0.0;
        }
      }
      if (forecast24h is Map && forecast24h['zone_risk_scores'] is List) {
        for (var z in forecast24h['zone_risk_scores'] as List) {
          final id = z['zone_id'];
          if (id != null) risk24hZones['Z-$id'] = (z['risk_score'] as num?)?.toDouble() ?? 0.0;
        }
      }

      Map<String, double> protZones = {};
      Map<String, double> prot12hZones = {};
      Map<String, double> prot24hZones = {};
      if (protectionData['zones'] is List) {
        for (var z in protectionData['zones'] as List) {
          final id = z['zone_id'];
          if (id == null) continue;
          final key = 'Z-$id';
          protZones[key] = (z['current_protection'] as num?)?.toDouble() ?? 0.0;
          prot12hZones[key] = (z['protection_12h'] as num?)?.toDouble() ?? 0.0;
          prot24hZones[key] = (z['protection_24h'] as num?)?.toDouble() ?? 0.0;
        }
      }

      List<String> highLiability = [];
      if (currentRisk['zone_risk_scores'] is List) {
        for (var z in currentRisk['zone_risk_scores'] as List) {
          final type = z['zone_type'] as String?;
          if (type == 'stairs' || type == 'ramp') {
            final id = z['zone_id'];
            if (id != null) highLiability.add('Z-$id');
          }
        }
      }

      final body = {
        'property_id': propertyId,
        'risk_property': (currentRisk['property_risk_score'] as num?)?.toDouble() ?? 0.0,
        'risk_zones': riskZones,
        'forecasted_risk_12h': {
          'property': (forecast12h is Map ? (forecast12h['property_risk_score'] as num?)?.toDouble() : null) ?? 0.0,
          'zones': risk12hZones,
        },
        'forecasted_risk_24h': {
          'property': (forecast24h is Map ? (forecast24h['property_risk_score'] as num?)?.toDouble() : null) ?? 0.0,
          'zones': risk24hZones,
        },
        'prot_property': (protectionData['property_protection'] as num?)?.toDouble() ?? 0.0,
        'prot_zones': protZones,
        'forecasted_prot_12h': {
          'property': (protectionData['property_protection_12h'] as num?)?.toDouble() ?? 0.0,
          'zones': prot12hZones,
        },
        'forecasted_prot_24h': {
          'property': (protectionData['property_protection_24h'] as num?)?.toDouble() ?? 0.0,
          'zones': prot24hZones,
        },
        'high_liability_zones': highLiability,
        'has_active_salt': protectionData['has_active_salt'] == true,
        'last_dispatch_time': protectionData['last_dispatch_time'],
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final result = await _dispatchApi.makeDecision(body);
      if (mounted) {
        setState(() {
          _lastDecision = result;
          _running = false;
        });
        _loadDashboard();
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        if (mounted) _handleSessionExpired();
        return;
      }
      if (mounted) {
        setState(() {
          _decisionError = e.toString();
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user != null && !auth.user!.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Dispatch Intelligence')),
        body: const Center(child: Text('Admin only')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Dispatch Intelligence',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) _buildError(),
                    if (_error != null) const SizedBox(height: 12),
                    _buildHealth(),
                    const SizedBox(height: 16),
                    _buildPropertySelector(),
                    const SizedBox(height: 16),
                    if (_selectedProperty != null) _buildRunSection(),
                    if (_lastDecision != null) _buildDecisionResult(),
                    if (_lastDecision != null && _lastDecision!['forecast_alert'] != null) _buildForecastAlertCard(),
                    if (_decisionError != null) _buildDecisionError(),
                    if (_selectedProperty != null) ...[
                      const SizedBox(height: 20),
                      _buildDashboardSection(),
                    ],
                    const SizedBox(height: 24),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildHealth() {
    final ok = _health?.isOperational ?? false;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: ok ? AppColors.success : Colors.red,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (ok ? AppColors.success : Colors.red).withOpacity(0.5), blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              ok ? 'Engine operational' : (_health?.error ?? 'Engine error'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ok ? AppColors.success : Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertySelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select property (${_properties.length} available)', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            if (_properties.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No properties found.'))
            else
              DropdownButtonFormField<Property>(
                value: _selectedProperty,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _properties.map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (p) {
                  setState(() => _selectedProperty = p);
                  if (p != null) _loadDashboard();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedProperty!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _running ? null : _runDispatchEngine,
                icon: _running ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.gps_fixed, size: 20),
                label: Text(_running ? 'Analyzing...' : 'Run Dispatch Engine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionResult() {
    final decision = _lastDecision!['decision'] as Map<String, dynamic>? ?? {};
    final decisionType = decision['decision'] as String? ?? '—';
    final triggerReason = decision['trigger_reason'] as String? ?? '—';
    final confidence = (decision['confidence'] as num?)?.toDouble();
    final currentResidual = decision['current_residual'] as Map<String, dynamic>?;
    final zonesList = decision['zones'] as List<dynamic>?;
    final decisionId = _lastDecision!['decision_id'];
    final alertId = _lastDecision!['alert_id'];
    String icon = '✅';
    Color color = AppColors.success;
    if (decisionType == 'FULL_PROPERTY_SALT') {
      icon = '🚨';
      color = Colors.red;
    } else if (decisionType == 'SPOT_SALT') {
      icon = '⚠️';
      color = Colors.orange;
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Decision result', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(
                    decisionType.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _row('Trigger reason', _titleCase(triggerReason)),
            if (confidence != null) _row('Confidence', '${(confidence * 100).round()}%'),
            if (currentResidual != null) ...[
              const SizedBox(height: 12),
              _buildResidualSection(currentResidual),
            ],
            if (zonesList != null && zonesList.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Zones to treat (${zonesList.length})', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: zonesList.map<Widget>((z) {
                  final label = z is String ? z : z.toString();
                  return Chip(
                    label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.blue600.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  );
                }).toList(),
              ),
            ],
            if (decisionId != null || alertId != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'Decision ID: #$decisionId${alertId != null ? ' • Alert ID: #$alertId' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResidualSection(Map<String, dynamic> currentResidual) {
    final propRes = (currentResidual['property_residual'] as num?)?.toDouble();
    final zoneResiduals = currentResidual['zone_residuals'] as Map<String, dynamic>?;
    final entries = zoneResiduals != null
        ? (zoneResiduals.entries.toList()
          ..sort((a, b) => ((b.value as num?)?.toDouble() ?? 0).compareTo((a.value as num?)?.toDouble() ?? 0)))
        : <MapEntry<String, dynamic>>[];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Residual hazard', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          if (propRes != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Property residual'),
                Text(
                  propRes.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: propRes >= 55 ? Colors.red : (propRes >= 45 ? Colors.orange : AppColors.success),
                  ),
                ),
              ],
            ),
          ],
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Text('Zone residuals', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ...entries.map((e) {
              final v = (e.value as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 12)),
                    Text(
                      v.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: v >= 55 ? Colors.red : (v >= 45 ? Colors.orange : AppColors.success),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}').join(' ');
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildForecastAlertCard() {
    final alert = _lastDecision!['forecast_alert'] as Map<String, dynamic>?;
    if (alert == null) return const SizedBox.shrink();
    final level = alert['alert_level'] as String? ?? '';
    final triggerReason = alert['trigger_reason'] as String? ?? '';
    final expectedTime = alert['expected_dispatch_time'];
    final affectedZones = alert['affected_zones'] as List<dynamic>? ?? [];
    final forecastedResidual = alert['forecasted_residual'] as Map<String, dynamic>?;
    final propRes = forecastedResidual != null ? (forecastedResidual['property_residual'] as num?)?.toDouble() : null;
    final hoursAhead = forecastedResidual != null ? (forecastedResidual['hours_ahead'] as num?)?.toInt() : null;
    final isLocked = level == 'DISPATCH_LOCKED';
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: (isLocked ? Colors.orange : AppColors.blue600).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isLocked ? Icons.lock : Icons.warning_amber, color: isLocked ? Colors.orange : AppColors.blue600, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Forecast alert: ${level.replaceAll('_', ' ')}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isLocked ? Colors.orange.shade800 : AppColors.blue800),
                  ),
                ),
                if (propRes != null && hoursAhead != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(propRes.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('+${hoursAhead}h forecast', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_titleCase(triggerReason), style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
            if (expectedTime != null) ...[
              const SizedBox(height: 4),
              Text('Expected dispatch: ${DateTime.tryParse(expectedTime.toString())?.toLocal().toString().replaceFirst(RegExp(r'\.\d+'), '') ?? expectedTime.toString()}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
            if (affectedZones.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Affected zones: ${affectedZones.join(', ')}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionError() {
    return Card(
      elevation: 2,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(_decisionError!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Dispatch decisions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (_dashboardLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        if (_selectedProperty != null) Text(_selectedProperty!.name, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        if (_alerts.isNotEmpty) ...[
          Text('Active forecast alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          ...(_alerts.map<Widget>((a) {
            final level = (a is Map ? a['alert_level'] : null) as String? ?? '';
            final reason = (a is Map ? a['trigger_reason'] : null) as String? ?? '';
            final forecasted = a is Map ? a['forecasted_residual'] as Map<String, dynamic>? : null;
            final propRes = forecasted != null ? (forecasted['property_residual'] as num?)?.toDouble() : null;
            final hours = forecasted != null ? (forecasted['hours_ahead'] as num?)?.toInt() : null;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(level == 'DISPATCH_LOCKED' ? Icons.lock : Icons.warning_amber, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${level.replaceAll('_', ' ')}: ${_titleCase(reason)}', style: const TextStyle(fontSize: 13))),
                    if (propRes != null && hours != null) Text('${propRes.toStringAsFixed(1)} (+${hours}h)', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
            );
          })),
          const SizedBox(height: 16),
        ],
        Text('Decision history', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No dispatch decisions yet', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          )
        else
          ...(_history.map<Widget>((h) {
            final id = h is Map ? h['id'] : null;
            final type = (h is Map ? h['decision_type'] : null) as String? ?? '—';
            final reason = (h is Map ? h['trigger_reason'] : null) as String? ?? '—';
            final conf = (h is Map ? h['confidence'] as num? : null)?.toDouble();
            final residual = (h is Map ? h['residual_property'] as num? : null)?.toDouble();
            final time = h is Map ? h['decision_time'] : null;
            final executed = h is Map ? (h['was_executed'] == true) : false;
            Color typeColor = Colors.grey;
            if (type == 'FULL_PROPERTY_SALT') typeColor = Colors.red;
            else if (type == 'SPOT_SALT') typeColor = Colors.orange;
            else if (type == 'NO_DISPATCH') typeColor = AppColors.success;
            final timeStr = time != null ? (DateTime.tryParse(time.toString())?.toLocal().toString().replaceFirst(RegExp(r'\.\d+'), '') ?? time.toString()) : '—';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: typeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(type.replaceAll('_', ' '), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: typeColor)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_titleCase(reason), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text('$timeStr${conf != null ? ' • ${(conf * 100).round()}%' : ''}${residual != null ? ' • Residual ${residual.toStringAsFixed(1)}' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    if (executed)
                      Chip(label: const Text('Executed', style: TextStyle(fontSize: 11)), backgroundColor: AppColors.success.withOpacity(0.2), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)
                    else if (type != 'NO_DISPATCH' && id != null)
                      TextButton(
                        onPressed: () async {
                          try {
                            await _dispatchApi.markDecisionExecuted(id as int);
                            _loadDashboard();
                          } catch (_) {}
                        },
                        child: const Text('Mark executed', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
            );
          })),
        if (_analytics != null && (_analytics!['total_decisions'] as int? ?? 0) > 0) ...[
          const SizedBox(height: 16),
          Text('30-day analytics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _analyticsChip('Total', '${_analytics!['total_decisions']}', Colors.grey),
                      _analyticsChip('No dispatch', '${(_analytics!['decision_counts'] as Map?)?['NO_DISPATCH'] ?? 0}', AppColors.success),
                      _analyticsChip('Spot salt', '${(_analytics!['decision_counts'] as Map?)?['SPOT_SALT'] ?? 0}', Colors.orange),
                      _analyticsChip('Full property', '${(_analytics!['decision_counts'] as Map?)?['FULL_PROPERTY_SALT'] ?? 0}', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _analyticsChip('Avg confidence', '${((_analytics!['average_confidence'] as num?) ?? 0) * 100}%', AppColors.blue600),
                      _analyticsChip('Execution rate', '${((_analytics!['execution_rate'] as num?) ?? 0) * 100}%', Colors.purple),
                      _analyticsChip('Executed', '${_analytics!['dispatches_executed'] ?? 0}/${_analytics!['total_dispatches'] ?? 0}', Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _analyticsChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildInfoCard() {
    final config = _health?.configuration;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DI Engine information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Core equation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blue800)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Text('Residual = Risk × (1 - Protection / 100)', style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 4),
            Text('How dangerous is this location accounting for remaining protection?', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            Text('Decision types', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blue800)),
            const SizedBox(height: 6),
            _infoRow('NO DISPATCH', 'Conditions are safe'),
            _infoRow('SPOT SALT', 'Specific zones need treatment'),
            _infoRow('FULL PROPERTY SALT', 'Entire property needs treatment'),
            const SizedBox(height: 16),
            Text('Key thresholds', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blue800)),
            const SizedBox(height: 6),
            _infoRow('Initial full salt risk', '≥ 50'),
            _infoRow('Spot salt residual', '≥ 55'),
            _infoRow('Full salt residual', '≥ 50'),
            _infoRow('Failing zones threshold', '≥ 3'),
            _infoRow('High-liability threshold', '≥ 50'),
            const SizedBox(height: 16),
            Text('Key features', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blue800)),
            const SizedBox(height: 6),
            Text('• 12–24h forecast-based standby alerts', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('• 4–6h dispatch lock warnings', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('• High-liability zone priority', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('• 90-minute anti-chatter protection', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('• Emergency override at residual ≥ 70', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            Text('• Full decision audit trail', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            if (config != null && config.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text('Engine configuration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: config.entries.map<Widget>((e) {
                  final key = e.key.toString().replaceAll('_', ' ');
                  final value = e.value?.toString() ?? '—';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(key, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
