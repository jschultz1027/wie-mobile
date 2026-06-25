import '../constants/equipment_constants.dart';

class EquipmentItem {
  final int? id;
  final String equipmentType;
  final int units;
  final bool hasPlowBlade;
  final bool hasSalter;
  final bool handBucketSalting;
  final bool handShoveling;
  final String? videoUrl;
  final bool verified;
  final String? truckMake;
  final String? truckModel;
  final int? truckYear;
  final String? truckSizeClass;
  final String? plowType;
  final String? plowWidth;
  final String? salterType;
  final String? salterCapacity;
  final List<String> salterMaterials;

  EquipmentItem({
    this.id,
    required this.equipmentType,
    required this.units,
    required this.hasPlowBlade,
    required this.hasSalter,
    required this.handBucketSalting,
    required this.handShoveling,
    this.videoUrl,
    required this.verified,
    this.truckMake,
    this.truckModel,
    this.truckYear,
    this.truckSizeClass,
    this.plowType,
    this.plowWidth,
    this.salterType,
    this.salterCapacity,
    this.salterMaterials = const [],
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    return EquipmentItem(
      id: json['id'],
      equipmentType: json['equipment_type'],
      units: json['units'] ?? 1,
      hasPlowBlade: json['has_plow_blade'] ?? false,
      hasSalter: json['has_salter'] ?? false,
      handBucketSalting: json['hand_bucket_salting'] ?? false,
      handShoveling: json['hand_shoveling'] ?? false,
      videoUrl: json['video_url'],
      verified: json['verified'] ?? false,
      truckMake: json['truck_make']?.toString(),
      truckModel: json['truck_model']?.toString(),
      truckYear: json['truck_year'] is int ? json['truck_year'] as int : int.tryParse('${json['truck_year'] ?? ''}'),
      truckSizeClass: json['truck_size_class']?.toString(),
      plowType: json['plow_type']?.toString(),
      plowWidth: json['plow_width']?.toString(),
      salterType: json['salter_type']?.toString(),
      salterCapacity: json['salter_capacity']?.toString(),
      salterMaterials: json['salter_materials'] is List
          ? (json['salter_materials'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  List<String> get summaryLines {
    final form = EquipmentCapabilityForm.fromJson({
      'truck_make': truckMake,
      'truck_model': truckModel,
      'truck_year': truckYear,
      'truck_size_class': truckSizeClass,
      'has_plow_blade': hasPlowBlade,
      'has_salter': hasSalter,
      'plow_type': plowType,
      'plow_width': plowWidth,
      'salter_type': salterType,
      'salter_capacity': salterCapacity,
      'salter_materials': salterMaterials,
    });
    return form.summaryLines(equipmentType);
  }
}
