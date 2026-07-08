import 'package:flutter/material.dart';
import '../../../utils/constants.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/form_helpers.dart';
import '../../../utils/number_input_formatter.dart';
import '../../../utils/currency_formatter.dart';
import '../../../services/database_service.dart';
import '../../../services/supabase_database_service.dart';
import '../../../models/account.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/form_section_card.dart';
import '../../../models/transaction.dart';
import '../../../models/ledger_entry.dart';

/// Hesaplar arası transfer formu.
///
/// Akış: önce kaynak hesap seçilir; para birimi kaynaktan otomatik alınır ve
/// hedef hesap listesi aynı para birimindeki hesaplarla sınırlanır (farklı
/// para birimleri arasında transfer desteklenmiyor).
class TransferForm extends StatefulWidget {
  final TransactionModel? existingTransaction;
  final List<LedgerEntry>? existingLedgers;

  const TransferForm({super.key, this.existingTransaction, this.existingLedgers});

  @override
  State<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<TransferForm> {
  final DatabaseService _db = SupabaseDatabaseService();
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.existingTransaction != null;

  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  String? _currency;

  // Kayıt sonrası formu sıfırlamak için (bkz. TransactionForm._formGeneration).
  int _formGeneration = 0;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Account> _accounts = [];
  String? _selectedAccountId; // Kaynak Hesap
  String? _selectedToAccountId; // Hedef Hesap

  Account? _accountById(String? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final tr = widget.existingTransaction;
    if (tr != null) {
      _selectedDate = tr.transactionDate;
      _currency = tr.currency;
      _amountController.text = formatNumberForInput(tr.amount);
      _descriptionController.text = tr.description ?? '';
      for (final l in widget.existingLedgers ?? const <LedgerEntry>[]) {
        if (l.entryType == 'credit') _selectedAccountId = l.accountId; // kaynak (çıkış)
        if (l.entryType == 'debit') _selectedToAccountId = l.accountId; // hedef (giriş)
      }
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
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

  void _onSourceChanged(String? val) {
    setState(() {
      _selectedAccountId = val;
      final source = _accountById(val);
      if (source != null) {
        // Para birimi kaynaktan gelir; hedef farklı para birimindeyse temizlenir.
        _currency = source.currency;
        final target = _accountById(_selectedToAccountId);
        if (target != null && target.currency != source.currency) {
          _selectedToAccountId = null;
        }
        // Kaynak ve hedef aynı olamaz.
        if (_selectedToAccountId == val) _selectedToAccountId = null;
      }
    });
  }

  void _swapAccounts() {
    if (_selectedAccountId == null && _selectedToAccountId == null) return;
    setState(() {
      final tmp = _selectedAccountId;
      _selectedAccountId = _selectedToAccountId;
      _selectedToAccountId = tmp;
      _formGeneration++; // dropdown'ların iç durumunu yeni değerlerle kur
    });
  }

  void _resetForm() {
    _amountController.clear();
    _descriptionController.clear();
    setState(() => _formGeneration++);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen kaynak hesap seçin.')));
      return;
    }
    if (_selectedToAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen hedef hesap seçin.')));
      return;
    }
    if (_selectedAccountId == _selectedToAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaynak ve hedef hesap aynı olamaz.')));
      return;
    }
    if (_currency == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir para birimi seçin.')));
      return;
    }
    // Son kontrol: iki hesap da işlemin para biriminde olmalı. Dropdown zaten
    // filtreliyor ama düzenleme/swap gibi akışlarda tutarsız durum kalmasın
    // (bakiye ledger toplamından hesaplandığı için birim uyuşmazlığı bakiyeyi
    // bozar; aynı kural DB'de de denetleniyor).
    final source = _accountById(_selectedAccountId);
    final target = _accountById(_selectedToAccountId);
    if ((source != null && source.currency != _currency) ||
        (target != null && target.currency != _currency)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kaynak ve hedef hesap, transferin para birimiyle aynı olmalı.'),
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
        transactionType: TransactionType.transfer,
        // Kaynak/hedef asıl olarak ledger'da tutulur; işlem satırına da
        // yazmak raporlama/filtreleme sorgularını kolaylaştırır.
        accountId: _selectedAccountId,
        toAccountId: _selectedToAccountId,
        amount: amount,
        currency: _currency!,
        exchangeRate: 1.0,
        transactionDate: _selectedDate,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        createdAt: DateTime.now(),
      );

      final ledgers = [
        LedgerEntry(id: '', transactionId: '', accountId: _selectedAccountId, entryType: 'credit', amount: amount),
        LedgerEntry(id: '', transactionId: '', accountId: _selectedToAccountId, entryType: 'debit', amount: amount),
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
          navigator.pop(true);
        } else {
          // Sidebar route'una gömülü kullanılırken pop edilecek sayfa yok.
          _resetForm();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Transfer güncellendi!' : 'Transfer işlemi başarıyla eklendi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt Hatası: $e')));
      }
    }
  }

  IconData _accountIcon(AccountType type) {
    return switch (type) {
      AccountType.cash => Icons.payments_outlined,
      AccountType.bank => Icons.account_balance_outlined,
      AccountType.creditCard => Icons.credit_card_outlined,
    };
  }

  DropdownMenuItem<String> _accountItem(Account a) {
    final bal = a.currentBalance ?? a.openingBalance;
    return DropdownMenuItem(
      value: a.id,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_accountIcon(a.accountType), size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.format(bal, currency: a.currency),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Kaynak-hedef özeti: iki hesap da seçiliyse "A → B" şeklinde gösterilir.
  List<Widget> _buildTransferSummary() {
    final source = _accountById(_selectedAccountId);
    final target = _accountById(_selectedToAccountId);
    if (source == null || target == null) return [];
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                source.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.info),
            ),
            Flexible(
              child: Text(
                target.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final summary = _buildTransferSummary();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: _isEditing ? 'Transferi Düzenle' : 'Yeni Transfer', icon: Icons.swap_horiz),
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
                          // 1) Hesaplar: önce kaynak, sonra hedef.
                          FormSectionCard(
                            title: 'Hesaplar',
                            icon: Icons.compare_arrows_outlined,
                            trailing: _currency == null
                                ? null
                                : InlineTypeBadge(
                                    label: CurrencyFormatter.getLabel(_currency!),
                                    color: AppColors.info,
                                    icon: Icons.payments_outlined,
                                  ),
                            children: [
                              DropdownButtonFormField<String>(
                                decoration: buildInputDecoration('Kaynak Hesap (Para Çıkışı)'),
                                initialValue: _selectedAccountId,
                                hint: const Text('Önce kaynak hesabı seçin'),
                                isExpanded: true,
                                items: _accounts.map(_accountItem).toList(),
                                onChanged: _onSourceChanged,
                                validator: (val) => val == null ? 'Lütfen kaynak hesabı seçin.' : null,
                              ),
                              // Kaynak <-> hedef değiştirme düğmesi.
                              Center(
                                child: IconButton(
                                  tooltip: 'Hesapları Yer Değiştir',
                                  onPressed: _swapAccounts,
                                  icon: const Icon(Icons.swap_vert_rounded, color: AppColors.info),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.info.withValues(alpha: 0.08),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              DropdownButtonFormField<String>(
                                key: ValueKey('target_$_currency'),
                                decoration: buildInputDecoration('Hedef Hesap (Para Girişi)'),
                                initialValue: _selectedToAccountId,
                                hint: Text(
                                  _currency == null
                                      ? 'Önce kaynak hesabı seçin'
                                      : 'Aynı para birimindeki hesaplar (${CurrencyFormatter.getLabel(_currency!)})',
                                ),
                                isExpanded: true,
                                items: _accounts
                                    .where((a) => _currency == null || a.currency == _currency)
                                    .where((a) => a.id != _selectedAccountId)
                                    .map(_accountItem)
                                    .toList(),
                                onChanged: (val) => setState(() => _selectedToAccountId = val),
                                validator: (val) {
                                  if (val == null) return 'Lütfen hedef hesabı seçin.';
                                  if (val == _selectedAccountId) return 'Kaynak ve hedef hesap aynı olamaz.';
                                  return null;
                                },
                              ),
                              ...summary,
                            ],
                          ),
                          // 2) Tutar ve tarih.
                          FormSectionCard(
                            title: 'İşlem Bilgileri',
                            icon: Icons.event_note_outlined,
                            children: [
                              TextFormField(
                                controller: _amountController,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                decoration: buildInputDecoration(
                                  'Tutar',
                                  prefixIcon: const Icon(Icons.attach_money, color: AppColors.textSecondary),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [ThousandSeparatorInputFormatter()],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Lütfen tutar girin.';
                                  final num = parseFormattedNumber(val);
                                  if (num == null || num <= 0) return 'Lütfen geçerli bir tutar girin.';
                                  return null;
                                },
                              ),
                              InkWell(
                                onTap: () => _selectDate(context),
                                child: InputDecorator(
                                  decoration: buildInputDecoration('Tarih'),
                                  child: Text('${_selectedDate.toLocal()}'.split(' ')[0]),
                                ),
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
                              backgroundColor: AppColors.info,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Icon(_isEditing ? Icons.check_circle_outline : Icons.swap_horiz),
                            label: Text(
                              _isEditing ? 'Değişiklikleri Kaydet' : 'Transferi Kaydet',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
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
              child: LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: Colors.transparent,
                minHeight: 3,
              ),
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
