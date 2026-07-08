class Profile {
  final String id;
  final String userId;
  final String companyName;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Profile({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  Profile copyWith({
    String? id,
    String? userId,
    String? companyName,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyName: companyName ?? this.companyName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      companyName: json['company_name'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'company_name': companyName,
      'first_name': firstName,
      'last_name': lastName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    };
  }
}
