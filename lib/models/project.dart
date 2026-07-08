class Project {
  final String id;
  final String userId;
  final String name;
  final String? description;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Project({
    required this.id,
    required this.userId,
    required this.name,
    this.description,

    this.createdAt,
    this.updatedAt,
  });

  Project copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,

      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,

      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'name': name,
      // Null olsa da gönderilir: düzenlemede boşaltılan açıklama temizlensin.
      'description': description,
    };
  }
}
