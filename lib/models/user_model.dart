class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String userType; // 'customer' or 'rider'
  final String? profilePhotoBase64;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.userType,
    this.profilePhotoBase64,
    required this.createdAt,
  });

  UserModel copyWith({
    String? name,
    String? phone,
    String? profilePhotoBase64,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      userType: userType,
      profilePhotoBase64: profilePhotoBase64 ?? this.profilePhotoBase64,
      createdAt: createdAt,
    );
  }

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'userType': userType,
      'profilePhotoBase64': profilePhotoBase64,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firebase document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      userType: map['userType'] ?? 'customer',
      profilePhotoBase64: map['profilePhotoBase64'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
