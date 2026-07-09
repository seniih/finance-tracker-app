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
  // durumu. Para birimine göre işaretli (signed) değerler --
  // pozitif = cari bana borçlu, negatif = ben cariye borçluyum
  // (ContactBalanceCalculator ile aynı sözleşme).
  // Örnek: {"TRY": 5000, "USD": -200}
  final Map<String, double> openingBalances;

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
    this.openingBalances = const {},
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
    Map<String, double>? openingBalances,
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
      openingBalances: openingBalances ?? this.openingBalances,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contactType: contactType ?? this.contactType,
    );
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    // opening_balances JSONB → Map<String, double>
    final rawBalances = json['opening_balances'];
    final balances = <String, double>{};
    if (rawBalances is Map) {
      for (final entry in rawBalances.entries) {
        final val = entry.value;
        if (val is num && val != 0) {
          balances[entry.key as String] = val.toDouble();
        }
      }
    }
    // Eski sisteme geri dönük uyumluluk (migration çalışmamışsa):
    if (balances.isEmpty && json['opening_balance'] != null) {
      final double oldBal = (json['opening_balance'] as num).toDouble();
      final String oldCur = json['opening_balance_currency'] as String? ?? 'TRY';
      if (oldBal != 0) balances[oldCur] = oldBal;
    }

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
      openingBalances: balances,
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
      'opening_balances': openingBalances,
    };
  }
}
