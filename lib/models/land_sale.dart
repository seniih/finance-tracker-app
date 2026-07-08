import 'contact.dart';
import 'land_sale_distribution.dart';

/// Bir arsanın satış kaydı. Arsa başına en fazla bir satış olabilir
/// (DB'de land_id UNIQUE). `salePriceUsd` GENERATED kolondur -- uygulama
/// yazmaz, sadece okur. Satış kaydı eklenince DB trigger'ı arsayı 'sold'
/// yapar, satış silinirse 'purchased'a döndürür.
/// Bkz. supabase/migrations/20260708150000_land_investment_system.sql
class LandSale {
  final String id;
  final String landId;

  /// Satış tutarı (TL)
  final double salePriceTry;

  /// Satış anındaki USD/TRY kuru
  final double? usdRate;

  /// USD karşılığı -- DB hesaplar (readonly)
  final double? salePriceUsd;

  final DateTime saleDate;
  final String? buyerContactId;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined relations
  final Contact? buyer;
  final List<LandSaleDistribution> distributions;

  const LandSale({
    required this.id,
    required this.landId,
    required this.salePriceTry,
    this.usdRate,
    this.salePriceUsd,
    required this.saleDate,
    this.buyerContactId,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.buyer,
    this.distributions = const [],
  });

  LandSale copyWith({
    String? id,
    String? landId,
    double? salePriceTry,
    double? usdRate,
    double? salePriceUsd,
    DateTime? saleDate,
    String? buyerContactId,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    Contact? buyer,
    List<LandSaleDistribution>? distributions,
  }) {
    return LandSale(
      id: id ?? this.id,
      landId: landId ?? this.landId,
      salePriceTry: salePriceTry ?? this.salePriceTry,
      usdRate: usdRate ?? this.usdRate,
      salePriceUsd: salePriceUsd ?? this.salePriceUsd,
      saleDate: saleDate ?? this.saleDate,
      buyerContactId: buyerContactId ?? this.buyerContactId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      buyer: buyer ?? this.buyer,
      distributions: distributions ?? this.distributions,
    );
  }

  factory LandSale.fromJson(Map<String, dynamic> json) {
    return LandSale(
      id: json['id'] as String,
      landId: json['land_id'] as String,
      salePriceTry: (json['sale_price_try'] as num).toDouble(),
      usdRate: (json['usd_rate'] as num?)?.toDouble(),
      salePriceUsd: (json['sale_price_usd'] as num?)?.toDouble(),
      saleDate: DateTime.parse(json['sale_date'] as String),
      buyerContactId: json['buyer_contact_id'] as String?,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      buyer: json['contacts'] != null ? Contact.fromJson(json['contacts']) : null,
      distributions: json['land_sale_distributions'] != null
          ? (json['land_sale_distributions'] as List)
              .map((d) => LandSaleDistribution.fromJson(d as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    // sale_price_usd GENERATED kolon -- bilinçli olarak gönderilmiyor.
    return {
      if (id.isNotEmpty) 'id': id,
      'land_id': landId,
      'sale_price_try': salePriceTry,
      if (usdRate != null) 'usd_rate': usdRate,
      'sale_date': saleDate.toIso8601String().split('T').first,
      if (buyerContactId != null) 'buyer_contact_id': buyerContactId,
      if (description != null) 'description': description,
    };
  }
}
