/// Zone model for Zone Manager (FINAL SPEC V1).
/// Matches backend property_zones and web types/zone.ts.
class ZoneGeometryPoint {
  final double? x;
  final double? y;
  final double? lat;
  final double? lng;

  ZoneGeometryPoint({this.x, this.y, this.lat, this.lng});

  factory ZoneGeometryPoint.fromJson(Map<String, dynamic> json) {
    return ZoneGeometryPoint(
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
  }
}

class ZoneAttributes {
  final int? id;
  final String name;
  final String zoneType;
  final String orientation;
  final String surfaceType;
  final double stairs;
  final double ramp;
  final double curbStep;
  final double shade;
  final double northFacing;
  final double treeCover;
  final double windCorridor;
  final double vegEdge;
  final double covered;
  final double elevated;
  final double waterAccumulation;
  final double highFootTraffic;
  final String? notes;
  final List<ZoneGeometryPoint> geometry;
  final double? zoneRiskMultiplier;
  final double? zoneDecayMultiplier;
  final bool? isHighLiabilityZone;

  ZoneAttributes({
    this.id,
    required this.name,
    required this.zoneType,
    required this.orientation,
    required this.surfaceType,
    this.stairs = 0,
    this.ramp = 0,
    this.curbStep = 0,
    this.shade = 0.33,
    this.northFacing = 0,
    this.treeCover = 0,
    this.windCorridor = 0,
    this.vegEdge = 0,
    this.covered = 0,
    this.elevated = 0,
    this.waterAccumulation = 0,
    this.highFootTraffic = 0,
    this.notes,
    required this.geometry,
    this.zoneRiskMultiplier,
    this.zoneDecayMultiplier,
    this.isHighLiabilityZone,
  });

  factory ZoneAttributes.fromJson(Map<String, dynamic> json) {
    final geom = json['geometry'];
    List<ZoneGeometryPoint> geometryList = [];
    if (geom is List) {
      for (var g in geom) {
        if (g is Map<String, dynamic>) {
          geometryList.add(ZoneGeometryPoint.fromJson(g));
        }
      }
    }
    return ZoneAttributes(
      id: json['id'] as int?,
      name: json['name'] as String,
      zoneType: json['zone_type'] as String? ?? 'sidewalk',
      orientation: json['orientation'] as String? ?? 'N',
      surfaceType: json['surface_type'] as String? ?? 'concrete',
      stairs: (json['stairs'] as num?)?.toDouble() ?? 0,
      ramp: (json['ramp'] as num?)?.toDouble() ?? 0,
      curbStep: (json['curb_step'] as num?)?.toDouble() ?? 0,
      shade: (json['shade'] as num?)?.toDouble() ?? 0.33,
      northFacing: (json['north_facing'] as num?)?.toDouble() ?? 0,
      treeCover: (json['tree_cover'] as num?)?.toDouble() ?? 0,
      windCorridor: (json['wind_corridor'] as num?)?.toDouble() ?? 0,
      vegEdge: (json['veg_edge'] as num?)?.toDouble() ?? 0,
      covered: (json['covered'] as num?)?.toDouble() ?? 0,
      elevated: (json['elevated'] as num?)?.toDouble() ?? 0,
      waterAccumulation: (json['water_accumulation'] as num?)?.toDouble() ?? 0,
      highFootTraffic: (json['high_foot_traffic'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      geometry: geometryList,
      zoneRiskMultiplier: (json['zone_risk_multiplier'] as num?)?.toDouble(),
      zoneDecayMultiplier: (json['zone_decay_multiplier'] as num?)?.toDouble(),
      isHighLiabilityZone: json['is_high_liability_zone'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'zone_type': zoneType,
      'orientation': orientation,
      'surface_type': surfaceType,
      'stairs': stairs,
      'ramp': ramp,
      'curb_step': curbStep,
      'shade': shade,
      'north_facing': northFacing,
      'tree_cover': treeCover,
      'wind_corridor': windCorridor,
      'veg_edge': vegEdge,
      'covered': covered,
      'elevated': elevated,
      'water_accumulation': waterAccumulation,
      'high_foot_traffic': highFootTraffic,
      if (notes != null) 'notes': notes,
      'geometry': geometry.map((e) => e.toJson()).toList(),
    };
  }

  ZoneAttributes copyWith({
    int? id,
    String? name,
    String? zoneType,
    String? orientation,
    String? surfaceType,
    double? stairs,
    double? ramp,
    double? curbStep,
    double? shade,
    double? northFacing,
    double? treeCover,
    double? windCorridor,
    double? vegEdge,
    double? covered,
    double? elevated,
    double? waterAccumulation,
    double? highFootTraffic,
    String? notes,
    List<ZoneGeometryPoint>? geometry,
  }) {
    return ZoneAttributes(
      id: id ?? this.id,
      name: name ?? this.name,
      zoneType: zoneType ?? this.zoneType,
      orientation: orientation ?? this.orientation,
      surfaceType: surfaceType ?? this.surfaceType,
      stairs: stairs ?? this.stairs,
      ramp: ramp ?? this.ramp,
      curbStep: curbStep ?? this.curbStep,
      shade: shade ?? this.shade,
      northFacing: northFacing ?? this.northFacing,
      treeCover: treeCover ?? this.treeCover,
      windCorridor: windCorridor ?? this.windCorridor,
      vegEdge: vegEdge ?? this.vegEdge,
      covered: covered ?? this.covered,
      elevated: elevated ?? this.elevated,
      waterAccumulation: waterAccumulation ?? this.waterAccumulation,
      highFootTraffic: highFootTraffic ?? this.highFootTraffic,
      notes: notes ?? this.notes,
      geometry: geometry ?? this.geometry,
      zoneRiskMultiplier: zoneRiskMultiplier,
      zoneDecayMultiplier: zoneDecayMultiplier,
      isHighLiabilityZone: isHighLiabilityZone,
    );
  }
}

// ---------------------------------------------------------------------------
// Zone constants (match web types/zone.ts) for dropdowns and slider presets
// ---------------------------------------------------------------------------

const double kSliderNone = 0.0;
const double kSliderLight = 0.33;
const double kSliderMedium = 0.66;
const double kSliderDeep = 1.0;

const List<double> kSliderPresetValues = [kSliderNone, kSliderLight, kSliderMedium, kSliderDeep];
const List<String> kSliderPresetLabels = ['None', 'Light', 'Medium', 'Deep'];

String sliderPresetLabel(double value) {
  if ((value - kSliderNone).abs() < 0.01) return 'None';
  if ((value - kSliderLight).abs() < 0.01) return 'Light';
  if ((value - kSliderMedium).abs() < 0.01) return 'Medium';
  if ((value - kSliderDeep).abs() < 0.01) return 'Deep';
  return 'Custom';
}

const List<Map<String, String>> kZoneTypes = [
  {'value': 'stairs', 'label': 'Stairs'},
  {'value': 'ramp', 'label': 'Ramp'},
  {'value': 'entrance', 'label': 'Entrance'},
  {'value': 'corridor', 'label': 'Corridor'},
  {'value': 'parkade', 'label': 'Parkade'},
  {'value': 'sidewalk', 'label': 'Sidewalk'},
  {'value': 'driveway', 'label': 'Driveway'},
  {'value': 'parking_lot', 'label': 'Parking Lot'},
  {'value': 'other', 'label': 'Other'},
];

const List<Map<String, String>> kOrientations = [
  {'value': 'N', 'label': 'North (N)'},
  {'value': 'NE', 'label': 'Northeast (NE)'},
  {'value': 'E', 'label': 'East (E)'},
  {'value': 'SE', 'label': 'Southeast (SE)'},
  {'value': 'S', 'label': 'South (S)'},
  {'value': 'SW', 'label': 'Southwest (SW)'},
  {'value': 'W', 'label': 'West (W)'},
  {'value': 'NW', 'label': 'Northwest (NW)'},
];

const List<Map<String, String>> kSurfaceTypes = [
  {'value': 'asphalt', 'label': 'Asphalt (Light Slip)'},
  {'value': 'concrete', 'label': 'Concrete (Medium Slip)'},
  {'value': 'pavers', 'label': 'Pavers (Medium Slip)'},
  {'value': 'gravel', 'label': 'Gravel (HIGH SLIP)'},
  {'value': 'metal', 'label': 'Metal (HIGH SLIP)'},
  {'value': 'wood', 'label': 'Wood (Medium Slip)'},
];

/// Engine A: M_zone = 1 + Σ(wi × si), capped at 2.6. Matches web ImageZoneEditor.
double calculateMZone(ZoneAttributes zone) {
  double surfaceWeight;
  switch (zone.surfaceType) {
    case 'asphalt':
      surfaceWeight = 0.33;
      break;
    case 'gravel':
    case 'metal':
      surfaceWeight = 1.0;
      break;
    default:
      surfaceWeight = 0.66;
  }
  double m = 1.0 +
      (0.55 * zone.stairs +
          0.45 * zone.ramp +
          0.25 * zone.curbStep +
          0.35 * zone.shade +
          0.25 * zone.northFacing +
          0.20 * zone.treeCover +
          0.15 * zone.windCorridor +
          0.20 * zone.vegEdge +
          0.20 * zone.covered +
          0.30 * zone.elevated +
          0.65 * zone.waterAccumulation +
          0.30 * zone.highFootTraffic +
          0.25 * surfaceWeight);
  return m > 2.6 ? 2.6 : m;
}

/// Engine B: Decay_zone = 1 + Σ(dj × sj), capped at 2.8. Matches backend zone_routes.
double calculateDecayZone(ZoneAttributes zone) {
  double surfaceWeight;
  switch (zone.surfaceType) {
    case 'asphalt':
      surfaceWeight = 0.33;
      break;
    case 'gravel':
    case 'metal':
      surfaceWeight = 1.0;
      break;
    default:
      surfaceWeight = 0.66;
  }
  double d = 1.0 +
      (0.25 * zone.stairs +
          0.25 * zone.ramp +
          0.15 * zone.shade +
          0.25 * zone.windCorridor +
          0.25 * zone.vegEdge +
          0.15 * zone.covered +
          0.20 * zone.elevated +
          0.85 * zone.waterAccumulation +
          0.35 * zone.highFootTraffic +
          0.15 * surfaceWeight);
  return d > 2.8 ? 2.8 : d;
}
