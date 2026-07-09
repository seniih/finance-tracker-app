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
import '../../../models/contact.dart';
import '../../../models/project.dart';
import '../../../models/transaction.dart';
import '../../../models/ledger_entry.dart';

/// Alış formu: projeye yapılan HER TÜR harcama (arsa alımı, tapu, komisyon,
/// inşaat...). Kasadan çıkar (credit ledger) ve projenin toplam maliyetine
/// yazılır (maliyet = projenin 'purchase' işlemlerinin toplamı). Arsa
/// ayrımı bilinçli olarak yok -- tüm alışlar proje maliyetidir.
///
/// [fixedProject] verilirse (proje detayından açıldığında) proje kilitli
/// gösterilir; işlem geçmişinden düzenlemede seçilebilir dropdown olur.
class PurchaseForm extends StatefulWidget {
  final Project? fixedProject;
  final TransactionModel? existingTransaction;
  final List<LedgerEntry>? existingLedgers;

  const PurchaseForm({
    super.key,
    this.fixedProject,
    this.existingTransaction,
    this.existingLedgers,
  });

  @override
  State<PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<PurchaseForm> {
  final DatabaseService _db = SupabaseDatabaseService();
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.existingTransaction != null;
  bool get _isLocked => widget.fixedProject != null;

  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  String? _currency;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Account> _accounts = [];
  List<Contact> _contacts = [];
  List<Project> _projects = [];

  String? _selectedAccountId;
  String? _selectedContactId;
  String? _selectedProjectId;

  Account? get _selectedAccount {
    if (_selectedAccountId == null) return null;
    for (final a in _accounts) {
      if (a.id == _selectedAccountId) return a;
    }
    return null;
  }

  void _onAccountChanged(String? val) {
    setState(() {
      _selectedAccountId = val;
      // Para birimi hesabınkinden otomatik gelir (bakiye tutarlılığı için
      // işlem her zaman hesabın para biriminde kaydedilmeli).
      final account = _selectedAccount;
      if (account != null) _currency = account.currency;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.fixedProject != null) _selectedProjectId = widget.fixedProject!.id;

    final tr = widget.existingTransaction;
    if (tr != null) {
      _selectedDate = tr.transactionDate;
      _currency = tr.currency;
      _amountController.text = formatNumberForInput(tr.amount);
      _descriptionController.text = tr.description ?? '';
      _selectedContactId = tr.contactId;
      _selectedProjectId = tr.projectId ?? _selectedProjectId;
      final ledgers = widget.existingLedgers;
      if (ledgers != null && ledgers.isNotEmpty) {
        _selectedAccountId = ledgers.first.accountId;
      }
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getAccounts();
      final contacts = await _db.getContacts();
      final projects = _isLocked ? <Project>[] : await _db.getProjects();

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _contacts = contacts;
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  /// Sidebar'dan (route içine gömülü) kullanılırken kayıt sonrası formu
  /// sıfırlar; kasa/para birimi/tarih, art arda giriş kolay olsun diye korunur.
  void _resetForm() {
    _amountController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedContactId = null;
      if (!_isLocked) _selectedProjectId = null;
    });
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lütfen bir proje seçin -- alış proje maliyetine yazılır.')));
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir hesap/kasa seçin.')));
      return;
    }
    if (_currency == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir para birimi seçin.')));
      return;
    }
    // Para birimi hesabınkiyle aynı olmalı (bakiye bozulmasın; DB de denetler).
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
      final transaction = TransactionModel(
        id: _isEditing ? widget.existingTransaction!.id : '',
        userId: '',
        transactionType: TransactionType.purchase,
        projectId: _selectedProjectId,
        contactId: _selectedContactId,
        // Hesap bilgisi asıl olarak ledger'da; işlem satırına da yazılır.
        accountId: _selectedAccountId,
        amount: amount,
        currency: _currency!,
        exchangeRate: 1.0,
        transactionDate: _selectedDate,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Alış = kasadan para çıkışı (credit)
      final ledgers = [
        LedgerEntry(id: '', transactionId: '', accountId: _selectedAccountId, entryType: 'credit', amount: amount),
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
          // Ayrı sayfa olarak açıldıysa (proje detayı/düzenleme) geri dön.
          navigator.pop(true);
        } else {
          // Sidebar route'una gömülüyse pop edilecek sayfa yok.
          _resetForm();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Alış güncellendi!' : 'Alış kaydedildi, proje maliyetine eklendi.')),
        );
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
      appBar: CustomAppBar(title: _isEditing ? 'Alışı Düzenle' : 'Yeni Alış', icon: Icons.shopping_cart_outlined),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isLocked)
                      FormSectionCard(
                        title: 'Proje',
                        icon: Icons.business_outlined,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.business_outlined, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.fixedProject?.name ?? '—',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      FormSectionCard(
                        title: 'Proje',
                        icon: Icons.business_outlined,
                        children: [
                          DropdownButtonFormField<String>(
                            decoration: buildInputDecoration('Proje (Maliyetin Yazılacağı)'),
                            initialValue: _selectedProjectId,
                            hint: const Text('Seçiniz'),
                            items: _projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                            onChanged: (val) => setState(() => _selectedProjectId = val),
                            validator: (val) => val == null ? 'Lütfen bir proje seçin.' : null,
                          ),
                        ],
                      ),
                    FormSectionCard(
                      title: 'Alış Detayları',
                      icon: Icons.event_note_outlined,
                      children: [
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
                                decoration: buildInputDecoration('Para Birimi'),
                                initialValue: _currency,
                                hint: const Text('Seçiniz'),
                                items: appCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (val) => setState(() => _currency = val),
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: _amountController,
                          decoration: buildInputDecoration('Tutar', prefixIcon: const Icon(Icons.payments, color: AppColors.textSecondary)),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [ThousandSeparatorInputFormatter()],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Tutar giriniz';
                            final n = parseFormattedNumber(val);
                            if (n == null || n <= 0) return 'Geçerli bir tutar girin';
                            return null;
                          },
                        ),
                      ],
                    ),
                    FormSectionCard(
                      title: 'Kasa (Paranın Çıktığı Hesap)',
                      icon: Icons.account_balance_wallet_outlined,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: buildInputDecoration('Hesap / Kasa'),
                          initialValue: _selectedAccountId,
                          hint: const Text('Seçiniz'),
                          items: _accounts
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text('${a.name} (${CurrencyFormatter.getLabel(a.currency)})'),
                                  ))
                              .toList(),
                          onChanged: _onAccountChanged,
                          validator: (val) => val == null ? 'Lütfen bir hesap/kasa seçin.' : null,
                        ),
                      ],
                    ),
                    FormSectionCard(
                      title: 'Satıcı (Opsiyonel)',
                      icon: Icons.link,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: buildInputDecoration('Cari (Kimden Alındı)'),
                          initialValue: _selectedContactId,
                          hint: const Text('Seçiniz'),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Yok')),
                            ..._contacts.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedContactId = val),
                        ),
                      ],
                    ),
                    FormSectionCard(
                      title: 'Açıklama',
                      icon: Icons.notes_outlined,
                      children: [
                        TextFormField(
                          controller: _descriptionController,
                          decoration: buildInputDecoration('Açıklama (ör. tapu masrafı, arsa alımı...)'),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(_isEditing ? Icons.check_circle_outline : Icons.shopping_cart_outlined),
                  label: Text(
                    _isEditing ? 'Değişiklikleri Kaydet' : 'Alışı Kaydet',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  // Çift gönderim koruması: kayıt sürerken buton devre dışı.
                  onPressed: _isLoading ? null : _save,
                ),
              ),
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
