class DriverModel {
  final String id;
  final String name;
  final String title;
  final String phone;
  final String? photoUrl;
  final String ambulanceNumber;
  final String
  ambulanceType; // ALS (Advanced Life Support), BLS, Patient Transport
  final double rating;
  final int totalTrips;
  final double currentLat;
  final double currentLng;
  final double heading;
  final DateTime lastLocationUpdate;

  DriverModel({
    required this.id,
    required this.name,
    this.title = '',
    required this.phone,
    this.photoUrl,
    required this.ambulanceNumber,
    required this.ambulanceType,
    this.rating = 5.0,
    this.totalTrips = 0,
    required this.currentLat,
    required this.currentLng,
    this.heading = 0.0,
    required this.lastLocationUpdate,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      photoUrl: json['photo_url'],
      ambulanceNumber: (json['ambulance_number'] ?? '').toString(),
      ambulanceType: (json['ambulance_type'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: (json['total_trips'] as num?)?.toInt() ?? 0,
      currentLat: (json['current_lat'] as num?)?.toDouble() ?? 0.0,
      currentLng: (json['current_lng'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      lastLocationUpdate: json['last_location_update'] != null
          ? DateTime.parse(json['last_location_update'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'phone': phone,
      'photo_url': photoUrl,
      'ambulance_number': ambulanceNumber,
      'ambulance_type': ambulanceType,
      'rating': rating,
      'total_trips': totalTrips,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'heading': heading,
      'last_location_update': lastLocationUpdate.toIso8601String(),
    };
  }

  DriverModel copyWith({
    String? id,
    String? name,
    String? title,
    String? phone,
    String? photoUrl,
    String? ambulanceNumber,
    String? ambulanceType,
    double? rating,
    int? totalTrips,
    double? currentLat,
    double? currentLng,
    double? heading,
    DateTime? lastLocationUpdate,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      ambulanceNumber: ambulanceNumber ?? this.ambulanceNumber,
      ambulanceType: ambulanceType ?? this.ambulanceType,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      heading: heading ?? this.heading,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }
}
