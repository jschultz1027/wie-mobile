import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../config/app_colors.dart';
import '../../models/zone_attributes.dart';
import '../../services/zone_manager_service.dart';

/// Full zone edit screen: all values editable (name, type, orientation, surface, notes, 13 sliders).
/// Matches web ImageZoneEditor attribute panel. See docs/ZONE_MANAGER_LOGIC_FOR_FLUTTER.md.
class ZoneEditScreen extends StatefulWidget {
  final ZoneAttributes zone;
  final int propertyId;
  final bool canEdit;
  final VoidCallback? onSaved;
  final VoidCallback? onDeleted;

  const ZoneEditScreen({
    super.key,
    required this.zone,
    required this.propertyId,
    this.canEdit = true,
    this.onSaved,
    this.onDeleted,
  });

  @override
  State<ZoneEditScreen> createState() => _ZoneEditScreenState();
}

class _ZoneEditScreenState extends State<ZoneEditScreen> {
  final ZoneManagerService _api = ZoneManagerService();
  late ZoneAttributes _zone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _zone = widget.zone.copyWith();
  }

  void _update(String field, dynamic value) {
    setState(() {
      switch (field) {
        case 'name':
          _zone = _zone.copyWith(name: value as String);
          break;
        case 'zoneType':
          _zone = _zone.copyWith(zoneType: value as String);
          break;
        case 'orientation':
          _zone = _zone.copyWith(orientation: value as String);
          break;
        case 'surfaceType':
          _zone = _zone.copyWith(surfaceType: value as String);
          break;
        case 'notes':
          _zone = _zone.copyWith(notes: value as String?);
          break;
        case 'stairs':
          _zone = _zone.copyWith(stairs: value as double);
          break;
        case 'ramp':
          _zone = _zone.copyWith(ramp: value as double);
          break;
        case 'curbStep':
          _zone = _zone.copyWith(curbStep: value as double);
          break;
        case 'shade':
          _zone = _zone.copyWith(shade: value as double);
          break;
        case 'northFacing':
          _zone = _zone.copyWith(northFacing: value as double);
          break;
        case 'treeCover':
          _zone = _zone.copyWith(treeCover: value as double);
          break;
        case 'windCorridor':
          _zone = _zone.copyWith(windCorridor: value as double);
          break;
        case 'vegEdge':
          _zone = _zone.copyWith(vegEdge: value as double);
          break;
        case 'covered':
          _zone = _zone.copyWith(covered: value as double);
          break;
        case 'elevated':
          _zone = _zone.copyWith(elevated: value as double);
          break;
        case 'waterAccumulation':
          _zone = _zone.copyWith(waterAccumulation: value as double);
          break;
        case 'highFootTraffic':
          _zone = _zone.copyWith(highFootTraffic: value as double);
          break;
      }
    });
  }

  Future<void> _save() async {
    if (!widget.canEdit) return;
    if (_zone.notes == null || _zone.notes!.trim().isEmpty) {
      setState(() => _error = 'Notes are required');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      if (_zone.id != null && _zone.id! > 0) {
        await _api.updateZone(widget.propertyId, _zone.id!, _zone);
      } else {
        await _api.createZone(widget.propertyId, _zone);
      }
      if (mounted) {
        widget.onSaved?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    if (!widget.canEdit) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Zone?'),
        content: Text(
          'Are you sure you want to delete zone "${_zone.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, delete it'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (_zone.id == null || _zone.id! <= 0) {
      widget.onDeleted?.call();
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.deleteZone(widget.propertyId, _zone.id!);
      if (mounted) {
        widget.onDeleted?.call();
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mZone = calculateMZone(_zone);
    final decayZone = _zone.zoneDecayMultiplier ?? calculateDecayZone(_zone);
    Color riskColor = AppColors.success;
    String riskLabel = 'Low Risk';
    if (mZone >= 2.2) {
      riskColor = Colors.red;
      riskLabel = 'Very High Risk';
    } else if (mZone >= 1.8) {
      riskColor = Colors.orange;
      riskLabel = 'High Risk';
    } else if (mZone >= 1.4) {
      riskColor = Colors.amber;
      riskLabel = 'Medium Risk';
    }

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: Text(
          _zone.id != null && _zone.id! > 0 ? 'Edit Zone' : 'New Zone',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.canEdit)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Basic info
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Zone name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    TextField(
                      readOnly: !widget.canEdit,
                      controller: TextEditingController(text: _zone.name),
                      onChanged: (v) => _update('name', v),
                      decoration: InputDecoration(
                        hintText: 'Zone 1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _dropdown('Zone type', _zone.zoneType, kZoneTypes, (v) => _update('zoneType', v)),
                    const SizedBox(height: 12),
                    _dropdown('Orientation', _zone.orientation, kOrientations, (v) => _update('orientation', v)),
                    const SizedBox(height: 12),
                    _dropdown('Surface type', _zone.surfaceType, kSurfaceTypes, (v) => _update('surfaceType', v)),
                    const SizedBox(height: 12),
                    const Text('Notes (required)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    TextField(
                      readOnly: !widget.canEdit,
                      maxLines: 3,
                      controller: TextEditingController(text: _zone.notes ?? ''),
                      onChanged: (v) => _update('notes', v.isEmpty ? null : v),
                      decoration: InputDecoration(
                        hintText: 'Observations, conditions...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: (_zone.notes == null || _zone.notes!.trim().isEmpty) ? Colors.red : Colors.grey,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    if (_zone.notes == null || _zone.notes!.trim().isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Notes are required for this zone', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Sliders
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Zone attributes (each 0 – 1)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Range: 0 = None, 0.33 = Light, 0.66 = Medium, 1.0 = Deep', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    _slider('Stairs', _zone.stairs, (v) => _update('stairs', v)),
                    _slider('Ramp', _zone.ramp, (v) => _update('ramp', v)),
                    _slider('Curb step', _zone.curbStep, (v) => _update('curbStep', v)),
                    _slider('Shade', _zone.shade, (v) => _update('shade', v)),
                    _slider('North-facing', _zone.northFacing, (v) => _update('northFacing', v)),
                    _slider('Tree cover', _zone.treeCover, (v) => _update('treeCover', v)),
                    _slider('Wind corridor', _zone.windCorridor, (v) => _update('windCorridor', v)),
                    _slider('Vegetation edge', _zone.vegEdge, (v) => _update('vegEdge', v)),
                    _slider('Covered', _zone.covered, (v) => _update('covered', v)),
                    _slider('Elevated', _zone.elevated, (v) => _update('elevated', v)),
                    _slider('Water accumulation', _zone.waterAccumulation, (v) => _update('waterAccumulation', v)),
                    _slider('High foot traffic', _zone.highFootTraffic, (v) => _update('highFootTraffic', v)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Engine A: M_zone
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Engine A: Risk multiplier (M_zone)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${mZone.toStringAsFixed(2)}×', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: riskColor)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: riskColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: Text(riskLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: riskColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Range: 1.0 (normal) to 2.6 (maximum)', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Engine B: Decay_zone
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Engine B: Salt decay (Decay_zone)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${decayZone.toStringAsFixed(2)}×', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Range: 1.0 to 2.8 (salt effectiveness decay)', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (widget.canEdit && _zone.id != null && _zone.id! > 0)
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Delete zone'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<Map<String, String>> options, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: options.map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!))).toList(),
          onChanged: widget.canEdit ? (v) => v != null ? onChanged(v) : null : null,
        ),
      ],
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text('${value.toStringAsFixed(2)} · ${sliderPresetLabel(value)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 4),
          Slider(
            value: value,
            min: 0,
            max: 1,
            divisions: 100,
            onChanged: widget.canEdit ? onChanged : null,
            activeColor: AppColors.blue600,
          ),
          if (widget.canEdit)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (i) {
                final v = kSliderPresetValues[i];
                final isSelected = (value - v).abs() < 0.01;
                return TextButton(
                  onPressed: () => onChanged(v),
                  style: TextButton.styleFrom(
                    backgroundColor: isSelected ? AppColors.blue600 : Colors.grey.shade200,
                    foregroundColor: isSelected ? Colors.white : Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(kSliderPresetLabels[i], style: const TextStyle(fontSize: 12)),
                );
              }),
            ),
        ],
      ),
    );
  }
}
