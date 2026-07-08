import '../models/profile.dart';
import '../models/contact_type.dart';
import '../models/contact.dart';
import '../models/account.dart';
import '../models/project.dart';
import '../models/land.dart';
import '../models/land_contact.dart';
import '../models/land_investment.dart';
import '../models/land_sale.dart';
import '../models/land_sale_distribution.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/ledger_entry.dart';

/// Silme işlemi bağımlılık nedeniyle engellendiğinde fırlatılır.
/// [message] kullanıcıya gösterilecek Türkçe açıklamadır.
class DependencyException implements Exception {
  final String message;
  const DependencyException(this.message);
  @override
  String toString() => message;
}

abstract class DatabaseService {
  // ── Profiles ───────────────────────────────────────────────────────────────
  Future<Profile?> getProfile();
  Future<void> updateProfile(Profile profile);

  // ── Contacts ───────────────────────────────────────────────────────────────
  Future<List<ContactTypeModel>> getContactTypes();
  Future<void> addContactType(ContactTypeModel type);
  Future<void> deleteContactType(String id);

  Future<List<Contact>> getContacts([String? typeId]);
  Future<void> addContact(Contact contact);
  Future<void> updateContact(Contact contact);
  Future<void> deleteContact(String id);

  // ── Accounts ───────────────────────────────────────────────────────────────
  Future<List<Account>> getAccounts();
  Future<void> addAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> deleteAccount(String id);

  // ── Projects ───────────────────────────────────────────────────────────────
  Future<List<Project>> getProjects();
  Future<void> addProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String id);

  // ── Lands ──────────────────────────────────────────────────────────────────
  Future<List<Land>> getLands({String? projectId});
  Future<void> addLand(Land land);
  Future<void> updateLand(Land land);
  Future<void> deleteLand(String id);

  // ── Land Contacts (Yatırımcı/Ortak) ────────────────────────────────────────
  Future<List<LandContact>> getLandContacts(String landId);
  Future<void> addLandContact(LandContact landContact);
  Future<void> updateLandContact(LandContact landContact);
  Future<void> deleteLandContact(String id);

  // ── Land Investments (Yatırımcı Ödemeleri) ─────────────────────────────────
  // Her ödeme ayrı satır: tarih + TL tutar + o günkü USD kuru.
  // USD karşılığı DB'de hesaplanır (GENERATED kolon), buradan sadece okunur.
  Future<void> addLandInvestment(LandInvestment investment);
  Future<void> updateLandInvestment(LandInvestment investment);
  Future<void> deleteLandInvestment(String id);

  // ── Land Sales (Arsa Satışı + Yüzdelik Dağıtım) ────────────────────────────
  // Arsa başına en fazla bir satış (DB'de land_id UNIQUE). Satış kaydı
  // dağıtım satırlarıyla birlikte oluşturulur; dağıtım tutarlarını DB
  // trigger'ı hesaplar, arsa durumunu da otomatik 'sold' yapar.
  Future<LandSale?> getLandSale(String landId);
  Future<void> createLandSale(LandSale sale, List<LandSaleDistribution> distributions);
  Future<void> deleteLandSale(String id);

  // ── Categories ─────────────────────────────────────────────────────────────
  Future<List<Category>> getCategories(); // Hiyerarşik getirmeli
  Future<void> addCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> deleteCategory(String id);

  // ── Transactions & Ledgers ─────────────────────────────────────────────────
  Future<List<TransactionModel>> getTransactions({
    String? accountId,
    String? projectId,
    String? landId,
    String? contactId,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<void> addTransaction(TransactionModel transaction, List<LedgerEntry> ledgers);

  // Bir işlemi günceller. Hesap/tutar/yön değişebileceği için eski
  // ledger_entries silinip yeni [ledgers] ile değiştirilir.
  Future<void> updateTransaction(TransactionModel transaction, List<LedgerEntry> ledgers);
  Future<void> deleteTransaction(String id);

  // Bir kasa/hesabın ekstresi için: o hesabı etkileyen tüm ledger_entries
  // kayıtlarını (bağlı işlem bilgisiyle birlikte) döner. transactions.account_id
  // her zaman dolu olmadığından (bkz. formlar) bu sorgu ledger_entries
  // üzerinden yapılmalı.
  Future<List<LedgerEntry>> getLedgerEntriesForAccount(String accountId);

  // Bir işlemi düzenlerken hangi hesap(lar)ın kullanıldığını öğrenmek için.
  Future<List<LedgerEntry>> getLedgerEntriesForTransaction(String transactionId);
}
