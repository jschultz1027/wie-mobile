import 'package:flutter/material.dart';
import '../constants/equipment_constants.dart';

class EquipmentCapabilityFields extends StatelessWidget {
  final String equipmentType;
  final EquipmentCapabilityForm form;
  final ValueChanged<EquipmentCapabilityForm> onChanged;

  const EquipmentCapabilityFields({
    super.key,
    required this.equipmentType,
    required this.form,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final showAttachments = EquipmentConstants.supportsAttachments(equipmentType);
    final showTruckDetails = equipmentType == 'truck';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTruckDetails) ...[
          const Text('Truck Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _textField('Make', form.truckMake, (v) => onChanged(form.copyWith(truckMake: v))),
          _textField('Model', form.truckModel, (v) => onChanged(form.copyWith(truckModel: v))),
          _textField('Year', form.truckYear, (v) => onChanged(form.copyWith(truckYear: v)), keyboardType: TextInputType.number),
          _dropdown('Size / Class', form.truckSizeClass, EquipmentConstants.truckSizeClasses, (v) => onChanged(form.copyWith(truckSizeClass: v ?? ''))),
          const SizedBox(height: 24),
        ],
        if (showAttachments) ...[
          const Text('Snow Attachments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: const Text('Plow'),
            value: form.hasPlowBlade,
            onChanged: (v) => onChanged(form.copyWith(hasPlowBlade: v ?? false)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: const Text('Salter'),
            value: form.hasSalter,
            onChanged: (v) => onChanged(form.copyWith(hasSalter: v ?? false)),
          ),
          if (form.hasPlowBlade) ...[
            const SizedBox(height: 16),
            const Text('Plow Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _dropdown('Plow Type', form.plowType, EquipmentConstants.plowTypes, (v) => onChanged(form.copyWith(plowType: v ?? ''))),
            _textField('Plow Width / Size', form.plowWidth, (v) => onChanged(form.copyWith(plowWidth: v))),
          ],
          if (form.hasSalter) ...[
            const SizedBox(height: 16),
            const Text('Salter Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _dropdown('Salter Type', form.salterType, EquipmentConstants.salterTypes, (v) => onChanged(form.copyWith(salterType: v ?? ''))),
            _textField('Capacity / Size', form.salterCapacity, (v) => onChanged(form.copyWith(salterCapacity: v))),
            const SizedBox(height: 12),
            const Text('Materials It Can Spread', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            ...EquipmentConstants.salterMaterials.map((opt) {
              final value = opt['value']!;
              final selected = form.salterMaterials.contains(value);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(opt['label']!),
                value: selected,
                onChanged: (_) {
                  final next = List<String>.from(form.salterMaterials);
                  if (selected) {
                    next.remove(value);
                  } else {
                    next.add(value);
                  }
                  onChanged(form.copyWith(salterMaterials: next));
                },
              );
            }),
          ],
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _textField(String label, String value, ValueChanged<String> onChanged, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<Map<String, String>> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Select')),
          ...options.map((opt) => DropdownMenuItem(value: opt['value'], child: Text(opt['label']!))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
