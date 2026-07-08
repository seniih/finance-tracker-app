import 'land.dart';
import 'contact.dart';
import 'land_investment.dart';

/// Bir arsanın yatırımcısı/ortağı (arsa <-> cari bağlantısı).
///
/// Tek tutarlı eski investment_amount/paid_amount/remaining_amount alanları
/// kaldırıldı: ödemeler artık satır satır [LandInvestment] kayıtlarında
/// tutulur, toplamlar buradaki getter'lardan türetilir (tek doğruluk
/// kaynağı). Bkz. supabase/migrations/20260708150000_land_investment_system.sql
class LandContact {
  final String id;
  final String landId;
  final String contactId;
  final String role;

  /// Arsadaki ortaklık yüzdesi (0-100)
  final double? sharePercentage;

  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined relations
  final Land? land;
  final Contact? contact;
  final List<LandInvestment> investments;

  const LandContact({
    required this.id,
    required this.landId,
    required this.contactId,
    this.role = 'investor',
    this.sharePercentage,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.land,
    this.contact,
    this.investments = const [],
  });

  /// Toplam yatırılan TL (tüm ödemelerin toplamı)
  double get totalPaidTry => investments.fold(0.0, (s, i) => s + i.amountTry);

  /// Toplam USD karşılığı (kuru bilinen ödemelerin toplamı)
  double get totalPaidUsd => investments.fold(0.0, (s, i) => s + (i.amountUsd ?? 0));

  /// Kuru bilinmeyen (USD karşılığı hesaplanamayan) ödeme var mı?
  bool get hasUnknownRatePayments => investments.any((i) => i.usdRate == null);

  LandContact copyWith({
    String? id,
    String? landId,
    String? contactId,
    String? role,
    double? sharePercentage,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Land? land,
    Contact? contact,
    List<LandInvestment>? investments,
  }) {
    return LandContact(
      id: id ?? this.id,
      landId: landId ?? this.landId,
      contactId: contactId ?? this.contactId,
      role: role ?? this.role,
      sharePercentage: sharePercentage ?? this.sharePercentage,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      land: land ?? this.land,
      contact: contact ?? this.contact,
      investments: investments ?? this.investments,
    );
  }

  factory LandContact.fromJson(Map<String, dynamic> json) {
    final investmentsJson = json['land_investments'] as List?;
    final investments = investmentsJson != null
        ? (investmentsJson
            .map((i) => LandInvestment.fromJson(i as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)))
        : <LandInvestment>[];

    return LandContact(
      id: json['id'] as String,
      landId: json['land_id'] as String,
      contactId: json['contact_id'] as String,
      role: json['role'] as String? ?? 'investor',
      sharePercentage: (json['share_percentage'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      land: json['lands'] != null ? Land.fromJson(json['lands']) : null,
      contact: json['contacts'] != null ? Contact.fromJson(json['contacts']) : null,
      investments: investments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'land_id': landId,
      'contact_id': contactId,
      'role': role,
      // Null olsa da gönderilir: düzenlemede boşaltılan yüzde/not temizlensin.
      'share_percentage': sharePercentage,
      'notes': notes,
    };
  }
}
