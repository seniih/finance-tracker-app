class TransactionModel {
  final String id;
  final String type;
  
  // UUID'ler (Veritabanı ilişkileri için)
  final String? mainAccountId;
  final String? fromAccountId;
  final String? profitCenterId;
  final String? mainCategoryId;
  final String? subCategoryId;
  final String? contactId;

  // İsimler (Arayüzde göstermek için, JOIN ile gelir)
  final String? mainAccountName;
  final String? fromAccountName;
  final String? profitCenterName;
  final String? mainCategoryName;
  final String? subCategoryName;
  final String? contactName;

  final String? currency;
  final double amount;
  final double exchangeRate;
  final String? contactType;
  final String? description;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.type,
    this.mainAccountId,
    this.fromAccountId,
    this.profitCenterId,
    this.mainCategoryId,
    this.subCategoryId,
    this.contactId,
    this.mainAccountName,
    this.fromAccountName,
    this.profitCenterName,
    this.mainCategoryName,
    this.subCategoryName,
    this.contactName,
    this.currency,
    this.amount = 0.0,
    this.exchangeRate = 0.0,
    this.contactType,
    this.description,
    required this.date,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // JOIN sorgusundan dönen isimleri güvenle almak için yardımcı fonksiyon
    String? extractName(dynamic field) {
      if (field == null) return null;
      if (field is Map<String, dynamic>) return field['name'] as String?;
      return null;
    }

    return TransactionModel(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? '',
      
      mainAccountId: json['main_account_id']?.toString(),
      fromAccountId: json['from_account_id']?.toString(),
      profitCenterId: json['profit_center_id']?.toString(),
      mainCategoryId: json['main_category_id']?.toString(),
      subCategoryId: json['sub_category_id']?.toString(),
      contactId: json['contact_id']?.toString(),

      mainAccountName: extractName(json['safes_main_account']),
      fromAccountName: extractName(json['safes_from_account']),
      profitCenterName: extractName(json['profit_centers']),
      mainCategoryName: extractName(json['main_categories']),
      subCategoryName: extractName(json['sub_categories']),
      contactName: extractName(json['contacts']),

      currency: json['currency'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 0.0,
      contactType: json['contact_type'] as String?,
      description: json['description'] as String?,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'main_account_id': mainAccountId,
      'from_account_id': fromAccountId,
      'profit_center_id': profitCenterId,
      'main_category_id': mainCategoryId,
      'sub_category_id': subCategoryId,
      'contact_id': contactId,
      'currency': currency,
      'amount': amount,
      'exchange_rate': exchangeRate,
      'contact_type': contactType,
      'description': description,
      'date': date.toIso8601String(),
    };
  }
}
