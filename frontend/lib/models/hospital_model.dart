class HospitalModel {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double distanceKm;
  final String emergencyPhone;
  final List<String> emergencyServices;
  final bool hasTraumaCenter;
  final bool hasIcuBed;
  final String estimatedDriveTime;

  HospitalModel({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.emergencyPhone,
    required this.emergencyServices,
    this.hasTraumaCenter = true,
    this.hasIcuBed = true,
    this.estimatedDriveTime = '8 min',
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    return HospitalModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 1.2,
      emergencyPhone: json['emergency_phone'] ?? '108',
      emergencyServices: (json['emergency_services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['24x7 Emergency', 'Trauma Center', 'ICU', 'Cardiac Care'],
      hasTraumaCenter: json['has_trauma_center'] ?? true,
      hasIcuBed: json['has_icu_bed'] ?? true,
      estimatedDriveTime: json['estimated_drive_time'] ?? '8 min',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'distance_km': distanceKm,
      'emergency_phone': emergencyPhone,
      'emergency_services': emergencyServices,
      'has_trauma_center': hasTraumaCenter,
      'has_icu_bed': hasIcuBed,
      'estimated_drive_time': estimatedDriveTime,
    };
  }

  HospitalModel copyWith({
    String? id,
    String? name,
    String? address,
    double? lat,
    double? lng,
    double? distanceKm,
    String? emergencyPhone,
    List<String>? emergencyServices,
    bool? hasTraumaCenter,
    bool? hasIcuBed,
    String? estimatedDriveTime,
  }) {
    return HospitalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      distanceKm: distanceKm ?? this.distanceKm,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      emergencyServices: emergencyServices ?? this.emergencyServices,
      hasTraumaCenter: hasTraumaCenter ?? this.hasTraumaCenter,
      hasIcuBed: hasIcuBed ?? this.hasIcuBed,
      estimatedDriveTime: estimatedDriveTime ?? this.estimatedDriveTime,
    );
  }

  bool get isGovernment =>
      name.toLowerCase().contains('government') ||
      name.toLowerCase().contains('cmch') ||
      name.toLowerCase().contains('esi') ||
      name.toLowerCase().contains('gh') ||
      name.toLowerCase().contains('stanley') ||
      name.toLowerCase().contains('rajiv gandhi') ||
      name.toLowerCase().contains('royapettah') ||
      name.toLowerCase().contains('kilpauk') ||
      name.toLowerCase().contains('omandurar') ||
      emergencyServices.any((s) => s.toLowerCase().contains('108') || s.toLowerCase().contains('free'));
}
