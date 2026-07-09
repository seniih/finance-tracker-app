import 'contact.dart';
import 'project_investment.dart';

/// Projeye sermaye koyan yatırımcı (proje <-> cari bağlantısı).
///
/// Elle tutulan yüzde/tutar alanı YOK: ortaklık oranı sermaye ödemelerinden
/// ([ProjectInvestment] satırlarından) türetilir -- tek doğruluk kaynağı.
/// Satış dağıtımı da DB'de bu oranlara göre otomatik hesaplanır.
/// Bkz. supabase/migrations/20260709130000_profit_center_structure.sql
class ProjectInvestor {
  final String id;
  final String projectId;
  final String contactId;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined relations
  final Contact? contact;
  final List<ProjectInvestment> investments;

  const ProjectInvestor({
    required this.id,
    required this.projectId,
    required this.contactId,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.contact,
    this.investments = const [],
  });

  /// Toplam konan sermaye TL (tüm ödemelerin toplamı)
  double get totalCapitalTry => investments.fold(0.0, (s, i) => s + i.amountTry);

  /// Toplam USD karşılığı (kuru bilinen ödemelerin toplamı)
  double get totalCapitalUsd => investments.fold(0.0, (s, i) => s + (i.amountUsd ?? 0));

  /// Kuru bilinmeyen (USD karşılığı hesaplanamayan) ödeme var mı?
  bool get hasUnknownRatePayments => investments.any((i) => i.usdRate == null);

  ProjectInvestor copyWith({
    String? id,
    String? projectId,
    String? contactId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Contact? contact,
    List<ProjectInvestment>? investments,
  }) {
    return ProjectInvestor(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      contactId: contactId ?? this.contactId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contact: contact ?? this.contact,
      investments: investments ?? this.investments,
    );
  }

  factory ProjectInvestor.fromJson(Map<String, dynamic> json) {
    final investmentsJson = json['project_investments'] as List?;
    final investments = investmentsJson != null
        ? (investmentsJson
            .map((i) => ProjectInvestment.fromJson(i as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)))
        : <ProjectInvestment>[];

    return ProjectInvestor(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      contactId: json['contact_id'] as String,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      contact: json['contacts'] != null ? Contact.fromJson(json['contacts']) : null,
      investments: investments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'project_id': projectId,
      'contact_id': contactId,
      // Null olsa da gönderilir: düzenlemede boşaltılan not temizlensin.
      'notes': notes,
    };
  }
}
