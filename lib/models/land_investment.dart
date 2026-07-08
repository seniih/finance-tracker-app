/// Bir yatırımcının bir arsaya yaptığı TEK bir ödeme kaydı.
///
/// Yatırımcı farklı tarihlerde farklı kurlarla ödeme yapabilir; "toplam
/// yatırım" bu satırların toplamıdır. `amountUsd` DB'de GENERATED kolondur
/// (amount_try / usd_rate) -- uygulama bu alanı asla yazmaz, sadece okur.
/// Bkz. supabase/migrations/20260708150000_land_investment_system.sql
class LandInvestment {
  final String id;
  final String landContactId;

  /// Ödenen TL tutarı
  final double amountTry;

  /// Ödeme anındaki USD/TRY kuru (eski/devir kayıtlarda bilinmeyebilir)
  final double? usdRate;

  /// USD karşılığı -- DB hesaplar (readonly)
  final double? amountUsd;

  final DateTime paymentDate;
  final String? transactionId;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LandInvestment({
    required this.id,
    required this.landContactId,
    required this.amountTry,
    this.usdRate,
    this.amountUsd,
    required this.paymentDate,
    this.transactionId,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  LandInvestment copyWith({
    String? id,
    String? landContactId,
    double? amountTry,
    double? usdRate,
    double? amountUsd,
    DateTime? paymentDate,
    String? transactionId,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LandInvestment(
      id: id ?? this.id,
      landContactId: landContactId ?? this.landContactId,
      amountTry: amountTry ?? this.amountTry,
      usdRate: usdRate ?? this.usdRate,
      amountUsd: amountUsd ?? this.amountUsd,
      paymentDate: paymentDate ?? this.paymentDate,
      transactionId: transactionId ?? this.transactionId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory LandInvestment.fromJson(Map<String, dynamic> json) {
    return LandInvestment(
      id: json['id'] as String,
      landContactId: json['land_contact_id'] as String,
      amountTry: (json['amount_try'] as num).toDouble(),
      usdRate: (json['usd_rate'] as num?)?.toDouble(),
      amountUsd: (json['amount_usd'] as num?)?.toDouble(),
      paymentDate: DateTime.parse(json['payment_date'] as String),
      transactionId: json['transaction_id'] as String?,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    // amount_usd GENERATED kolon -- bilinçli olarak gönderilmiyor.
    return {
      if (id.isNotEmpty) 'id': id,
      'land_contact_id': landContactId,
      'amount_try': amountTry,
      // Null olsa da gönderilir: düzenlemede temizlenen kur/açıklama DB'de
      // de temizlensin (koşullu gönderim eski değeri bırakıyordu).
      'usd_rate': usdRate,
      'payment_date': paymentDate.toIso8601String().split('T').first,
      'transaction_id': transactionId,
      'description': description,
    };
  }
}
