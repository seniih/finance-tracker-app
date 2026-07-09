import 'package:flutter/material.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/form_section_card.dart';
import '../../../utils/constants.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/form_helpers.dart';
import '../../../utils/number_input_formatter.dart';
import '../../../utils/currency_formatter.dart';
import '../../../services/database_service.dart';
import '../../../services/supabase_database_service.dart';
import '../../../models/account.dart';
import '../../../models/category.dart';
import '../../../models/contact.dart';
import '../../../models/transaction.dart';
import '../../../models/ledger_entry.dart';

/// Gider / Gelir ekleme formu.
///
/// [fixedType] verilirse form o tipe kilitlenir: başlık "Gider Ekle" /
/// "Gelir Ekle" olur ve kategori listesi yalnızca o tipteki kategorileri
/// gösterir (sidebar'daki "Gider Ekle" ve "Gelir Ekle" girişleri bunu kullanır).
///
/// [existingTransaction] verilirse form düzenleme modunda açılır;
/// [existingLedgers] o işlemin hangi hesabı kullandığını geri yüklemek için
/// kullanılır (transactions.account_id her zaman dolu olmadığından, hesap
/// bilgisi ledger_entries üzerinden geliyor).
class TransactionForm extends StatefulWidget {
  final CategoryType? fixedType;

  /// true ise form "Ödeme" (gider + cari) veya "Tahsilat" (gelir + cari)
  /// modunda çalışır: cari seçimi gösterilir ve zorunludur.
  final bool withContact;

  final TransactionModel? existingTransaction;
  final List<LedgerEntry>? existingLedgers;

  const TransactionForm({
    super.key,
    this.fixedType,
    this.withContact = false,
    this.existingTransaction,
    this.existingLedgers,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final DatabaseService _db = SupabaseDatabaseService();
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.existingTransaction != null;

  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  // Kayıt sonrası formu sıfırlamak için: artınca form alt ağacı yeniden
  // kurulur ve dropdown'lar initialValue'larına döner.
  int _formGeneration = 0;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<Contact> _contacts = [];

  String? _currency;
  String? _selectedAccountId;
  String? _selectedCategoryId;

  // Ödeme/Tahsilat modunda kullanıcı tarafından seçilir; diğer modlarda
  // yalnızca düzenlenen işlemin mevcut cari bağlantısını taşır.
  String? _selectedContactId;

  // İlişkili kayıtlar (proje/arsa) formdan kaldırıldı; düzenleme modunda
  // mevcut işlemin bağlantıları kaybolmasın diye saklanıp geri yazılıyor.
  String? _existingProjectId;
  String? _existingLandId;

  Account? get _selectedAccount {
    if (_selectedAccountId == null) return null;
    for (final a in _accounts) {
      if (a.id == _selectedAccountId) return a;
    }
    return null;
  }

  Category? get _selectedCategory {
    if (_selectedCategoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _selectedCategoryId) return c;
    }
    return null;
  }

  /// Formun geçerli tipi: sabitlenmişse o, değilse seçili kategorinin tipi.
  CategoryType? get _type => widget.fixedType ?? _selectedCategory?.type;

  bool? get _isIncome {
    final t = _type;
    if (t == null) return null;
    return t == CategoryType.income;
  }

  Color get _accentColor {
    final isIncome = _isIncome;
    if (isIncome == null) return AppColors.primary;
    return isIncome ? AppColors.success : AppColors.error;
  }

  String get _title {
    if (_isEditing) return 'İşlemi Düzenle';
    if (widget.withContact) {
      return widget.fixedType == CategoryType.income ? 'Tahsilat' : 'Ödeme';
    }
    return switch (widget.fixedType) {
      CategoryType.income => 'Gelir Ekle',
      CategoryType.expense => 'Gider Ekle',
      null => 'Yeni İşlem',
    };
  }

  IconData get _titleIcon {
    if (widget.withContact) {
      return widget.fixedType == CategoryType.income ? Icons.call_received : Icons.call_made;
    }
    return switch (widget.fixedType) {
      CategoryType.income => Icons.trending_up,
      CategoryType.expense => Icons.trending_down,
      null => Icons.receipt_long_outlined,
    };
  }

  String get _saveLabel {
    if (_isEditing) return 'Değişiklikleri Kaydet';
    if (widget.withContact) {
      return widget.fixedType == CategoryType.income ? 'Tahsilatı Kaydet' : 'Ödemeyi Kaydet';
    }
    final isIncome = _isIncome;
    if (isIncome == null) return 'İşlemi Kaydet';
    return isIncome ? 'Geliri Kaydet' : 'Gideri Kaydet';
  }

  IconData get _saveIcon {
    if (_isEditing) return Icons.check_circle_outline;
    final isIncome = _isIncome;
    if (isIncome == null) return Icons.save_outlined;
    return isIncome ? Icons.trending_up : Icons.trending_down;
  }

  @override
  void initState() {
    super.initState();
    final tr = widget.existingTransaction;
    if (tr != null) {
      _selectedDate = tr.transactionDate;
      _currency = tr.currency;
      _amountController.text = _amountToInput(tr.amount);
      _descriptionController.text = tr.description ?? '';
      _selectedCategoryId = tr.categoryId;
      _selectedContactId = tr.contactId;
      _existingProjectId = tr.projectId;
      _existingLandId = tr.landId;
      final ledgers = widget.existingLedgers;
      if (ledgers != null && ledgers.isNotEmpty) {
        _selectedAccountId = ledgers.first.accountId;
      }
    }
    _loadData();
  }

  String _amountToInput(double v) => formatNumberForInput(v);

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getAccounts();
      final categories = await _db.getCategories();
      final contacts = widget.withContact ? await _db.getContacts() : <Contact>[];

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _categories = categories;
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  /// Formda gösterilecek kategoriler: tip sabitse yalnızca o tip.
  List<Category> _visibleCategories() {
    final fixed = widget.fixedType;
    if (fixed == null) return _categories;
    return _categories.where((c) => c.type == fixed).toList();
  }

  /// Alt kategorileri, ebeveynlerinin hemen altında (girintili) göstermek
  /// için kategorileri hiyerarşik sıraya diziyor.
  List<Category> _orderedCategories() {
    final source = _visibleCategories();
    final parents = source.where((c) => c.parentId == null).toList()..sort((a, b) => a.name.compareTo(b.name));
    final ordered = <Category>[];
    for (final p in parents) {
      ordered.add(p);
      final children = source.where((c) => c.parentId == p.id).toList()..sort((a, b) => a.name.compareTo(b.name));
      ordered.addAll(children);
    }
    for (final c in source) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    return ordered;
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _onAccountChanged(String? accountId) {
    setState(() {
      _selectedAccountId = accountId;
      // Hesap seçilince para birimi hesabınkinden otomatik gelir.
      final account = _selectedAccount;
      if (account != null) _currency = account.currency;
    });
  }

  /// Sidebar'dan (route içine gömülü) kullanılırken kayıt sonrası formu
  /// sıfırlar; hesap/para birimi/tarih, art arda giriş kolay olsun diye korunur.
  void _resetForm() {
    _amountController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategoryId = null;
      if (widget.withContact) _selectedContactId = null;
      _formGeneration++;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir hesap/kasa seçin.')));
      return;
    }
    if (widget.withContact && _selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir cari seçin.')));
      return;
    }
    final category = _selectedCategory;
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir kategori seçin.')));
      return;
    }
    if (_currency == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir para birimi seçin.')));
      return;
    }
    // Para birimi hesabınkiyle aynı olmak ZORUNDA: hesap bakiyesi ledger
    // tutarlarının toplamından hesaplandığı için (para birimi ledger'da
    // tutulmaz) farklı birimde kayıt bakiyeyi sessizce bozar. Aynı kural
    // DB'de de denetleniyor (atomic_transaction_rpc migration'ı).
    final account = _selectedAccount;
    if (account != null && _currency != account.currency) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Para birimi (${CurrencyFormatter.getLabel(_currency!)}) seçilen hesabın para birimiyle '
          '(${CurrencyFormatter.getLabel(account.currency)}) aynı olmalı.',
        ),
      ));
      return;
    }

    final amount = parseFormattedNumber(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir tutar girin.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isIncome = category.type == CategoryType.income;

      final transaction = TransactionModel(
        id: _isEditing ? widget.existingTransaction!.id : '',
        userId: '',
        transactionType: TransactionType.standard,
        projectId: _existingProjectId,
        landId: _existingLandId,
        contactId: _selectedContactId,
        // Hesap bilgisi asıl olarak ledger'da tutulur; account_id'yi işlem
        // satırına da yazmak raporlama/filtreleme sorgularını kolaylaştırır.
        accountId: _selectedAccountId,
        categoryId: _selectedCategoryId,
        amount: amount,
        currency: _currency!,
        exchangeRate: 1.0,
        transactionDate: _selectedDate,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        createdAt: DateTime.now(),
      );

      final ledgers = [
        LedgerEntry(
          id: '',
          transactionId: '',
          accountId: _selectedAccountId,
          // Gelir -> hesaba para girer (debit), Gider -> hesaptan para çıkar (credit).
          entryType: isIncome ? 'debit' : 'credit',
          amount: amount,
        ),
      ];

      if (_isEditing) {
        await _db.updateTransaction(transaction, ledgers);
      } else {
        await _db.addTransaction(transaction, ledgers);
      }

      if (mounted) {
        final navigator = Navigator.of(context);
        setState(() => _isLoading = false);
        if (navigator.canPop()) {
          // Ayrı sayfa olarak açıldıysa (düzenleme vb.) geri dön.
          navigator.pop(true);
        } else {
          // Sidebar route'una gömülüyse pop edilecek sayfa yok --
          // pop çağırmak uygulamanın tek route'unu kapatıp hata üretir.
          _resetForm();
        }
        final String successText;
        if (_isEditing) {
          successText = 'İşlem güncellendi!';
        } else if (widget.withContact) {
          successText = isIncome ? 'Tahsilat başarıyla kaydedildi!' : 'Ödeme başarıyla kaydedildi!';
        } else {
          successText = isIncome ? 'Gelir işlemi başarıyla eklendi!' : 'Gider işlemi başarıyla eklendi!';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successText)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt Hatası: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: _title, icon: _titleIcon),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: _isLoading,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: KeyedSubtree(
                      key: ValueKey(_formGeneration),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1) Önce hesap, sonra kategori.
                        FormSectionCard(
                          title: widget.withContact ? 'Hesap, Cari & Kategori' : 'Hesap & Kategori',
                          icon: Icons.account_balance_wallet_outlined,
                          trailing: _isIncome == null
                              ? null
                              : InlineTypeBadge(
                                  label: _isIncome! ? 'Gelir' : 'Gider',
                                  color: _accentColor,
                                  icon: _isIncome! ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                ),
                          children: [
                            DropdownButtonFormField<String>(
                              decoration: buildInputDecoration('Hesap / Kasa'),
                              initialValue: _selectedAccountId,
                              hint: const Text('Önce hesap seçin'),
                              isExpanded: true,
                              items: _accounts.map((a) {
                                final bal = a.currentBalance ?? a.openingBalance;
                                return DropdownMenuItem(
                                  value: a.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        switch (a.accountType) {
                                          AccountType.cash => Icons.payments_outlined,
                                          AccountType.bank => Icons.account_balance_outlined,
                                          AccountType.creditCard => Icons.credit_card_outlined,
                                        },
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        CurrencyFormatter.format(bal, currency: a.currency),
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: _onAccountChanged,
                              validator: (val) => val == null ? 'Lütfen bir hesap/kasa seçin.' : null,
                            ),
                            if (widget.withContact)
                              DropdownButtonFormField<String>(
                                decoration: buildInputDecoration('Cari'),
                                initialValue: _selectedContactId,
                                hint: Text(
                                  widget.fixedType == CategoryType.income
                                      ? 'Tahsilat yapılacak cariyi seçin'
                                      : 'Ödeme yapılacak cariyi seçin',
                                ),
                                isExpanded: true,
                                items: _contacts.map((c) {
                                  return DropdownMenuItem(
                                    value: c.id,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                                        const SizedBox(width: 8),
                                        Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedContactId = val),
                                validator: (val) => val == null ? 'Lütfen bir cari seçin.' : null,
                              ),
                            DropdownButtonFormField<String>(
                              decoration: buildInputDecoration('Kategori'),
                              initialValue: _selectedCategoryId,
                              hint: const Text('Seçiniz'),
                              isExpanded: true,
                              items: _orderedCategories().map((c) {
                                final isChild = c.parentId != null;
                                final dotColor = c.type == CategoryType.income ? AppColors.success : AppColors.error;
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isChild) ...[
                                        const SizedBox(width: 16),
                                        const Icon(Icons.subdirectory_arrow_right, size: 14, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                      ],
                                      Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          c.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isChild ? AppColors.textSecondary : AppColors.textPrimary,
                                            fontWeight: isChild ? FontWeight.normal : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedCategoryId = val),
                              validator: (val) => val == null ? 'Lütfen bir kategori seçin.' : null,
                            ),
                          ],
                        ),
                        // 2) Tutar, tarih ve para birimi.
                        FormSectionCard(
                          title: 'İşlem Bilgileri',
                          icon: Icons.event_note_outlined,
                          children: [
                            TextFormField(
                              controller: _amountController,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              decoration: buildInputDecoration(
                                'Tutar',
                                prefixIcon: const Icon(Icons.payments, color: AppColors.textSecondary),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [ThousandSeparatorInputFormatter()],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Tutar giriniz';
                                final n = parseFormattedNumber(val);
                                if (n == null || n <= 0) return 'Geçerli bir tutar girin';
                                return null;
                              },
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectDate(context),
                                    child: InputDecorator(
                                      decoration: buildInputDecoration('Tarih'),
                                      child: Text('${_selectedDate.toLocal()}'.split(' ')[0]),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(_currency),
                                    decoration: buildInputDecoration('Para Birimi'),
                                    initialValue: _currency,
                                    hint: const Text('Seçiniz'),
                                    items: appCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                    onChanged: (val) => setState(() => _currency = val),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // 3) Açıklama.
                        FormSectionCard(
                          title: 'Açıklama',
                          icon: Icons.notes_outlined,
                          children: [
                            TextFormField(
                              controller: _descriptionController,
                              decoration: buildInputDecoration('Açıklama (Opsiyonel)'),
                              maxLines: 3,
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Icon(_saveIcon),
                          label: Text(_saveLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: _isLoading ? null : _save,
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(color: AppColors.primary, backgroundColor: Colors.transparent, minHeight: 3),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
