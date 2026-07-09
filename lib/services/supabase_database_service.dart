import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/contact.dart';
import '../models/contact_type.dart';
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
import 'database_service.dart';

class SupabaseDatabaseService implements DatabaseService {
  final _client = Supabase.instance.client;
  String get _uid => _client.auth.currentUser!.id;

  // ── Profiles ───────────────────────────────────────────────────────────────
  @override
  Future<Profile?> getProfile() async {
    final response = await _client.from('profiles').select().eq('user_id', _uid).maybeSingle();
    if (response == null) return null;
    return Profile.fromJson(response);
  }

  @override
  Future<void> updateProfile(Profile profile) async {
    await _client.from('profiles').upsert(profile.toJson());
  }

  // ── Contact Types ────────────────────────────────────────────────────────────
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

  @override
  Future<void> deleteContactType(String id) async {
    final count = await _client.from('contacts').select('id').eq('contact_type_id', id).count(CountOption.exact);
    if (count.count > 0) {
      throw DependencyException(
        'Bu cari türüne bağlı ${count.count} cari var. Önce carilerin türünü değiştirin veya silin.',
      );
    }
    await _client.from('contact_types').delete().eq('id', id);
  }

  // ── Contacts ───────────────────────────────────────────────────────────────
  @override
  Future<List<Contact>> getContacts([String? typeId]) async {
    var query = _client.from('contacts').select('*, contact_types(*)');
    if (typeId != null && typeId.isNotEmpty) {
      query = query.eq('contact_type_id', typeId);
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
    await _client.from('contacts').update(contact.toJson()).eq('id', contact.id);
  }

  @override
  Future<void> deleteContact(String id) async {
    // İşlem kaydı var mı?
    final trxCount = await _client.from('transactions').select('id').eq('contact_id', id).count(CountOption.exact);
    if (trxCount.count > 0) {
      throw DependencyException(
        'Bu cariye bağlı ${trxCount.count} işlem kaydı var. Önce bu işlemleri silin veya başka bir cariye aktarın.',
      );
    }
    // Proje yatırımcısı olarak eklenmiş mi?
    final piCount = await _client.from('project_investors').select('id').eq('contact_id', id).count(CountOption.exact);
    if (piCount.count > 0) {
      throw DependencyException(
        'Bu cari ${piCount.count} projede yatırımcı olarak kayıtlı. Önce proje yatırımcı kayıtlarını kaldırın.',
      );
    }
    await _client.from('contacts').delete().eq('id', id);
  }

  // ── Accounts ───────────────────────────────────────────────────────────────
  @override
  Future<List<Account>> getAccounts() async {
    // Güncel bakiye (current_balance) account_balances view'inden geliyor:
    // opening_balance + ledger_entries üzerinden SUM(debit) - SUM(credit).
    // Bkz. supabase/migrations/20260708120000_account_balances_view.sql
    final data = await _client.from('account_balances').select().order('name');
    return (data as List).map((json) => Account.fromJson(json)).toList();
  }

  @override
  Future<void> addAccount(Account account) async {
    await _client.from('accounts').insert({
      ...account.toJson(),
      'user_id': _uid,
    });
  }

  @override
  Future<void> updateAccount(Account account) async {
    // Para birimi değişikliği koruması: hesapta ledger hareketi varken para
    // birimi değiştirilirse mevcut tüm hareketler yeni birimde "yeniden
    // yorumlanır" ve bakiye anlamsızlaşır (ledger satırlarında para birimi
    // tutulmuyor, hesabınki geçerli). Bu yüzden hareketi olan hesabın para
    // birimi değiştirilemez.
    final existing = await _client
        .from('accounts')
        .select('currency')
        .eq('id', account.id)
        .maybeSingle();
    if (existing != null && existing['currency'] != account.currency) {
      final leCount = await _client
          .from('ledger_entries')
          .select('id')
          .eq('account_id', account.id)
          .count(CountOption.exact);
      if (leCount.count > 0) {
        throw DependencyException(
          'Bu hesapta ${leCount.count} muhasebe hareketi var; para birimi değiştirilemez. '
          'Gerekirse yeni para biriminde ayrı bir hesap açın.',
        );
      }
    }
    await _client.from('accounts').update(account.toJson()).eq('id', account.id);
  }

  @override
  Future<void> deleteAccount(String id) async {
    // Bu hesabı kullanan ledger_entries var mı?
    final leCount = await _client.from('ledger_entries').select('id').eq('account_id', id).count(CountOption.exact);
    if (leCount.count > 0) {
      throw DependencyException(
        'Bu kasada/hesapta ${leCount.count} muhasebe hareketi var. Hesap silinemez — önce bağlı işlemleri silin.',
      );
    }
    // Doğrudan transactions tablosunda referans var mı? (account_id veya to_account_id)
    final trxFrom = await _client.from('transactions').select('id').eq('account_id', id).count(CountOption.exact);
    final trxTo = await _client.from('transactions').select('id').eq('to_account_id', id).count(CountOption.exact);
    final totalTrx = trxFrom.count + trxTo.count;
    if (totalTrx > 0) {
      throw DependencyException(
        'Bu hesaba bağlı $totalTrx işlem var. Hesap silinemez — önce bağlı işlemleri silin.',
      );
    }
    await _client.from('accounts').delete().eq('id', id);
  }

  // ── Profit Centers ─────────────────────────────────────────────────────────
  @override
  Future<List<ProfitCenter>> getProfitCenters() async {
    final data = await _client.from('profit_centers').select().order('name');
    return (data as List).map((json) => ProfitCenter.fromJson(json)).toList();
  }

  @override
  Future<void> addProfitCenter(ProfitCenter profitCenter) async {
    await _client.from('profit_centers').insert({
      ...profitCenter.toJson(),
      'user_id': _uid,
    });
  }

  @override
  Future<void> updateProfitCenter(ProfitCenter profitCenter) async {
    await _client.from('profit_centers').update(profitCenter.toJson()).eq('id', profitCenter.id);
  }

  @override
  Future<void> deleteProfitCenter(String id) async {
    // Kar merkezine bağlı proje var mı?
    final projectCount =
        await _client.from('projects').select('id').eq('profit_center_id', id).count(CountOption.exact);
    if (projectCount.count > 0) {
      throw DependencyException(
        'Bu kar merkezine bağlı ${projectCount.count} proje var. Önce projeleri silin veya başka bir kar merkezine taşıyın.',
      );
    }
    await _client.from('profit_centers').delete().eq('id', id);
  }

  // ── Projects ───────────────────────────────────────────────────────────────
  @override
  Future<List<Project>> getProjects({String? profitCenterId}) async {
    var query = _client.from('projects').select('*, profit_centers(*)');
    if (profitCenterId != null) {
      query = query.eq('profit_center_id', profitCenterId);
    }
    final data = await query.order('name');
    return (data as List).map((json) => Project.fromJson(json)).toList();
  }

  @override
  Future<void> addProject(Project project) async {
    await _client.from('projects').insert({
      ...project.toJson(),
      'user_id': _uid,
    });
  }

  @override
  Future<void> updateProject(Project project) async {
    await _client.from('projects').update(project.toJson()).eq('id', project.id);
  }

  @override
  Future<void> deleteProject(String id) async {
    // Projeye bağlı arsa var mı?
    final landCount = await _client.from('lands').select('id').eq('project_id', id).count(CountOption.exact);
    if (landCount.count > 0) {
      throw DependencyException(
        'Bu projeye bağlı ${landCount.count} arsa var. Önce arsaları silin veya başka bir projeye taşıyın.',
      );
    }
    // Projeye kayıtlı yatırımcı var mı?
    final invCount = await _client.from('project_investors').select('id').eq('project_id', id).count(CountOption.exact);
    if (invCount.count > 0) {
      throw DependencyException(
        'Bu projede ${invCount.count} yatırımcı kayıtlı. Önce yatırımcıları çıkarın.',
      );
    }
    // Projeye bağlı işlem var mı?
    final trxCount = await _client.from('transactions').select('id').eq('project_id', id).count(CountOption.exact);
    if (trxCount.count > 0) {
      throw DependencyException(
        'Bu projeye bağlı ${trxCount.count} işlem kaydı var. Önce bu işlemleri silin veya başka bir projeye aktarın.',
      );
    }
    await _client.from('projects').delete().eq('id', id);
  }

  // ── Lands ──────────────────────────────────────────────────────────────────
  @override
  Future<List<Land>> getLands({String? projectId}) async {
    var query = _client.from('lands').select('*, projects(*)');
    if (projectId != null) {
      query = query.eq('project_id', projectId);
    }
    final data = await query.order('title');
    return (data as List).map((json) => Land.fromJson(json)).toList();
  }

  @override
  Future<void> addLand(Land land) async {
    await _client.from('lands').insert({
      ...land.toJson(),
      'user_id': _uid,
    });
  }

  @override
  Future<void> updateLand(Land land) async {
    await _client.from('lands').update(land.toJson()).eq('id', land.id);
  }

  @override
  Future<void> deleteLand(String id) async {
    // Satış kaydı var mı? (CASCADE ile sessizce silinmesin -- bilinçli karar olsun)
    final saleCount = await _client.from('land_sales').select('id').eq('land_id', id).count(CountOption.exact);
    if (saleCount.count > 0) {
      throw DependencyException(
        'Bu arsanın satış kaydı var. Önce satış kaydını silin.',
      );
    }
    // Arsaya bağlı işlem var mı?
    final trxCount = await _client.from('transactions').select('id').eq('land_id', id).count(CountOption.exact);
    if (trxCount.count > 0) {
      throw DependencyException(
        'Bu arsaya bağlı ${trxCount.count} işlem kaydı var. Önce bu işlemleri silin.',
      );
    }
    await _client.from('lands').delete().eq('id', id);
  }

  // ── Project Investors ──────────────────────────────────────────────────────
  @override
  Future<List<ProjectInvestor>> getProjectInvestors(String projectId) async {
    // Yatırımcı + tüm sermaye ödemeleri tek sorguda: toplam TL/USD, model
    // getter'larından (totalCapitalTry/totalCapitalUsd) hesaplanır.
    final data = await _client
        .from('project_investors')
        .select('*, contacts(*), project_investments(*)')
        .eq('project_id', projectId);
    return (data as List).map((json) => ProjectInvestor.fromJson(json)).toList();
  }

  @override
  Future<void> addProjectInvestor(ProjectInvestor investor) async {
    await _client.from('project_investors').insert(investor.toJson());
  }

  @override
  Future<void> updateProjectInvestor(ProjectInvestor investor) async {
    await _client.from('project_investors').update(investor.toJson()).eq('id', investor.id);
  }

  @override
  Future<void> deleteProjectInvestor(String id) async {
    // Bu yatırımcıya satış dağıtımı yapılmış mı? (DB'de FK RESTRICT de var;
    // burada kullanıcıya anlaşılır mesaj vermek için önden kontrol ediyoruz.)
    final distCount = await _client
        .from('land_sale_distributions')
        .select('id')
        .eq('project_investor_id', id)
        .count(CountOption.exact);
    if (distCount.count > 0) {
      throw DependencyException(
        'Bu yatırımcıya satış dağıtımı yapılmış. Önce ilgili satış kayıtlarını silin.',
      );
    }
    await _client.from('project_investors').delete().eq('id', id);
  }

  // ── Project Investments (Sermaye Ödemeleri) ────────────────────────────────
  // Ödeme değişince projenin satış dağıtımlarını DB trigger'ı otomatik
  // yeniden hesaplar -- burada ek bir şey yapılmaz.
  @override
  Future<void> addProjectInvestment(ProjectInvestment investment) async {
    await _client.from('project_investments').insert(investment.toJson());
  }

  @override
  Future<void> updateProjectInvestment(ProjectInvestment investment) async {
    await _client.from('project_investments').update(investment.toJson()).eq('id', investment.id);
  }

  @override
  Future<void> deleteProjectInvestment(String id) async {
    await _client.from('project_investments').delete().eq('id', id);
  }

  // ── Land Sales (Arsa Satışı) ───────────────────────────────────────────────
  @override
  Future<LandSale?> getLandSale(String landId) async {
    final data = await _client
        .from('land_sales')
        .select('*, contacts(*), land_sale_distributions(*, project_investors(*, contacts(*)))')
        .eq('land_id', landId)
        .maybeSingle();
    if (data == null) return null;
    return LandSale.fromJson(data);
  }

  @override
  Future<void> createLandSale(LandSale sale, {required String accountId}) async {
    // Satış + kasa girişi TEK Postgres transaction'ında (RPC). Dağıtım
    // satırlarını ve arsa durumunu DB trigger'ları halleder.
    // Bkz. supabase/migrations/20260709140000_purchase_sale_cash.sql
    await _client.rpc('create_land_sale_with_cash', params: {
      'p_land_id': sale.landId,
      'p_sale_price_try': sale.salePriceTry,
      'p_usd_rate': sale.usdRate,
      'p_owner_profit_pct': sale.ownerProfitPct,
      'p_sale_date': sale.saleDate.toIso8601String().split('T').first,
      'p_buyer_contact_id': sale.buyerContactId,
      'p_account_id': accountId,
      'p_description': sale.description,
    });
  }

  @override
  Future<void> deleteLandSale(String id) async {
    // ON DELETE CASCADE ile dağıtım satırları, trigger'larla bağlı kasa
    // işlemi silinir ve arsa durumu 'purchased'a döner.
    await _client.from('land_sales').delete().eq('id', id);
  }

  @override
  Future<Map<String, double>> getInvestorSaleDebts() async {
    final data = await _client.from('investor_sale_debts').select();
    return {
      for (final row in data as List)
        row['contact_id'] as String: (row['total_debt_try'] as num).toDouble(),
    };
  }

  // ── Categories ─────────────────────────────────────────────────────────────
  @override
  Future<List<Category>> getCategories() async {
    final data = await _client.from('categories').select().order('name');
    final allCats = (data as List).map((json) => Category.fromJson(json)).toList();
    return allCats;
  }

  @override
  Future<void> addCategory(Category category) async {
    await _client.from('categories').insert({
      ...category.toJson(),
      'user_id': _uid,
    });
  }

  @override
  Future<void> updateCategory(Category category) async {
    await _client.from('categories').update(category.toJson()).eq('id', category.id);
  }

  @override
  Future<void> deleteCategory(String id) async {
    // Alt kategorisi var mı?
    final childCount = await _client.from('categories').select('id').eq('parent_id', id).count(CountOption.exact);
    if (childCount.count > 0) {
      throw DependencyException(
        'Bu kategoriye bağlı ${childCount.count} alt kategori var. Önce alt kategorileri silin.',
      );
    }
    // İşlemde kullanılıyor mu?
    final trxCount = await _client.from('transactions').select('id').eq('category_id', id).count(CountOption.exact);
    if (trxCount.count > 0) {
      throw DependencyException(
        'Bu kategori ${trxCount.count} işlemde kullanılıyor. Önce bu işlemlerin kategorisini değiştirin.',
      );
    }
    await _client.from('categories').delete().eq('id', id);
  }

  // ── Transactions ───────────────────────────────────────────────────────────
  @override
  Future<List<TransactionModel>> getTransactions({
    String? accountId,
    String? projectId,
    String? landId,
    String? contactId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client.from('transactions').select('''
      *,
      projects(*),
      lands(*),
      contacts(*),
      from_account:accounts!transactions_account_id_fkey(*),
      to_account:accounts!transactions_to_account_id_fkey(*),
      categories(*)
    ''');

    if (accountId != null) query = query.eq('account_id', accountId);
    if (projectId != null) query = query.eq('project_id', projectId);
    if (landId != null) query = query.eq('land_id', landId);
    if (contactId != null) query = query.eq('contact_id', contactId);
    if (startDate != null) query = query.gte('transaction_date', startDate.toIso8601String());
    if (endDate != null) query = query.lte('transaction_date', endDate.toIso8601String());

    final response = await query.order('transaction_date', ascending: false);
    return (response as List).map((json) => TransactionModel.fromJson(json)).toList();
  }

  /// RPC'nin beklediği ledger listesi: [{account_id, entry_type, amount}]
  static List<Map<String, dynamic>> _ledgersToRpcJson(List<LedgerEntry> ledgers) {
    return ledgers
        .map((l) => {
              'account_id': l.accountId,
              'entry_type': l.entryType,
              'amount': l.amount,
            })
        .toList();
  }

  /// İşlem alanlarını RPC parametrelerine çevirir. Tüm opsiyonel alanlar
  /// açıkça gönderilir (null dahil) -- böylece güncellemede temizlenen bir
  /// alan (örn. silinen açıklama) DB'de de gerçekten NULL olur.
  static Map<String, dynamic> _transactionToRpcParams(TransactionModel tr) {
    return {
      'p_transaction_type': tr.transactionType.value,
      'p_amount': tr.amount,
      'p_currency': tr.currency,
      'p_exchange_rate': tr.exchangeRate,
      'p_transaction_date': tr.transactionDate.toIso8601String(),
      'p_description': tr.description,
      'p_project_id': tr.projectId,
      'p_land_id': tr.landId,
      'p_contact_id': tr.contactId,
      'p_account_id': tr.accountId,
      'p_to_account_id': tr.toAccountId,
      'p_category_id': tr.categoryId,
    };
  }

  @override
  Future<void> addTransaction(TransactionModel transaction, List<LedgerEntry> ledgers) async {
    // transactions + ledger_entries TEK Postgres transaction'ında yazılır
    // (bkz. supabase/migrations/20260709100000_atomic_transaction_rpc.sql).
    // Herhangi bir adım hata verirse tamamı geri alınır -- yarım işlem
    // (ledger'sız kayıt) oluşamaz. user_id fonksiyon içinde auth.uid()'den
    // atanır, istemciden gönderilmez.
    await _client.rpc('create_transaction_with_ledgers', params: {
      ..._transactionToRpcParams(transaction),
      'p_ledgers': _ledgersToRpcJson(ledgers),
    });
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction, List<LedgerEntry> ledgers) async {
    // Güncelleme de atomik RPC ile: işlem alanları güncellenir, eski ledger
    // satırları silinip yenileri yazılır -- hepsi tek transaction'da. Sahiplik
    // fonksiyon içinde (user_id = auth.uid()) doğrulanır.
    await _client.rpc('update_transaction_with_ledgers', params: {
      'p_id': transaction.id,
      ..._transactionToRpcParams(transaction),
      'p_ledgers': _ledgersToRpcJson(ledgers),
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
    // ON DELETE CASCADE sayesinde ledger_entries de silinecektir.
    await _client.from('transactions').delete().eq('id', id);
  }

  @override
  Future<List<LedgerEntry>> getLedgerEntriesForAccount(String accountId) async {
    final data = await _client
        .from('ledger_entries')
        .select('*, transactions(*, projects(*), lands(*), contacts(*), categories(*))')
        .eq('account_id', accountId)
        .order('created_at', ascending: false);
    final entries = (data as List).map((json) => LedgerEntry.fromJson(json)).toList();
    // Ekstre, kayıt anına (created_at) göre değil İŞLEM TARİHİNE göre
    // sıralanmalı -- geçmişe dönük girilen bir işlem listede doğru yerde
    // görünsün. İşlem tarihi eşitse created_at ile kararlı sıralama yapılır.
    entries.sort((a, b) {
      final dateA = a.transaction?.transactionDate ?? a.createdAt ?? DateTime(1970);
      final dateB = b.transaction?.transactionDate ?? b.createdAt ?? DateTime(1970);
      final cmp = dateB.compareTo(dateA);
      if (cmp != 0) return cmp;
      return (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970));
    });
    return entries;
  }

  @override
  Future<List<LedgerEntry>> getLedgerEntriesForTransaction(String transactionId) async {
    final data = await _client.from('ledger_entries').select('*, accounts(*)').eq('transaction_id', transactionId);
    return (data as List).map((json) => LedgerEntry.fromJson(json)).toList();
  }
}
