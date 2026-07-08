import '../utils/constants.dart';

class Category {
  final String id;
  final String userId;
  final String? parentId;
  final String name;
  final CategoryType type;
  final String? icon;
  final String? color;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Ekranda ağaç yapısı göstermek için
  final List<Category> subCategories;

  const Category({
    required this.id,
    required this.userId,
    this.parentId,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.createdAt,
    this.updatedAt,
    this.subCategories = const [],
  });

  Category copyWith({
    String? id,
    String? userId,
    String? parentId,
    String? name,
    CategoryType? type,
    String? icon,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Category>? subCategories,
  }) {
    return Category(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subCategories: subCategories ?? this.subCategories,
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      parentId: json['parent_id'] as String?,
      name: json['name'] as String,
      type: CategoryType.fromString(json['type'] as String),
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      // Null olsa da gönderilir: alt kategori köke taşınabilsin, ikon/renk
      // temizlenebilsin (koşullu gönderim eski değeri bırakıyordu).
      'parent_id': parentId,
      'name': name,
      'type': type.value,
      'icon': icon,
      'color': color,
    };
  }
}
