class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? bloodGroup;
  final String? emergencyNotes;
  final bool isGuest;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.bloodGroup,
    this.emergencyNotes,
    this.isGuest = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: json['email'],
      bloodGroup: json['blood_group'],
      emergencyNotes: json['emergency_notes'],
      isGuest: json['is_guest'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'blood_group': bloodGroup,
      'emergency_notes': emergencyNotes,
      'is_guest': isGuest,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? bloodGroup,
    String? emergencyNotes,
    bool? isGuest,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      emergencyNotes: emergencyNotes ?? this.emergencyNotes,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}
