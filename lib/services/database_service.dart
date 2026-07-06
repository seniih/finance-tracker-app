import '../models/contact_models.dart';
import '../models/safe_models.dart';
import '../models/category_models.dart';
import '../models/transaction_models.dart';

/// Tüm uygulamanın veritabanı işlemlerini standartlaştıran Arayüz (Interface)
abstract class DatabaseService {
  // Contact Types
  Future<List<ContactTypeModel>> getContactTypes();
  Future<void> addContactType(ContactTypeModel type);

  // Contacts
  Future<List<Contact>> getContacts([String? type]);
  Future<void> addContact(Contact contact);
  Future<void> updateContact(Contact contact);

  // Safes
  Future<List<Safe>> getSafes();
  Future<void> addSafe(Safe safe);


  // Balance Updates are handled via PostgreSQL Triggers automatically.

  // Profit Centers & Categories
  Future<List<ProfitCenter>> getProfitCenters();
  Future<void> addProfitCenter(ProfitCenter pc);
  Future<void> updateProfitCenter(ProfitCenter pc);

  Future<void> addMainCategory(MainCategory mc, String profitCenterId);
  Future<void> updateMainCategory(MainCategory mc);

  Future<void> addSubCategory(SubCategory sc, String mainCategoryId);
  Future<void> updateSubCategory(SubCategory sc);

  // Transactions
  Future<void> saveTransaction(Map<String, dynamic> transactionData);
  Future<List<TransactionModel>> getTransactions({String? safeId, String? contactId});
  Future<void> deleteTransaction(TransactionModel transaction);

  // Deletes
  Future<void> deleteSafe(Safe safe);
  Future<void> deleteContact(Contact contact);
  Future<void> deleteContactType(String typeName);
  Future<void> deleteProfitCenter(String id);
  Future<void> deleteMainCategory(String id);
  Future<void> deleteSubCategory(String id);
}

/// Proje genelinde erişilebilmesi için global bir örnek.
/// Supabase veya Firebase seçildiğinde buradaki dbService
/// değiştirilerek tüm proje tek satırda buluta taşınacak.
late DatabaseService dbService;
