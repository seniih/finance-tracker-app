import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_models.dart';
import '../models/contact_models.dart';
import '../models/safe_models.dart';
import '../models/transaction_models.dart';
import 'database_service.dart';

class SupabaseDatabaseService implements DatabaseService {
  final _client = Supabase.instance.client;

  /// Giriş yapmış kullanıcının ID'si.
  String get _uid => _client.auth.currentUser!.id;

  // ── Contact Types ──────────────────────────────────────────────────────────
  @override
  Future<List<ContactTypeModel>> getContactTypes() async {
    final data = await _client.from('contact_types').select().order('name');
    return (data as List).map((json) => ContactTypeModel.fromJson(json)).toList();
  }

  @override
  Future<void> addContactType(ContactTypeModel type) async {
    await _client.from('contact_types').insert({
      ...type.toJson(),
      'user_id': _uid,
    });
  }

  // ── Contacts ───────────────────────────────────────────────────────────────
  @override
  Future<List<Contact>> getContacts([String? type]) async {
    var query = _client.from('contacts').select();
    if (type != null && type.trim().isNotEmpty) {
      query = query.eq('type', type);
    }
    final data = await query.order('name');
    return (data as List).map((json) => Contact.fromJson(json)).toList();
  }

  @override
  Future<void> addContact(Contact contact) async {
    await _client.from('contacts').insert({
      ...contact.toJson(),
      'user_id': _uid,
    });
  }

  @override
  Future<void> updateContact(Contact contact) async {
    // İşlemlerde artık ID tuttuğumuz için cascade rename yapmaya gerek yok!
    await _client.from('contacts').update(contact.toJson()).eq('id', contact.id);
  }

  // ── Safes ──────────────────────────────────────────────────────────────────
  @override
  Future<List<Safe>> getSafes() async {
    final data = await _client.from('safes').select().order('name');
    return (data as List).map((json) => Safe.fromJson(json)).toList();
  }

  @override
  Future<void> addSafe(Safe safe) async {
    await _client.from('safes').insert({
      ...safe.toJson(),
      'user_id': _uid,
    });
  }

  // ── Profit Centers & Categories ────────────────────────────────────────────
  @override
  Future<List<ProfitCenter>> getProfitCenters() async {
    final data = await _client
        .from('profit_centers')
        .select('*, main_categories(*, sub_categories(*))');
    return (data as List).map((json) => ProfitCenter.fromJson(json)).toList();
  }

  @override
  Future<void> addProfitCenter(ProfitCenter pc) async {
    await _client.from('profit_centers').insert({
      ...pc.toJson(),
      'user_id': _uid,
    });
  }

  @override
  Future<void> updateProfitCenter(ProfitCenter pc) async {
    await _client.from('profit_centers').update({
      'name': pc.name,
      'balance': pc.balance,
      'currency': pc.currency,
      'exchange_rate': pc.exchangeRate,
    }).eq('id', pc.id);
  }

  @override
  Future<void> addMainCategory(MainCategory mc, String profitCenterId) async {
    await _client.from('main_categories').insert({
      ...mc.toJson(profitCenterId),
      'user_id': _uid,
    });
  }

  @override
  Future<void> updateMainCategory(MainCategory mc) async {
    await _client.from('main_categories').update({
      'name': mc.name,
      'balance': mc.balance,
      'currency': mc.currency,
      'exchange_rate': mc.exchangeRate,
    }).eq('id', mc.id);
  }

  @override
  Future<void> addSubCategory(SubCategory sc, String mainCategoryId) async {
    await _client.from('sub_categories').insert({
      ...sc.toJson(mainCategoryId),
      'user_id': _uid,
    });
  }

  @override
  Future<void> updateSubCategory(SubCategory sc) async {
    await _client.from('sub_categories').update({
      'name': sc.name,
      'balance': sc.balance,
      'currency': sc.currency,
      'exchange_rate': sc.exchangeRate,
    }).eq('id', sc.id);
  }

  // ── Transactions ───────────────────────────────────────────────────────────
  @override
  Future<void> saveTransaction(Map<String, dynamic> transactionData) async {
    // Tüm bakiye güncellemeleri Supabase PostgreSQL trigger'ları tarafından
    // otomatik olarak hesaplanacaktır. Sadece insert yapıyoruz.
    final data = {...transactionData, 'user_id': _uid};
    await _client.from('transactions').insert(data);
  }

  @override
  Future<List<TransactionModel>> getTransactions({String? safeId, String? contactId}) async {
    var query = _client.from('transactions').select('''
      *,
      safes_main_account:safes!main_account_id(name),
      safes_from_account:safes!from_account_id(name),
      profit_centers(name),
      main_categories(name),
      sub_categories(name),
      contacts(name)
    ''');

    if (safeId != null && safeId.trim().isNotEmpty) {
      query = query.or('main_account_id.eq.$safeId,from_account_id.eq.$safeId');
    }
    if (contactId != null && contactId.trim().isNotEmpty) {
      query = query.eq('contact_id', contactId);
    }

    final response = await query.order('date', ascending: false);
    return (response as List).map((json) => TransactionModel.fromJson(json)).toList();
  }

  @override
  Future<void> deleteTransaction(TransactionModel transaction) async {
    // İşlem silindiğinde veritabanındaki tetikleyici (Trigger) silme (DELETE)
    // olayını yakalayıp, işlemle ilgili eklenen/çıkan bakiyeleri geri alacaktır.
    await _client.from('transactions').delete().eq('id', transaction.id);
  }

  // ── Deletes ────────────────────────────────────────────────────────────────
  @override
  Future<void> deleteSafe(Safe safe) async {
    // FK 'ON DELETE RESTRICT' yapıldığı için eğer işlemlerde kullanılmışsa
    // veritabanı otomatik olarak PostgreSQL Exception fırlatacaktır.
    await _client.from('safes').delete().eq('id', safe.id);
  }

  @override
  Future<void> deleteContact(Contact contact) async {
    await _client.from('contacts').delete().eq('id', contact.id);
  }

  @override
  Future<void> deleteContactType(String typeName) async {
    final contacts = await getContacts(typeName);
    if (contacts.isNotEmpty) {
      throw Exception('Bu türe bağlı ${contacts.length} adet cari var. '
          'Önce altındaki carileri silin veya türlerini değiştirin.');
    }
    await _client.from('contact_types').delete().eq('name', typeName);
  }

  @override
  Future<void> deleteProfitCenter(String id) async {
    final mcRes = await _client.from('main_categories').select('id').eq('profit_center_id', id);
    for (var mc in mcRes) {
      await deleteMainCategory(mc['id'] as String);
    }
    await _client.from('profit_centers').delete().eq('id', id);
  }

  @override
  Future<void> deleteMainCategory(String id) async {
    final scRes = await _client.from('sub_categories').select('id').eq('main_category_id', id);
    for (var sc in scRes) {
      await deleteSubCategory(sc['id'] as String);
    }
    await _client.from('main_categories').delete().eq('id', id);
  }

  @override
  Future<void> deleteSubCategory(String id) async {
    await _client.from('sub_categories').delete().eq('id', id);
  }
}
