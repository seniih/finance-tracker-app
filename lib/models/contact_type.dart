class ContactTypeModel {
  final String id;
  final String userId;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ContactTypeModel({
    required this.id,
    required this.userId,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory ContactTypeModel.fromJson(Map<String, dynamic> json) {
    return ContactTypeModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'name': name,
    };
  }
}
