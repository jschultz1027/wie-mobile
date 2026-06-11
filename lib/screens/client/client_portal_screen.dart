import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../models/zone_attributes.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/zone_manager_service.dart';
import '../../utils/app_notification.dart';
import '../../widgets/property_map_with_zones.dart';
import '../auth/login_screen.dart';

/// Client Portal - property management dashboard. Matches web /client-portal.
class ClientPortalScreen extends StatefulWidget {
  const ClientPortalScreen({super.key});

  @override
  State<ClientPortalScreen> createState() => _ClientPortalScreenState();
}

class _ClientPortalScreenState extends State<ClientPortalScreen> {
  final ZoneManagerService _zoneService = ZoneManagerService();

  List<_PropertyItem> _properties = [];
  _PropertyItem? _selectedProperty;
  List<_AlertItem> _alerts = [];
  List<_ServiceItem> _recentServices = [];
  List<ZoneAttributes> _zones = [];
  List<_ZoneRowData> _zoneRows = [];
  String _propertyStatus = 'PROTECTED';
  double _protectionLevel = 85;
  double _hoursSinceSalt = 12;
  String? _mapImageUrl;
  bool _isLocked = false;
  bool _loading = true;
  bool _loadingZones = false;
  bool _loadingPropertyDetails = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatHoursSince(double hours) {
    if (hours < 1) return '<1h';
    if (hours < 24) return '${hours.round()}h';
    final days = (hours / 24).floor();
    final rem = (hours % 24).round();
    if (rem == 0) return '${days}d';
    return '${days}d ${rem}h';
  }

  Future<void> _load() async {
    final token = StorageService().getToken();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (token == null || token.isEmpty || user == null) {
      if (mounted) _handleSessionExpired();
      return;
    }
    if (!user.isClient) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final base = AppConfig.baseUrl;

      final propRes = await http.get(
        Uri.parse('$base/api/v1/properties'),
        headers: headers,
      );
      if (propRes.statusCode == 401) {
        if (mounted) _handleSessionExpired();
        return;
      }
      if (propRes.statusCode != 200) {
        throw Exception('Properties: ${propRes.statusCode}');
      }
      final propList = jsonDecode(propRes.body) is List
          ? (jsonDecode(propRes.body) as List)
              .map((e) => _PropertyItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : <_PropertyItem>[];

      List<_AlertItem> alerts = [];
      List<_ServiceItem> services = [];
      final dashRes = await http.get(
        Uri.parse('$base/api/v1/portal/dashboard/${user.id}'),
        headers: headers,
      );
      if (dashRes.statusCode == 200) {
        final dash = jsonDecode(dashRes.body) as Map<String, dynamic>;
        final alertsList = dash['alerts'] as List?;
        if (alertsList != null) {
          alerts = alertsList
              .map((e) => _AlertItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        final servicesList = dash['recent_services'] as List?;
        if (servicesList != null) {
          services = servicesList
              .map((e) => _ServiceItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _properties = propList;
          _selectedProperty =
              propList.isNotEmpty && _selectedProperty == null
                  ? propList.first
                  : _selectedProperty != null &&
                          propList.any((p) => p.id == _selectedProperty!.id)
                      ? propList.firstWhere(
                          (p) => p.id == _selectedProperty!.id)
                      : (propList.isNotEmpty ? propList.first : null);
          _alerts = alerts;
          _recentServices = services;
          _loading = false;
        });
        if (_selectedProperty != null) {
          _fetchZonesAndDetails(_selectedProperty!.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
          if (_properties.isEmpty) _properties = [];
        });
      }
    }
  }

  Future<void> _fetchZonesAndDetails(int propertyId) async {
    final token = StorageService().getToken();
    if (token == null || token.isEmpty) return;
    setState(() {
      _loadingZones = true;
      _loadingPropertyDetails = true;
      _zones = [];
      _zoneRows = [];
      _mapImageUrl = null;
      _isLocked = false;
    });
    final base = AppConfig.baseUrl;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    try {
      final results = await Future.wait([
        _zoneService.getMapUrl(propertyId),
        _zoneService.getLockStatus(propertyId),
        _zoneService.getZones(propertyId),
        http.get(
          Uri.parse('$base/api/v1/engine/hazard/property/$propertyId/current'),
          headers: headers,
        ),
        http.get(
          Uri.parse('$base/api/salt/protection/property/$propertyId?include_zones=true'),
          headers: headers,
        ),
      ]);
      final mapUrlRes = results[0] as MapUrlResponse;
      final lockRes = results[1] as LockStatusResponse;
      final zonesList = results[2] as List<ZoneAttributes>;
      final hazardRes = results[3] as http.Response;
      final protectionRes = results[4] as http.Response;

      String? mapImageUrl = mapUrlRes.mapImageUrl;
      final isLocked = lockRes.locked;
      final zones = zonesList;

      final Map<int, Map<String, dynamic>> riskByZone = {};
      if (hazardRes.statusCode == 200) {
        final hazard = jsonDecode(hazardRes.body) as Map<String, dynamic>;
        final zoneScores = hazard['zone_risk_scores'] as List?;
        if (zoneScores != null) {
          for (final z in zoneScores) {
            final zm = z as Map<String, dynamic>;
            final zid = zm['zone_id'] as int?;
            if (zid != null) {
              riskByZone[zid] = {
                'risk_score': (zm['risk_score'] as num?)?.toDouble() ?? 0.0,
                'highest_24h': (zm['highest_24h'] as num?)?.toDouble(),
                'highest_48h': (zm['highest_48h'] as num?)?.toDouble(),
                'highest_7days': (zm['highest_7days'] as num?)?.toDouble(),
              };
            }
          }
        }
      }

      double propProtection = 85;
      double hoursSince = 12;
      final Map<int, Map<String, dynamic>> protectionByZone = {};
      if (protectionRes.statusCode == 200) {
        final prot = jsonDecode(protectionRes.body) as Map<String, dynamic>;
        propProtection = (prot['property_protection'] as num?)?.toDouble() ?? 85;
        hoursSince = (prot['hours_since_full_salt'] as num?)?.toDouble() ?? 12;
        final zpList = prot['zone_protections'] as List?;
        if (zpList != null) {
          for (final zp in zpList) {
            final zpm = zp as Map<String, dynamic>;
            final zid = zpm['zone_id'] as int?;
            if (zid != null) {
              protectionByZone[zid] = {
                'protection': (zpm['protection'] as num?)?.toDouble() ?? 0,
                'hours_since_treatment': (zpm['hours_since_treatment'] as num?)?.toDouble() ?? 0,
                'last_event_time': zpm['last_event_time']?.toString(),
              };
            }
          }
        }
      }

      String status = 'PROTECTED';
      if (propProtection < 40) status = 'AT_RISK';
      else if (propProtection < 70) status = 'WARNING';

      final zoneRows = <_ZoneRowData>[];
      for (final zone in zones) {
        final rid = zone.id;
        final risk = rid != null ? riskByZone[rid] : null;
        final prot = rid != null ? protectionByZone[rid] : null;
        zoneRows.add(_ZoneRowData(
          zoneId: rid ?? 0,
          zoneName: zone.name,
          zoneType: zone.zoneType,
          riskScore: (risk?['risk_score'] as num?)?.toDouble() ?? 0,
          highest24h: (risk?['highest_24h'] as num?)?.toDouble(),
          highest48h: (risk?['highest_48h'] as num?)?.toDouble(),
          highest7days: (risk?['highest_7days'] as num?)?.toDouble(),
          protectionLevel: (prot?['protection'] as num?)?.toDouble() ?? 0,
          hoursSinceSalt: (prot?['hours_since_treatment'] as num?)?.toDouble() ?? 0,
          lastSaltApplication: prot?['last_event_time'] as String?,
        ));
      }

      if (mounted) {
        setState(() {
          _zones = zones;
          _zoneRows = zoneRows;
          _propertyStatus = status;
          _protectionLevel = propProtection;
          _hoursSinceSalt = hoursSince;
          _mapImageUrl = mapImageUrl;
          _isLocked = isLocked;
          _loadingZones = false;
          _loadingPropertyDetails = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingZones = false;
          _loadingPropertyDetails = false;
          _mapImageUrl = null;
          _isLocked = false;
        });
      }
    }
  }

  Future<void> _handleSessionExpired() async {
    await StorageService().clearAll();
    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: AppColors.error),
            SizedBox(width: 12),
            Text('Session expired'),
          ],
        ),
        content: const Text(
          'Your session has expired. Please log in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user != null && !auth.user!.isClient) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Client Portal')),
        body: const Center(child: Text('Client only')),
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
          'Client Portal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
                    Text(
                      'View zones, monitor protection, and track services',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      _buildErrorBanner(),
                      const SizedBox(height: 12),
                    ],
                    _buildPropertySelector(),
                    const SizedBox(height: 16),
                    if (_selectedProperty == null)
                      _buildPlaceholder()
                    else ...[
                      _buildStatusBanner(),
                      const SizedBox(height: 16),
                      _buildMapSection(),
                      const SizedBox(height: 16),
                      _buildZonesTableSection(),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 360) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildAlertsSection(),
                                const SizedBox(height: 12),
                                _buildServicesSection(),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildAlertsSection()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildServicesSection()),
                            ],
                          );
                        },
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
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildPropertySelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Property',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<_PropertyItem>(
                  value: _selectedProperty,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  selectedItemBuilder: (context) => _properties
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  items: _properties
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _properties.isEmpty
                      ? null
                      : (p) {
                          setState(() => _selectedProperty = p);
                          if (p != null) _fetchZonesAndDetails(p.id);
                        },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.location_on, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Select a property from the dropdown above',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isProtected = _propertyStatus == 'PROTECTED';
    final isWarning = _propertyStatus == 'WARNING';
    final bg = isProtected
        ? Colors.green.shade50
        : isWarning
            ? Colors.amber.shade50
            : Colors.red.shade50;
    final border = isProtected
        ? Colors.green.shade200
        : isWarning
            ? Colors.amber.shade200
            : Colors.red.shade200;
    final fg = isProtected
        ? Colors.green.shade700
        : isWarning
            ? Colors.amber.shade800
            : Colors.red.shade700;
    final fgDark = isProtected
        ? Colors.green.shade900
        : isWarning
            ? Colors.amber.shade900
            : Colors.red.shade900;
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 2),
          ),
          child: Row(
            children: [
              Icon(
                isProtected ? Icons.shield : Icons.warning_amber_rounded,
                size: 36,
                color: fg,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _propertyStatus.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: fgDark,
                      ),
                    ),
                    Text(
                      'Time since last salt: ${_formatHoursSince(_hoursSinceSalt)}',
                      style: TextStyle(fontSize: 13, color: fg),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Protection',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${_protectionLevel.round()}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_loadingPropertyDetails)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _fullMapUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = AppConfig.baseUrl;
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }

  Widget _buildMapSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.map, color: AppColors.blue600),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Property Map & Zones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_isLocked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 18, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Locked by Admin',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Editing enabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (_isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.orange.shade50,
              child: Text(
                'This property is locked. You cannot modify zones or upload images.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildMapContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContent() {
    final fullUrl = _fullMapUrl(_mapImageUrl);
    if (fullUrl.isNotEmpty) {
      return PropertyMapWithZones(
        mapImageUrl: fullUrl,
        zones: _zones,
        height: 280,
      );
    }
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'No map image available for this property',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          if (!_isLocked) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                AppNotification.info(context, 'Upload map on web client portal');
              },
              icon: const Icon(Icons.upload_file, size: 20),
              label: const Text('Upload Map Image'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZonesTableSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.grid_view, color: AppColors.blue600),
                const SizedBox(width: 8),
                Text(
                  'Zones',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_zoneRows.length} zone${_zoneRows.length == 1 ? '' : 's'} configured',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loadingZones)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_zoneRows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No zones configured for this property',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _zoneRows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final row = _zoneRows[i];
                ZoneAttributes? zone;
                try {
                  zone = _zones.firstWhere((z) => z.id == row.zoneId);
                } catch (_) {
                  zone = null;
                }
                return _buildZoneRowCard(row, zone);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildZoneRowCard(_ZoneRowData row, ZoneAttributes? zoneAttrs) {
    Color riskColor(double v) {
      if (v < 30) return Colors.green;
      if (v < 60) return Colors.amber;
      if (v < 80) return Colors.orange;
      return Colors.red;
    }
    return InkWell(
      onTap: () {
        if (zoneAttrs != null) {
          _showZoneDetailSheet(zoneAttrs, row);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.zoneName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blue600.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  row.zoneType.replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (zoneAttrs != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade500),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _riskChip('Risk', row.riskScore, riskColor(row.riskScore)),
              if (row.highest24h != null)
                _riskChip('24h', row.highest24h!, riskColor(row.highest24h!)),
              if (row.highest48h != null)
                _riskChip('48h', row.highest48h!, riskColor(row.highest48h!)),
              if (row.highest7days != null)
                _riskChip('7d', row.highest7days!, riskColor(row.highest7days!)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Protection: ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (row.protectionLevel / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      row.protectionLevel >= 70
                          ? Colors.green
                          : row.protectionLevel >= 40
                              ? Colors.amber
                              : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${row.protectionLevel.round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Since salt: ${_formatHoursSince(row.hoursSinceSalt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Spacer(),
              Text(
                row.lastSaltApplication != null
                    ? _formatDate(row.lastSaltApplication)
                    : 'Never',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  void _showZoneDetailSheet(ZoneAttributes zone, _ZoneRowData row) {
    final mZone = calculateMZone(zone);
    final decayZone = zone.zoneDecayMultiplier ?? calculateDecayZone(zone);
    String zoneTypeLabel(String v) {
      final m = kZoneTypes.firstWhere((e) => e['value'] == v, orElse: () => {'label': v});
      return m['label'] ?? v;
    }
    String orientationLabel(String v) {
      final m = kOrientations.firstWhere((e) => e['value'] == v, orElse: () => {'label': v});
      return m['label'] ?? v;
    }
    String surfaceLabel(String v) {
      final m = kSurfaceTypes.firstWhere((e) => e['value'] == v, orElse: () => {'label': v});
      return m['label'] ?? v;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Zone: ${zone.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle('Live data'),
                    _detailRow('Current risk', '${row.riskScore.round()}'),
                    if (row.highest24h != null) _detailRow('Peak 24h', '${row.highest24h!.round()}'),
                    if (row.highest48h != null) _detailRow('Peak 48h', '${row.highest48h!.round()}'),
                    if (row.highest7days != null) _detailRow('7-day high', '${row.highest7days!.round()}'),
                    _detailRow('Protection', '${row.protectionLevel.round()}%'),
                    _detailRow('Time since salt', _formatHoursSince(row.hoursSinceSalt)),
                    _detailRow('Last salt', row.lastSaltApplication != null ? _formatDate(row.lastSaltApplication) : 'Never'),
                    const SizedBox(height: 16),
                    _sectionTitle('Basic info'),
                    _detailRow('Zone name', zone.name),
                    _detailRow('Zone type', zoneTypeLabel(zone.zoneType)),
                    _detailRow('Orientation', orientationLabel(zone.orientation)),
                    _detailRow('Surface type', surfaceLabel(zone.surfaceType)),
                    if (zone.notes != null && zone.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text(zone.notes!, style: const TextStyle(fontSize: 14)),
                    ],
                    const SizedBox(height: 16),
                    _sectionTitle('Zone attributes (sliders)'),
                    _attrRow('Stairs (A: 0.55, B: 0.25)', zone.stairs),
                    _attrRow('Ramp (A: 0.45, B: 0.25)', zone.ramp),
                    _attrRow('Curb step (A: 0.25)', zone.curbStep),
                    _attrRow('Shade (A: 0.35, B: 0.15)', zone.shade),
                    _attrRow('North-facing (A: 0.25)', zone.northFacing),
                    _attrRow('Tree cover (A: 0.20)', zone.treeCover),
                    _attrRow('Wind corridor (A: 0.15, B: 0.25)', zone.windCorridor),
                    _attrRow('Vegetation edge (A: 0.20, B: 0.25)', zone.vegEdge),
                    _attrRow('Covered (A: 0.20, B: 0.15)', zone.covered),
                    _attrRow('Elevated (A: 0.30)', zone.elevated),
                    _attrRow('Water accumulation (A: 0.65, B: 0.85)', zone.waterAccumulation),
                    _attrRow('High foot traffic (A: 0.30, B: 0.35)', zone.highFootTraffic),
                    const SizedBox(height: 16),
                    _sectionTitle('Computed'),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.blue600.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.blue600.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Engine A: Risk multiplier (M_zone)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${mZone.toStringAsFixed(2)}×', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Engine B: Salt decay (Decay_zone)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${decayZone.toStringAsFixed(2)}×', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (zone.isHighLiabilityZone == true) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'HIGH LIABILITY ZONE\nStairs/Ramp/Water ≥0.66 or high-slip surface',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attrRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Text(
            '${sliderPresetLabel(value)} (${value.toStringAsFixed(2)})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _riskChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${value.round()}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildAlertsSection() {
    final unread = _alerts.where((a) => !a.isRead).toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: AppColors.blue600),
                const SizedBox(width: 8),
                const Text(
                  'Active Alerts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: unread.isEmpty ? 1 : unread.length,
              itemBuilder: (context, i) {
                if (unread.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No active alerts',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final a = unread[i];
                final color = a.severity == 'high'
                    ? Colors.red
                    : a.severity == 'medium'
                        ? Colors.orange
                        : AppColors.blue600;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: color, width: 4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.message,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(a.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    final list = _recentServices.take(10).toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.handyman, color: AppColors.blue600),
                const SizedBox(width: 8),
                const Text(
                  'Recent Services',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: list.isEmpty ? 1 : list.length,
              itemBuilder: (context, i) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No recent services',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final s = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.serviceType.replaceAll('_', ' '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: s.status == 'completed'
                                    ? AppColors.success.withOpacity(0.15)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s.status.replaceAll('_', ' '),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: s.status == 'completed'
                                      ? AppColors.success
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (s.contractorName != null)
                          Text(
                            'Contractor: ${s.contractorName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          _formatDate(s.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (s.cost != null)
                          Text(
                            '\$${s.cost!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? s) {
    if (s == null || s.isEmpty) return '—';
    try {
      final d = DateTime.tryParse(s);
      if (d == null) return s;
      return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return s;
    }
  }
}

class _ZoneRowData {
  final int zoneId;
  final String zoneName;
  final String zoneType;
  final double riskScore;
  final double? highest24h;
  final double? highest48h;
  final double? highest7days;
  final double protectionLevel;
  final double hoursSinceSalt;
  final String? lastSaltApplication;

  _ZoneRowData({
    required this.zoneId,
    required this.zoneName,
    required this.zoneType,
    required this.riskScore,
    this.highest24h,
    this.highest48h,
    this.highest7days,
    required this.protectionLevel,
    required this.hoursSinceSalt,
    this.lastSaltApplication,
  });
}

class _PropertyItem {
  final int id;
  final String name;
  final String address;
  final String? mapImageUrl;
  final bool isLocked;

  _PropertyItem({
    required this.id,
    required this.name,
    required this.address,
    this.mapImageUrl,
    this.isLocked = false,
  });

  factory _PropertyItem.fromJson(Map<String, dynamic> json) {
    return _PropertyItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      mapImageUrl: json['map_image_url'] as String?,
      isLocked: json['is_locked'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PropertyItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class _AlertItem {
  final int id;
  final String message;
  final String severity;
  final String createdAt;
  final bool isRead;

  _AlertItem({
    required this.id,
    required this.message,
    required this.severity,
    required this.createdAt,
    required this.isRead,
  });

  factory _AlertItem.fromJson(Map<String, dynamic> json) {
    return _AlertItem(
      id: json['id'] as int,
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'low',
      createdAt: json['created_at']?.toString() ?? '',
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

class _ServiceItem {
  final int id;
  final String serviceType;
  final String status;
  final String createdAt;
  final double? cost;
  final String? contractorName;

  _ServiceItem({
    required this.id,
    required this.serviceType,
    required this.status,
    required this.createdAt,
    this.cost,
    this.contractorName,
  });

  factory _ServiceItem.fromJson(Map<String, dynamic> json) {
    final contractor = json['contractor'];
    String? name;
    if (contractor is Map) {
      name = contractor['company_name'] as String?;
    }
    return _ServiceItem(
      id: json['id'] as int,
      serviceType: json['service_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      cost: (json['cost'] as num?)?.toDouble(),
      contractorName: name,
    );
  }
}
