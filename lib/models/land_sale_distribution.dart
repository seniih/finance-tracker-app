import 'land_contact.dart';

/// Satış tutarının bir yatırımcıya düşen payı.
///
/// Yüzdeyi KULLANICI girer (ortaklık yüzdesinden farklı olabilir);
/// `amountTry` DB trigger'ı tarafından hesaplanır (sale_price_try *
/// percentage / 100) -- uygulama yazmaz, sadece okur. Yüzde toplamının
/// 100'ü aşması DB seviyesinde engellenir.
/// Bkz. supabase/migrations/20260708150000_land_investment_system.sql
class LandSaleDistribution {
  final String id;
  final String landSaleId;
  final String landContactId;

  /// Kullanıcının girdiği dağıtım yüzdesi (0-100)
  final double percentage;

  /// Yatırımcıya düşen TL tutarı -- DB hesaplar (readonly)
  final double amountTry;

  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined relations
  final LandContact? landContact;

  const LandSaleDistribution({
    required this.id,
    required this.landSaleId,
    required this.landContactId,
    required this.percentage,
    this.amountTry = 0.0,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.landContact,
  });

  LandSaleDistribution copyWith({
    String? id,
    String? landSaleId,
    String? landContactId,
    double? percentage,
    double? amountTry,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    LandContact? landContact,
  }) {
    return LandSaleDistribution(
      id: id ?? this.id,
      landSaleId: landSaleId ?? this.landSaleId,
      landContactId: landContactId ?? this.landContactId,
      percentage: percentage ?? this.percentage,
      amountTry: amountTry ?? this.amountTry,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      landContact: landContact ?? this.landContact,
    );
  }

  factory LandSaleDistribution.fromJson(Map<String, dynamic> json) {
    return LandSaleDistribution(
      id: json['id'] as String,
      landSaleId: json['land_sale_id'] as String,
      landContactId: json['land_contact_id'] as String,
      percentage: (json['percentage'] as num).toDouble(),
      amountTry: (json['amount_try'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      landContact: json['land_contacts'] != null
          ? LandContact.fromJson(json['land_contacts'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    // amount_try DB trigger'ı tarafından hesaplanır -- gönderilmiyor.
    return {
      if (id.isNotEmpty) 'id': id,
      'land_sale_id': landSaleId,
      'land_contact_id': landContactId,
      'percentage': percentage,
      if (notes != null) 'notes': notes,
    };
  }
}
