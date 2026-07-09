import 'project_investor.dart';

/// Satış tutarının bir PROJE yatırımcısına düşen payı.
///
/// TAMAMEN DB tarafından hesaplanır ve yazılır (uygulamanın tabloya yazma
/// yetkisi yok, sadece okur): (satış - kullanıcının kar payı), yatırımcılara
/// sermaye oranlarına göre dağıtılır. `capitalBasisTry` hesap anındaki
/// toplam sermayeyi şeffaflık için saklar.
/// Bkz. supabase/migrations/20260709130000_profit_center_structure.sql
class LandSaleDistribution {
  final String id;
  final String landSaleId;
  final String projectInvestorId;

  /// Hesap anındaki toplam sermayesi (TL) -- DB yazar (readonly)
  final double capitalBasisTry;

  /// Yatırımcıya düşen TL tutarı -- DB hesaplar (readonly)
  final double amountTry;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined relations
  final ProjectInvestor? projectInvestor;

  const LandSaleDistribution({
    required this.id,
    required this.landSaleId,
    required this.projectInvestorId,
    required this.capitalBasisTry,
    required this.amountTry,
    this.createdAt,
    this.updatedAt,
    this.projectInvestor,
  });

  factory LandSaleDistribution.fromJson(Map<String, dynamic> json) {
    return LandSaleDistribution(
      id: json['id'] as String,
      landSaleId: json['land_sale_id'] as String,
      projectInvestorId: json['project_investor_id'] as String,
      capitalBasisTry: (json['capital_basis_try'] as num).toDouble(),
      amountTry: (json['amount_try'] as num).toDouble(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      projectInvestor: json['project_investors'] != null
          ? ProjectInvestor.fromJson(json['project_investors'] as Map<String, dynamic>)
          : null,
    );
  }

  // toJson yok: bu tabloya uygulama hiçbir zaman yazmaz.
}
