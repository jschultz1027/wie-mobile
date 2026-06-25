class EquipmentConstants {
  EquipmentConstants._();

  static const attachmentTypes = ['truck', 'atv', 'skid_steer', 'bobcat'];
  static const videoRequiredTypes = ['truck', 'atv', 'skid_steer', 'bobcat', 'sidewalk_salter'];

  static const truckSizeClasses = [
    {'value': 'half_ton', 'label': '½ ton'},
    {'value': 'three_quarter_ton', 'label': '¾ ton'},
    {'value': 'one_ton', 'label': '1 ton'},
  ];

  static const plowTypes = [
    {'value': 'straight_blade', 'label': 'Straight blade'},
    {'value': 'v_plow', 'label': 'V-plow'},
    {'value': 'box_plow', 'label': 'Box plow'},
    {'value': 'pusher_blade', 'label': 'Pusher blade'},
  ];

  static const salterTypes = [
    {'value': 'tailgate_salter', 'label': 'Tailgate salter'},
    {'value': 'v_box_salter', 'label': 'V-box salter'},
  ];

  static const salterMaterials = [
    {'value': 'rock_salt', 'label': 'Rock salt'},
    {'value': 'treated_salt', 'label': 'Treated salt'},
    {'value': 'ice_melt', 'label': 'Ice melt'},
    {'value': 'sand_salt_mix', 'label': 'Sand/salt mix'},
  ];

  static bool supportsAttachments(String type) => attachmentTypes.contains(type);

  static String? labelFor(List<Map<String, String>> options, String? value) {
    if (value == null || value.isEmpty) return null;
    for (final opt in options) {
      if (opt['value'] == value) return opt['label'];
    }
    return value.replaceAll('_', ' ');
  }
}

class EquipmentCapabilityForm {
  String truckMake;
  String truckModel;
  String truckYear;
  String truckSizeClass;
  bool hasPlowBlade;
  bool hasSalter;
  String plowType;
  String plowWidth;
  String salterType;
  String salterCapacity;
  List<String> salterMaterials;

  EquipmentCapabilityForm({
    this.truckMake = '',
    this.truckModel = '',
    this.truckYear = '',
    this.truckSizeClass = '',
    this.hasPlowBlade = false,
    this.hasSalter = false,
    this.plowType = '',
    this.plowWidth = '',
    this.salterType = '',
    this.salterCapacity = '',
    this.salterMaterials = const [],
  });

  EquipmentCapabilityForm copyWith({
    String? truckMake,
    String? truckModel,
    String? truckYear,
    String? truckSizeClass,
    bool? hasPlowBlade,
    bool? hasSalter,
    String? plowType,
    String? plowWidth,
    String? salterType,
    String? salterCapacity,
    List<String>? salterMaterials,
  }) {
    return EquipmentCapabilityForm(
      truckMake: truckMake ?? this.truckMake,
      truckModel: truckModel ?? this.truckModel,
      truckYear: truckYear ?? this.truckYear,
      truckSizeClass: truckSizeClass ?? this.truckSizeClass,
      hasPlowBlade: hasPlowBlade ?? this.hasPlowBlade,
      hasSalter: hasSalter ?? this.hasSalter,
      plowType: plowType ?? this.plowType,
      plowWidth: plowWidth ?? this.plowWidth,
      salterType: salterType ?? this.salterType,
      salterCapacity: salterCapacity ?? this.salterCapacity,
      salterMaterials: salterMaterials ?? this.salterMaterials,
    );
  }

  factory EquipmentCapabilityForm.fromJson(Map<String, dynamic> json) {
    return EquipmentCapabilityForm(
      truckMake: json['truck_make']?.toString() ?? '',
      truckModel: json['truck_model']?.toString() ?? '',
      truckYear: json['truck_year']?.toString() ?? '',
      truckSizeClass: json['truck_size_class']?.toString() ?? '',
      hasPlowBlade: json['has_plow_blade'] == true,
      hasSalter: json['has_salter'] == true,
      plowType: json['plow_type']?.toString() ?? '',
      plowWidth: json['plow_width']?.toString() ?? '',
      salterType: json['salter_type']?.toString() ?? '',
      salterCapacity: json['salter_capacity']?.toString() ?? '',
      salterMaterials: json['salter_materials'] is List
          ? (json['salter_materials'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'truck_make': truckMake.trim().isEmpty ? null : truckMake.trim(),
      'truck_model': truckModel.trim().isEmpty ? null : truckModel.trim(),
      'truck_year': truckYear.trim().isEmpty ? null : int.tryParse(truckYear.trim()),
      'truck_size_class': truckSizeClass.isEmpty ? null : truckSizeClass,
      'has_plow_blade': hasPlowBlade,
      'has_salter': hasSalter,
      'plow_type': hasPlowBlade && plowType.isNotEmpty ? plowType : null,
      'plow_width': hasPlowBlade && plowWidth.trim().isNotEmpty ? plowWidth.trim() : null,
      'salter_type': hasSalter && salterType.isNotEmpty ? salterType : null,
      'salter_capacity': hasSalter && salterCapacity.trim().isNotEmpty ? salterCapacity.trim() : null,
      'salter_materials': hasSalter && salterMaterials.isNotEmpty ? salterMaterials : null,
    };
  }

  List<String> summaryLines(String equipmentType) {
    final lines = <String>[];
    if (equipmentType == 'truck') {
      final truckParts = [truckMake, truckModel, truckYear].where((e) => e.trim().isNotEmpty);
      if (truckParts.isNotEmpty) lines.add(truckParts.join(' '));
      final size = EquipmentConstants.labelFor(EquipmentConstants.truckSizeClasses, truckSizeClass);
      if (size != null) lines.add(size);
    }
    if (hasPlowBlade) {
      final plow = EquipmentConstants.labelFor(EquipmentConstants.plowTypes, plowType) ?? 'Yes';
      lines.add('Plow: $plow${plowWidth.trim().isNotEmpty ? ' ($plowWidth)' : ''}');
    }
    if (hasSalter) {
      final salter = EquipmentConstants.labelFor(EquipmentConstants.salterTypes, salterType) ?? 'Yes';
      lines.add('Salter: $salter${salterCapacity.trim().isNotEmpty ? ' ($salterCapacity)' : ''}');
    }
    if (hasSalter && salterMaterials.isNotEmpty) {
      final mats = salterMaterials
          .map((m) => EquipmentConstants.labelFor(EquipmentConstants.salterMaterials, m) ?? m)
          .join(', ');
      lines.add('Materials: $mats');
    }
    return lines;
  }
}
