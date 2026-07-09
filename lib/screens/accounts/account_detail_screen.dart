import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../models/ledger_entry.dart';
import '../../utils/constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/number_input_formatter.dart';
import '../../utils/form_helpers.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../transactions/forms/transaction_form.dart';
import '../transactions/forms/transfer_form.dart';
import '../transactions/forms/investment_in_form.dart';
import '../transactions/forms/investment_out_form.dart';
import '../transactions/forms/purchase_form.dart';

/// Bir kasa/hesabın detay sayfası: güncel bakiye, hesabı düzenle/sil ve o
/// hesabı etkileyen tüm işlemlerin ekstresi (her satırda düzenle/sil).
///
/// Not: transactions.account_id her zaman dolu olmadığından (standart
/// gelir/gider işlemlerinde hesap bilgisi sadece ledger_entries'te tutulur),
/// bu ekran hesap hareketlerini ledger_entries üzerinden okur.
class AccountDetailScreen extends StatefulWidget {
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final DatabaseService _db = SupabaseDatabaseService();

  late Account _account = widget.account;
  bool _isLoading = true;
  bool _isFirstLoad = true;
  bool _wasChanged = false;
  List<LedgerEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _db.getAccounts(),
        _db.getLedgerEntriesForAccount(_account.id),
      ]);
      if (!mounted) return;
      final accounts = futures[0] as List<Account>;
      final match = accounts.where((a) => a.id == _account.id).toList();
      setState(() {
        if (match.isNotEmpty) _account = match.first;
        _entries = futures[1] as List<LedgerEntry>;
        _isLoading = false;
        _isFirstLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isFirstLoad = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  IconData _accountIcon(AccountType type) {
    return switch (type) {
      AccountType.cash => Icons.payments_outlined,
      AccountType.bank => Icons.account_balance_outlined,
      AccountType.creditCard => Icons.credit_card_outlined,
    };
  }

  Color _colorFor(LedgerEntry le) {
    final tr = le.transaction;
    if (tr == null) return AppColors.textSecondary;
    return switch (tr.transactionType) {
      TransactionType.standard => tr.category?.type == CategoryType.income ? AppColors.success : AppColors.error,
      TransactionType.transfer => AppColors.info,
      TransactionType.investmentIn => AppColors.investmentIn,
      TransactionType.investmentOut => AppColors.investmentOut,
      TransactionType.purchase => AppColors.error,
      TransactionType.sale => AppColors.success,
    };
  }

  IconData _iconFor(LedgerEntry le) {
    final tr = le.transaction;
    if (tr == null) return Icons.receipt_long_outlined;
    return switch (tr.transactionType) {
      TransactionType.standard => tr.category?.type == CategoryType.income ? Icons.trending_up : Icons.trending_down,
      TransactionType.transfer => le.entryType == 'debit' ? Icons.call_received : Icons.call_made,
      TransactionType.investmentIn => Icons.download,
      TransactionType.investmentOut => Icons.upload,
      TransactionType.purchase => Icons.shopping_cart_outlined,
      TransactionType.sale => Icons.sell_outlined,
    };
  }

  String _labelFor(LedgerEntry le) {
    final tr = le.transaction;
    if (tr == null) return 'İşlem';
    return switch (tr.transactionType) {
      TransactionType.standard => tr.category?.name ?? tr.transactionType.label,
      TransactionType.transfer => le.entryType == 'debit' ? 'Gelen Transfer' : 'Giden Transfer',
      TransactionType.investmentIn => 'Yatırım Girişi',
      TransactionType.investmentOut => 'Yatırım Çıkışı',
      TransactionType.purchase => 'Alış',
      TransactionType.sale => 'Satış',
    };
  }

  double _signedAmount(LedgerEntry le) => le.entryType == 'debit' ? le.amount : -le.amount;

  Future<void> _editEntry(LedgerEntry le) async {
    final tr = le.transaction;
    if (tr == null) return;
    List<LedgerEntry> ledgers;
    try {
      ledgers = await _db.getLedgerEntriesForTransaction(tr.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      return;
    }
    if (!mounted) return;

    // Satış işlemi land_sales kaydına bağlıdır; buradan düzenlenirse satış
    // kaydıyla tutarsızlaşır (arsa detayından satışı silip yeniden kaydedin).
    if (tr.transactionType == TransactionType.sale) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Satış işlemi buradan düzenlenemez. Arsa detayından satışı silip yeniden kaydedin.')));
      return;
    }

    final form = switch (tr.transactionType) {
      TransactionType.standard => TransactionForm(existingTransaction: tr, existingLedgers: ledgers),
      TransactionType.transfer => TransferForm(existingTransaction: tr, existingLedgers: ledgers),
      TransactionType.investmentIn => InvestmentInForm(existingTransaction: tr, existingLedgers: ledgers),
      TransactionType.investmentOut => InvestmentOutForm(existingTransaction: tr, existingLedgers: ledgers),
      TransactionType.purchase => PurchaseForm(existingTransaction: tr, existingLedgers: ledgers),
      // Yukarıda engellendi; switch'in eksiksiz olması için:
      TransactionType.sale => TransactionForm(existingTransaction: tr, existingLedgers: ledgers),
    };

    final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => form));
    if (changed == true) {
      _wasChanged = true;
      _loadData();
    }
  }

  Future<void> _deleteEntry(LedgerEntry le) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: const Text('Bu işlem kalıcı olarak silinecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _db.deleteTransaction(le.transactionId);
      _wasChanged = true;
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _showEditAccountDialog() {
    String name = _account.name;
    AccountType? selectedType = _account.accountType;
    String? currency = _account.currency;
    double openingBalance = _account.openingBalance;
    String description = _account.description ?? '';
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Hesap/Kasa Düzenle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<AccountType>(
                      decoration: buildInputDecoration('Hesap Türü'),
                      initialValue: selectedType,
                      hint: const Text('Seçiniz'),
                      items: AccountType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                      onChanged: (val) => setDialogState(() => selectedType = val),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: name,
                      decoration: buildInputDecoration('Hesap/Kasa Adı'),
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: openingBalance == 0.0 ? '' : formatNumberForInput(openingBalance),
                            decoration: buildInputDecoration('Açılış Bakiyesi'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [ThousandSeparatorInputFormatter()],
                            onChanged: (val) => openingBalance = parseFormattedNumber(val) ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: buildInputDecoration('Para Birimi'),
                            initialValue: currency,
                            hint: const Text('Seçiniz'),
                            items: appCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) => setDialogState(() => currency = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: description,
                      decoration: buildInputDecoration('Açıklama'),
                      onChanged: (val) => description = val,
                      maxLines: 2,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(errorText!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('İptal')),
                ElevatedButton(
                  onPressed: () async {
                    if (name.trim().isEmpty) {
                      setDialogState(() => errorText = 'Lütfen hesap/kasa adı girin.');
                      return;
                    }
                    if (selectedType == null) {
                      setDialogState(() => errorText = 'Lütfen hesap türü seçin.');
                      return;
                    }
                    if (currency == null) {
                      setDialogState(() => errorText = 'Lütfen para birimi seçin.');
                      return;
                    }
                    Navigator.pop(dialogCtx);
                    final updated = Account(
                      id: _account.id,
                      userId: _account.userId,
                      name: name.trim(),
                      accountType: selectedType!,
                      currency: currency!,
                      openingBalance: openingBalance,
                      description: description.trim().isEmpty ? null : description.trim(),
                    );
                    try {
                      await _db.updateAccount(updated);
                      _wasChanged = true;
                      _loadData();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text('${_account.name} hesabı silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _db.deleteAccount(_account.id);
      if (mounted) Navigator.pop(context, true);
    } on DependencyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ],
    );
  }

  Widget _buildHeader() {
    final bal = _account.currentBalance ?? _account.openingBalance;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(_accountIcon(_account.accountType), color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_account.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(_account.accountType.label, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          _detailRow('Güncel Bakiye', CurrencyFormatter.format(bal, currency: _account.currency)),
          const SizedBox(height: AppSpacing.sm),
          _detailRow('Açılış Bakiyesi', CurrencyFormatter.format(_account.openingBalance, currency: _account.currency)),
          if (_account.description != null && _account.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _detailRow('Açıklama', _account.description!),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showEditAccountDialog,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzenle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _confirmDeleteAccount,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Sil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              const Text('Bu hesapta henüz işlem yok.', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final le = _entries[index];
        final color = _colorFor(le);
        final signed = _signedAmount(le);
        final tr = le.transaction;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(_iconFor(le), color: color)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_labelFor(le), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      tr?.transactionDate.toLocal().toString().split(' ')[0] ?? '',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (tr?.description != null && tr!.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          tr.description!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${signed >= 0 ? '+' : '-'}${CurrencyFormatter.format(signed.abs(), currency: tr?.currency ?? _account.currency)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                        onPressed: () => _editEntry(le),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 14),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        onPressed: () => _deleteEntry(le),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: _account.name,
        icon: Icons.account_balance_wallet_outlined,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _wasChanged),
        ),
      ),
      body: _isFirstLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildHeader(),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                        child: Text(
                          'İŞLEMLER',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8),
                        ),
                      ),
                      _buildTransactionsList(),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
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
}
