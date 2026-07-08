import '../utils/constants.dart';
import 'project.dart';
import 'land.dart';
import 'contact.dart';
import 'account.dart';
import 'category.dart';

class TransactionModel {
  final String id;
  final String userId;
  final TransactionType transactionType;
  final String? projectId;
  final String? landId;
  final String? contactId;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final double amount;
  final String currency;
  final double exchangeRate;
  final String? description;
  final DateTime transactionDate;
  final TransactionStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined Relations
  final Project? project;
  final Land? land;
  final Contact? contact;
  final Account? account;
  final Account? toAccount;
  final Category? category;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.transactionType,
    this.projectId,
    this.landId,
    this.contactId,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    required this.amount,
    this.currency = 'TRY',
    this.exchangeRate = 1.0,
    this.description,
    required this.transactionDate,
    this.status = TransactionStatus.completed,
    this.createdAt,
    this.updatedAt,
    this.project,
    this.land,
    this.contact,
    this.account,
    this.toAccount,
    this.category,
  });

  TransactionModel copyWith({
    String? id,
    String? userId,
    TransactionType? transactionType,
    String? projectId,
    String? landId,
    String? contactId,
    String? accountId,
    String? toAccountId,
    String? categoryId,
    double? amount,
    String? currency,
    double? exchangeRate,
    String? description,
    DateTime? transactionDate,
    TransactionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Project? project,
    Land? land,
    Contact? contact,
    Account? account,
    Account? toAccount,
    Category? category,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      transactionType: transactionType ?? this.transactionType,
      projectId: projectId ?? this.projectId,
      landId: landId ?? this.landId,
      contactId: contactId ?? this.contactId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      project: project ?? this.project,
      land: land ?? this.land,
      contact: contact ?? this.contact,
      account: account ?? this.account,
      toAccount: toAccount ?? this.toAccount,
      category: category ?? this.category,
    );
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      transactionType: TransactionType.fromString(json['transaction_type'] as String),
      projectId: json['project_id'] as String?,
      landId: json['land_id'] as String?,
      contactId: json['contact_id'] as String?,
      accountId: json['account_id'] as String?,
      toAccountId: json['to_account_id'] as String?,
      categoryId: json['category_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'TRY',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      description: json['description'] as String?,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      status: TransactionStatus.fromString(json['status'] as String? ?? 'Completed'),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      
      project: json['projects'] != null ? Project.fromJson(json['projects']) : null,
      land: json['lands'] != null ? Land.fromJson(json['lands']) : null,
      contact: json['contacts'] != null ? Contact.fromJson(json['contacts']) : null,
      account: json['from_account'] != null ? Account.fromJson(json['from_account']) : null,
      toAccount: json['to_account'] != null ? Account.fromJson(json['to_account']) : null,
      category: json['categories'] != null ? Category.fromJson(json['categories']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'transaction_type': transactionType.value,
      if (projectId != null) 'project_id': projectId,
      if (landId != null) 'land_id': landId,
      if (contactId != null) 'contact_id': contactId,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (categoryId != null) 'category_id': categoryId,
      'amount': amount,
      'currency': currency,
      'exchange_rate': exchangeRate,
      if (description != null) 'description': description,
      'transaction_date': transactionDate.toIso8601String(),
      // NOT: 'status' kolonu DB şemasında (transactions tablosu) yok --
      // burada gönderilirse Postgres "column does not exist" hatası verir.
      // TransactionStatus alanı sadece istemci tarafında tutuluyor.
    };
  }
}
