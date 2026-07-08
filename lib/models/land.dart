import '../utils/constants.dart';
import 'project.dart';

class Land {
  final String id;
  final String userId;
  final String? projectId;
  final String title;
  final double? area;
  final double? purchasePrice;
  final double? estimatedValue;
  final DateTime? purchaseDate;
  final LandStatus status;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined relations
  final Project? project;

  const Land({
    required this.id,
    required this.userId,
    this.projectId,
    required this.title,
    this.area,
    this.purchasePrice,
    this.estimatedValue,
    this.purchaseDate,
    this.status = LandStatus.purchased,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.project,
  });

  Land copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? title,
    double? area,
    double? purchasePrice,
    double? estimatedValue,
    DateTime? purchaseDate,
    LandStatus? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    Project? project,
  }) {
    return Land(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      area: area ?? this.area,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      project: project ?? this.project,
    );
  }

  factory Land.fromJson(Map<String, dynamic> json) {
    return Land(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      projectId: json['project_id'] as String?,
      title: json['title'] as String,
      area: (json['area'] as num?)?.toDouble(),
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      estimatedValue: (json['estimated_value'] as num?)?.toDouble(),
      purchaseDate: json['purchase_date'] != null ? DateTime.parse(json['purchase_date'] as String) : null,
      status: LandStatus.fromString(json['status'] as String? ?? 'purchased'),
      description: json['description'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      project: json['projects'] != null ? Project.fromJson(json['projects']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      // Opsiyonel alanlar null olsa da gönderilir; düzenlemede boşaltılan
      // alan DB'de de temizlensin (koşullu gönderim eski değeri bırakıyordu).
      'project_id': projectId,
      'title': title,
      'area': area,
      'purchase_price': purchasePrice,
      'estimated_value': estimatedValue,
      'purchase_date': purchaseDate?.toIso8601String().split('T').first,
      'status': status.value,
      'description': description,
    };
  }
}
