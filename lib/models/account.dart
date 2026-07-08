import '../utils/constants.dart';

class Account {
  final String id;
  final String userId;
  final String name;
  final AccountType accountType;

  final String currency;
  final double openingBalance;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // UI için ekstra alan (JOIN ile ledger entries üzerinden hesaplanacak bakiye)
  final double? currentBalance;

  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.accountType,

    this.currency = 'TRY',
    this.openingBalance = 0.0,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.currentBalance,
  });

  Account copyWith({
    String? id,
    String? userId,
    String? name,
    AccountType? accountType,

    String? currency,
    double? openingBalance,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? currentBalance,
  }) {
    return Account(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,

      currency: currency ?? this.currency,
      openingBalance: openingBalance ?? this.openingBalance,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      accountType: AccountType.fromString(json['account_type'] as String),

      currency: json['currency'] as String? ?? 'TRY',
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      currentBalance: (json['current_balance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'name': name,
      'account_type': accountType.value,

      'currency': currency,
      'opening_balance': openingBalance,
      // Null olsa da gönderilir: düzenlemede boşaltılan açıklama DB'de de
      // temizlensin (koşullu gönderim eski değeri bırakıyordu).
      'description': description,
    };
  }
}
