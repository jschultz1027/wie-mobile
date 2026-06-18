import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/property.dart';
import '../../models/zone_attributes.dart';
import '../../providers/auth_provider.dart';
import '../../services/zone_manager_service.dart';
import '../../utils/app_notification.dart';
import '../../widgets/property_map_with_zones.dart';
import '../../widgets/property_risk_summary.dart';
import 'zone_edit_screen.dart';

/// Zone Manager detail: property header, map placeholder, zones, actions.
/// See docs/ZONE_MANAGER_LOGIC_FOR_FLUTTER.md.
class ZoneManagerDetailScreen extends StatefulWidget {
  final Property property;

  const ZoneManagerDetailScreen({super.key, required this.property});

  @override
  State<ZoneManagerDetailScreen> createState() => _ZoneManagerDetailScreenState();
}

class _ZoneManagerDetailScreenState extends State<ZoneManagerDetailScreen> {
  final ZoneManagerService _api = ZoneManagerService();
  String? _mapImageUrl;
  List<ZoneAttributes> _zones = [];
  bool _locked = false;
  String? _lockedBy;
  bool _canRecordManually = false;
  String _assignmentReason = '';
  bool _hasActiveAssignment = false;
  bool _loading = true;
  String? _error;
  bool _lockLoading = false;
  bool _isDrawing = false;
  final List<ZoneGeometryPoint> _drawingPoints = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getMapUrl(widget.property.id),
        _api.getZones(widget.property.id),
        _api.getLockStatus(widget.property.id),
        _api.getActiveAssignment(widget.property.id),
      ]);
      setState(() {
        _mapImageUrl = (results[0] as MapUrlResponse).mapImageUrl;
        _zones = results[1] as List<ZoneAttributes>;
        _locked = (results[2] as LockStatusResponse).locked;
        _lockedBy = (results[2] as LockStatusResponse).lockedBy;
        _canRecordManually = (results[3] as ActiveAssignmentResponse).canRecordManually;
        _assignmentReason = (results[3] as ActiveAssignmentResponse).reason;
        _hasActiveAssignment = (results[3] as ActiveAssignmentResponse).hasActiveAssignment;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleLock() async {
    setState(() => _lockLoading = true);
    try {
      if (_locked) {
        await _api.unlockProperty(widget.property.id);
        setState(() {
          _locked = false;
          _lockedBy = null;
          _lockLoading = false;
        });
        if (mounted) _showSnack('Property unlocked');
      } else {
        await _api.lockProperty(widget.property.id);
        await _loadAll();
        setState(() => _lockLoading = false);
        if (mounted) _showSnack('Property locked');
      }
    } catch (e) {
      setState(() => _lockLoading = false);
      if (mounted) _showSnack('Failed: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (isError) {
      AppNotification.error(context, msg);
    } else {
      AppNotification.success(context, msg);
    }
  }

  void _startDrawingZone() {
    if (_mapImageUrl == null || _mapImageUrl!.isEmpty || !_canEdit) return;
    setState(() {
      _isDrawing = true;
      _drawingPoints.clear();
    });
  }

  void _onMapTapWhenDrawing(ZoneGeometryPoint point) {
    setState(() => _drawingPoints.add(point));
  }

  void _cancelDrawing() {
    setState(() {
      _isDrawing = false;
      _drawingPoints.clear();
    });
  }

  Future<void> _finishDrawing() async {
    if (_drawingPoints.length < 3) return;
    final geometry = List<ZoneGeometryPoint>.from(_drawingPoints);
    setState(() {
      _isDrawing = false;
      _drawingPoints.clear();
    });
    final nextIndex = _zones.length + 1;
    final newZone = ZoneAttributes(
      name: 'Zone $nextIndex',
      zoneType: 'sidewalk',
      orientation: 'N',
      surfaceType: 'concrete',
      geometry: geometry,
      notes: '',
    );
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ZoneEditScreen(
          zone: newZone,
          propertyId: widget.property.id,
          canEdit: true,
          onSaved: _loadAll,
          onDeleted: _loadAll,
        ),
      ),
    );
    if (saved == true && mounted) _loadAll();
  }

  bool get _canEdit {
    final auth = context.read<AuthProvider>().user;
    return !_locked || (auth?.isAdmin ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?.isAdmin ?? false;

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'Zone Manager',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back to list
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 18, color: AppColors.blue600),
                    label: const Text('Back to Properties', style: TextStyle(color: AppColors.blue600)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                  ),
                  const SizedBox(height: 8),
                  // Risk at a glance (when API returned risk data)
                  if (widget.property.hasRiskData) ...[
                    PropertyRiskAtAGlance(property: widget.property),
                    const SizedBox(height: 12),
                  ],
                  // Property header card
                  _buildHeaderCard(isAdmin),
                  const SizedBox(height: 16),
                  if (_error != null) _buildErrorBanner(),
                  if (_error != null) const SizedBox(height: 12),
                  // Map / No map
                  _buildMapSection(),
                  const SizedBox(height: 16),
                  // Zones list placeholder
                  _buildZonesSection(),
                  const SizedBox(height: 16),
                  // Record Salt & Upload Map
                  _buildActionButtons(isAdmin),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(bool isAdmin) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.property.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.property.latitude.toStringAsFixed(4)}, ${widget.property.longitude.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      if (_locked && _lockedBy != null) ...[
                        const SizedBox(height: 4),
                        Text('Locked by: $_lockedBy', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                      ],
                      if (_hasActiveAssignment || _assignmentReason.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_assignmentReason, style: const TextStyle(fontSize: 12, color: AppColors.blue600)),
                      ],
                    ],
                  ),
                ),
                if (_locked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 4),
                        Text('Locked', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
                      ],
                    ),
                  ),
                if (_hasActiveAssignment && !_locked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.blue600.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Contractor Onsite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.blue600)),
                  ),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _lockLoading ? null : _toggleLock,
                  icon: _lockLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_locked ? Icons.lock_open : Icons.lock, size: 18),
                  label: Text(_locked ? 'Unlock Property' : 'Lock Property'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _locked ? Colors.orange : Colors.grey.shade700,
                    side: BorderSide(color: _locked ? Colors.orange : Colors.grey),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          TextButton(onPressed: _loadAll, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _mapImageUrl != null && _mapImageUrl!.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Map & Zones', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        _isDrawing ? 'Tap map to add points' : 'Pinch to zoom',
                        style: TextStyle(fontSize: 12, color: _isDrawing ? AppColors.blue600 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  PropertyMapWithZones(
                    mapImageUrl: _mapImageUrl!,
                    zones: _zones,
                    height: 340,
                    isDrawing: _isDrawing,
                    drawingPoints: _drawingPoints,
                    onTapWhenDrawing: _isDrawing ? _onMapTapWhenDrawing : null,
                  ),
                  const SizedBox(height: 8),
                  if (_isDrawing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _cancelDrawing,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _drawingPoints.length >= 3 ? _finishDrawing : null,
                            icon: const Icon(Icons.check, size: 18),
                            label: Text('Finish (${_drawingPoints.length} pts)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blue600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_canEdit)
                    ElevatedButton.icon(
                      onPressed: _startDrawingZone,
                      icon: const Icon(Icons.add_road, size: 20),
                      label: const Text('Start Drawing Zone'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.map_outlined, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No Map Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Upload a property map to draw zones.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_canEdit)
                    ElevatedButton.icon(
                      onPressed: () => _showSnack('Use Upload Map below (file picker to be wired)'),
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Upload Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildZonesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Zones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('${_zones.length} zone(s)', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            if (_zones.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No zones yet. Draw zones on the map above.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ..._zones.map((z) => ListTile(
                    leading: const Icon(Icons.layers, color: AppColors.blue600),
                    title: Text(z.name),
                    subtitle: Text('${z.zoneType} · ${z.surfaceType}'),
                    onTap: _canEdit
                        ? () async {
                            final saved = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => ZoneEditScreen(
                                  zone: z,
                                  propertyId: widget.property.id,
                                  canEdit: _canEdit,
                                  onSaved: _loadAll,
                                  onDeleted: _loadAll,
                                ),
                              ),
                            );
                            if (saved == true && mounted) _loadAll();
                          }
                        : null,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isAdmin) {
    final saltEnabled = _mapImageUrl != null && _zones.isNotEmpty && _canRecordManually;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: saltEnabled
              ? () => _showSnack('Record Salt Application modal to be implemented')
              : null,
          icon: const Icon(Icons.water_drop, size: 20),
          label: const Text('Record Salt Application'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _canEdit ? () => _showSnack('Upload Map: file picker to be wired') : null,
          icon: const Icon(Icons.upload_file, size: 20),
          label: const Text('Upload Map'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.blue600,
            side: const BorderSide(color: AppColors.blue600),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
