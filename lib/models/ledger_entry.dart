import 'account.dart';
import 'transaction.dart';

class LedgerEntry {
  final String id;
  final String transactionId;
  final String? accountId;
  final String entryType; // 'debit' veya 'credit'
  final double amount;
  final DateTime? createdAt;

  // Joined Relations
  final TransactionModel? transaction;
  final Account? account;

  const LedgerEntry({
    required this.id,
    required this.transactionId,
    this.accountId,
    required this.entryType,
    required this.amount,
    this.createdAt,
    this.transaction,
    this.account,
  });

  LedgerEntry copyWith({
    String? id,
    String? transactionId,
    String? accountId,
    String? entryType,
    double? amount,
    DateTime? createdAt,
    TransactionModel? transaction,
    Account? account,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      accountId: accountId ?? this.accountId,
      entryType: entryType ?? this.entryType,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      transaction: transaction ?? this.transaction,
      account: account ?? this.account,
    );
  }

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      accountId: json['account_id'] as String?,
      entryType: json['entry_type'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      transaction: json['transactions'] != null ? TransactionModel.fromJson(json['transactions']) : null,
      account: json['accounts'] != null ? Account.fromJson(json['accounts']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'transaction_id': transactionId,
      if (accountId != null) 'account_id': accountId,
      'entry_type': entryType,
      'amount': amount,
    };
  }
}
