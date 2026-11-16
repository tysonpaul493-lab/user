import '../core/constants/app_constants.dart';
import 'driver_model.dart';
import 'hospital_model.dart';

enum BookingStatus {
  requestSubmitted,
  findingAmbulance,
  driverAssigned,
  driverApproaching,
  driverArrived,
  patientPickedUp,
  travelingToHospital,
  arrivedAtHospital,
  tripCompleted,
  cancelled,
  noAmbulanceAvailable,
}

extension BookingStatusExtension on BookingStatus {
  String get label {
    switch (this) {
      case BookingStatus.requestSubmitted:
        return 'Request Submitted';
      case BookingStatus.findingAmbulance:
        return 'Finding Ambulance';
      case BookingStatus.driverAssigned:
        return 'Driver Assigned';
      case BookingStatus.driverApproaching:
        return 'Driver Approaching';
      case BookingStatus.driverArrived:
        return 'Driver Arrived at Pickup';
      case BookingStatus.patientPickedUp:
        return 'Patient Picked Up';
      case BookingStatus.travelingToHospital:
        return 'Traveling to Hospital';
      case BookingStatus.arrivedAtHospital:
        return 'Arrived at Hospital';
      case BookingStatus.tripCompleted:
        return 'Trip Completed';
      case BookingStatus.cancelled:
        return 'Booking Cancelled';
      case BookingStatus.noAmbulanceAvailable:
        return 'No Ambulance Available';
    }
  }

  String localizedLabel(String locale) {
    if (locale == 'ta') {
      switch (this) {
        case BookingStatus.requestSubmitted:
          return 'கோரிக்கை சமர்ப்பிக்கப்பட்டது';
        case BookingStatus.findingAmbulance:
          return 'ஆம்புலன்ஸ் தேடப்படுகிறது';
        case BookingStatus.driverAssigned:
          return 'ஓட்டுநர் நியமிக்கப்பட்டார்';
        case BookingStatus.driverApproaching:
          return 'ஆம்புலன்ஸ் வருகிறது';
        case BookingStatus.driverArrived:
          return 'ஆம்புலன்ஸ் வந்துவிட்டது';
        case BookingStatus.patientPickedUp:
          return 'நோயாளி ஏற்றப்பட்டார்';
        case BookingStatus.travelingToHospital:
          return 'மருத்துவமனைக்கு செல்கிறது';
        case BookingStatus.arrivedAtHospital:
          return 'மருத்துவமனையை அடைந்தது';
        case BookingStatus.tripCompleted:
          return 'பயணம் முடிந்தது';
        case BookingStatus.cancelled:
          return 'ரத்து செய்யப்பட்டது';
        case BookingStatus.noAmbulanceAvailable:
          return 'ஆம்புலன்ஸ் கிடைக்கவில்லை';
      }
    }
    return label;
  }

  bool get isActive =>
      this != BookingStatus.tripCompleted &&
      this != BookingStatus.cancelled &&
      this != BookingStatus.noAmbulanceAvailable;
}

class BookingModel {
  final String id;
  final String referenceNumber;
  final BookingStatus status;
  final String userId;
  final String callbackPhone;
  final String? patientName;
  final String emergencyCategory;
  final String? landmark;
  final String? notes;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final HospitalModel? destinationHospital;
  final DriverModel? driver;
  final int etaMinutes;
  final double distanceKm;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedPickupAt;
  final DateTime? patientPickedUpAt;
  final DateTime? completedAt;
  final String? cancellationReason;

  BookingModel({
    required this.id,
    required this.referenceNumber,
    required this.status,
    required this.userId,
    required this.callbackPhone,
    this.patientName,
    this.emergencyCategory = 'General Emergency',
    this.landmark,
    this.notes,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    this.destinationHospital,
    this.driver,
    this.etaMinutes = 0,
    this.distanceKm = 0.0,
    required this.createdAt,
    this.acceptedAt,
    this.arrivedPickupAt,
    this.patientPickedUpAt,
    this.completedAt,
    this.cancellationReason,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id']?.toString() ?? '',
      referenceNumber: json['reference_number'] ?? json['booking_reference'] ?? '#LR-${DateTime.now().millisecondsSinceEpoch % 100000}',
      status: _statusFromString(json['status']),
      userId: json['user_id']?.toString() ?? '',
      callbackPhone: json['callback_phone'] ?? json['patient_phone'] ?? '',
      patientName: json['patient_name'],
      emergencyCategory: json['emergency_category'] ?? 'General Emergency',
      landmark: json['landmark'] ?? json['pickup_landmark'],
      notes: json['notes'] ?? json['essential_instructions'],
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? (json['pickup_latitude'] as num?)?.toDouble() ?? AppConstants.defaultLat,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? (json['pickup_longitude'] as num?)?.toDouble() ?? AppConstants.defaultLng,
      pickupAddress: json['pickup_address'] ?? AppConstants.defaultLocationName,
      destinationHospital: json['destination_hospital'] != null
          ? (json['destination_hospital'] is Map<String, dynamic> 
              ? HospitalModel.fromJson(json['destination_hospital']) 
              : null)
          : null,
      driver: json['driver'] != null ? DriverModel.fromJson(json['driver']) : null,
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'].toString())?.toLocal()
          : null,
      arrivedPickupAt: json['arrived_pickup_at'] != null
          ? DateTime.tryParse(json['arrived_pickup_at'].toString())?.toLocal()
          : null,
      patientPickedUpAt: (json['patient_picked_up_at'] ?? json['patient_onboard_at']) != null
          ? DateTime.tryParse((json['patient_picked_up_at'] ?? json['patient_onboard_at']).toString())?.toLocal()
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())?.toLocal()
          : null,
      cancellationReason: json['cancellation_reason'] ?? json['cancel_reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference_number': referenceNumber,
      'status': status.name,
      'user_id': userId,
      'callback_phone': callbackPhone,
      'patient_name': patientName,
      'emergency_category': emergencyCategory,
      'landmark': landmark,
      'notes': notes,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup_address': pickupAddress,
      'destination_hospital': destinationHospital?.toJson(),
      'driver': driver?.toJson(),
      'eta_minutes': etaMinutes,
      'distance_km': distanceKm,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'arrived_pickup_at': arrivedPickupAt?.toIso8601String(),
      'patient_picked_up_at': patientPickedUpAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
    };
  }

  static BookingStatus _statusFromString(String? status) {
    switch (status) {
      case 'request_submitted':
      case 'requestSubmitted':
        return BookingStatus.requestSubmitted;
      case 'finding_ambulance':
      case 'findingAmbulance':
        return BookingStatus.findingAmbulance;
      case 'driver_assigned':
      case 'driverAssigned':
        return BookingStatus.driverAssigned;
      case 'driver_approaching':
      case 'driverApproaching':
        return BookingStatus.driverApproaching;
      case 'driver_arrived':
      case 'driverArrived':
        return BookingStatus.driverArrived;
      case 'patient_picked_up':
      case 'patientPickedUp':
        return BookingStatus.patientPickedUp;
      case 'traveling_to_hospital':
      case 'travelingToHospital':
        return BookingStatus.travelingToHospital;
      case 'arrived_at_hospital':
      case 'arrivedAtHospital':
        return BookingStatus.arrivedAtHospital;
      case 'trip_completed':
      case 'tripCompleted':
        return BookingStatus.tripCompleted;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'no_ambulance_available':
      case 'noAmbulanceAvailable':
        return BookingStatus.noAmbulanceAvailable;
      default:
        return BookingStatus.findingAmbulance;
    }
  }

  BookingModel copyWith({
    String? id,
    String? referenceNumber,
    BookingStatus? status,
    String? userId,
    String? callbackPhone,
    String? patientName,
    String? emergencyCategory,
    String? landmark,
    String? notes,
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    HospitalModel? destinationHospital,
    DriverModel? driver,
    int? etaMinutes,
    double? distanceKm,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? arrivedPickupAt,
    DateTime? patientPickedUpAt,
    DateTime? completedAt,
    String? cancellationReason,
  }) {
    return BookingModel(
      id: id ?? this.id,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      callbackPhone: callbackPhone ?? this.callbackPhone,
      patientName: patientName ?? this.patientName,
      emergencyCategory: emergencyCategory ?? this.emergencyCategory,
      landmark: landmark ?? this.landmark,
      notes: notes ?? this.notes,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationHospital: destinationHospital ?? this.destinationHospital,
      driver: driver ?? this.driver,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      arrivedPickupAt: arrivedPickupAt ?? this.arrivedPickupAt,
      patientPickedUpAt: patientPickedUpAt ?? this.patientPickedUpAt,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}
