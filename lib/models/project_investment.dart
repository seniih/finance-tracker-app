/// Bir yatırımcının PROJEYE koyduğu TEK bir sermaye ödemesi.
///
/// Yatırımcı farklı tarihlerde farklı kurlarla ödeme yapabilir; "toplam
/// sermaye" bu satırların toplamıdır. `amountUsd` DB'de GENERATED kolondur
/// (amount_try / usd_rate) -- uygulama bu alanı asla yazmaz, sadece okur.
/// Bkz. supabase/migrations/20260709130000_profit_center_structure.sql
class ProjectInvestment {
  final String id;
  final String projectInvestorId;

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

  const ProjectInvestment({
    required this.id,
    required this.projectInvestorId,
    required this.amountTry,
    this.usdRate,
    this.amountUsd,
    required this.paymentDate,
    this.transactionId,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  ProjectInvestment copyWith({
    String? id,
    String? projectInvestorId,
    double? amountTry,
    double? usdRate,
    double? amountUsd,
    DateTime? paymentDate,
    String? transactionId,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectInvestment(
      id: id ?? this.id,
      projectInvestorId: projectInvestorId ?? this.projectInvestorId,
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

  factory ProjectInvestment.fromJson(Map<String, dynamic> json) {
    return ProjectInvestment(
      id: json['id'] as String,
      projectInvestorId: json['project_investor_id'] as String,
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
      'project_investor_id': projectInvestorId,
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
