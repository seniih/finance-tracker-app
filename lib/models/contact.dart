import 'contact_type.dart';

class Contact {
  final String id;
  final String userId;
  final String name;
  final String? contactTypeId;
  final String? phone;
  final String? email;
  final String? taxOffice;
  final String? iban;
  final String? address;
  final String? description;

  // Devir bakiyesi: uygulamayı kullanmaya başlamadan önceki borç/alacak
  // durumu. İşaretli (signed) tek bir değer -- pozitif = cari bana borçlu,
  // negatif = ben cariye borçluyum (ContactBalanceCalculator ile aynı
  // sözleşme). Bkz. supabase/migrations/20260708130000_contacts_opening_balance.sql
  final double openingBalance;
  final String openingBalanceCurrency;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined Relation
  final ContactTypeModel? contactType;

  const Contact({
    required this.id,
    required this.userId,
    required this.name,
    this.contactTypeId,
    this.phone,
    this.email,
    this.taxOffice,
    this.iban,
    this.address,
    this.description,
    this.openingBalance = 0.0,
    this.openingBalanceCurrency = 'TRY',
    this.createdAt,
    this.updatedAt,
    this.contactType,
  });

  Contact copyWith({
    String? id,
    String? userId,
    String? name,
    String? contactTypeId,
    String? phone,
    String? email,
    String? taxOffice,
    String? iban,
    String? address,
    String? description,
    double? openingBalance,
    String? openingBalanceCurrency,
    DateTime? createdAt,
    DateTime? updatedAt,
    ContactTypeModel? contactType,
  }) {
    return Contact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      contactTypeId: contactTypeId ?? this.contactTypeId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxOffice: taxOffice ?? this.taxOffice,
      iban: iban ?? this.iban,
      address: address ?? this.address,
      description: description ?? this.description,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceCurrency: openingBalanceCurrency ?? this.openingBalanceCurrency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contactType: contactType ?? this.contactType,
    );
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      contactTypeId: json['contact_type_id'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      taxOffice: json['tax_office'] as String?,
      iban: json['iban'] as String?,
      address: json['address'] as String?,
      description: json['description'] as String?,
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
      openingBalanceCurrency: json['opening_balance_currency'] as String? ?? 'TRY',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      contactType: json['contact_types'] != null ? ContactTypeModel.fromJson(json['contact_types']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'name': name,
      // Opsiyonel alanlar null olsa da her zaman gönderilir; aksi halde
      // düzenlemede boşaltılan bir alan (örn. silinen telefon) DB'de eski
      // değerinde kalırdı ("if (x != null)" alanı payload'dan düşürüyordu).
      'contact_type_id': contactTypeId,
      'phone': phone,
      'email': email,
      'tax_office': taxOffice,
      'iban': iban,
      'address': address,
      'description': description,
      'opening_balance': openingBalance,
      'opening_balance_currency': openingBalanceCurrency,
    };
  }
}
