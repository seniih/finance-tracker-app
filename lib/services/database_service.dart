import '../models/profile.dart';
import '../models/contact_type.dart';
import '../models/contact.dart';
import '../models/account.dart';
import '../models/profit_center.dart';
import '../models/project.dart';
import '../models/land.dart';
import '../models/project_investor.dart';
import '../models/project_investment.dart';
import '../models/land_sale.dart';
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

  // ── Profit Centers (Kar Merkezleri) ────────────────────────────────────────
  // Hiyerarşinin tepesi: kar merkezi -> proje -> arsa + yatırımcı.
  Future<List<ProfitCenter>> getProfitCenters();
  Future<void> addProfitCenter(ProfitCenter profitCenter);
  Future<void> updateProfitCenter(ProfitCenter profitCenter);
  Future<void> deleteProfitCenter(String id);

  // ── Projects ───────────────────────────────────────────────────────────────
  Future<List<Project>> getProjects({String? profitCenterId});
  Future<void> addProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String id);

  // ── Lands (Projenin ürünleri) ──────────────────────────────────────────────
  Future<List<Land>> getLands({String? projectId});
  Future<void> addLand(Land land);
  Future<void> updateLand(Land land);
  Future<void> deleteLand(String id);

  // ── Project Investors (Projeye sermaye koyanlar) ───────────────────────────
  Future<List<ProjectInvestor>> getProjectInvestors(String projectId);
  Future<void> addProjectInvestor(ProjectInvestor investor);
  Future<void> updateProjectInvestor(ProjectInvestor investor);
  Future<void> deleteProjectInvestor(String id);

  // ── Project Investments (Sermaye Ödemeleri) ────────────────────────────────
  // Her ödeme ayrı satır: tarih + TL tutar + o günkü USD kuru.
  // USD karşılığı DB'de hesaplanır (GENERATED kolon), buradan sadece okunur.
  Future<void> addProjectInvestment(ProjectInvestment investment);
  Future<void> updateProjectInvestment(ProjectInvestment investment);
  Future<void> deleteProjectInvestment(String id);

  // ── Land Sales (Arsa Satışı) ───────────────────────────────────────────────
  // Arsa başına en fazla bir satış (DB'de land_id UNIQUE). Kullanıcı satış
  // tutarı + kasa + kendi kar payı YÜZDESİNİ girer. Satış + kasa girişi tek
  // Postgres transaction'ında yazılır (create_land_sale_with_cash RPC).
  // Kalan tutarın yatırımcılara sermaye oranlı dağıtımını DB trigger'ı
  // hesaplar (uygulama dağıtım yazamaz); arsa durumu otomatik 'sold' olur.
  // Satış DÜZENLEME yok: kasa işlemiyle tutarlılık bozulmasın diye
  // düzeltme = satışı silip yeniden kaydetmektir. Silmede bağlı kasa
  // işlemini DB trigger'ı da siler.
  Future<LandSale?> getLandSale(String landId);
  Future<void> createLandSale(LandSale sale, {required String accountId});
  Future<void> deleteLandSale(String id);

  // Cari başına toplam satış dağıtım borcu (TL): yatırımcılara satıştan
  // doğan borçlar cari bakiyesine "ben borçluyum" olarak yansıtılır.
  // Kaynak: investor_sale_debts view'i (borç = dağıtım satırları).
  Future<Map<String, double>> getInvestorSaleDebts();

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
