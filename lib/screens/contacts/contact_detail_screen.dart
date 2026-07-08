import 'package:flutter/material.dart';
import '../../models/contact.dart';
import '../../models/contact_type.dart';
import '../../models/transaction.dart';
import '../../models/ledger_entry.dart';
import '../../utils/constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/contact_balance.dart';
import '../../utils/number_input_formatter.dart';
import '../../utils/form_helpers.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../transactions/forms/transaction_form.dart';
import '../transactions/forms/investment_in_form.dart';
import '../transactions/forms/investment_out_form.dart';

/// Bir carinin detay sayfası: iletişim bilgileri, cariyi düzenle/sil ve o
/// cariye bağlı tüm işlemlerin listesi (her satırda düzenle/sil).
///
/// Bu ekran iki farklı akıştan açılabilir:
/// 1) Cariler listesinden bir karta tıklanarak (Navigator.push, geri dönüşte
///    [Navigator.pop] ile değişiklik olduğu bildirilir).
/// 2) Kenar çubuğundaki (sidebar) "Cariler" akışı üzerinden -- bu durumda
///    [onBack]/[onChanged] callback'leri kullanılır çünkü bu ekran o akışta
///    bir sayfa olarak push edilmez, içerik olarak gömülür.
class ContactDetailScreen extends StatefulWidget {
  final Contact contact;
  final VoidCallback? onBack;
  final VoidCallback? onChanged;

  const ContactDetailScreen({super.key, required this.contact, this.onBack, this.onChanged});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final DatabaseService _db = SupabaseDatabaseService();

  late Contact _contact = widget.contact;
  bool _isLoading = true;
  bool _isFirstLoad = true;
  bool _wasChanged = false;
  List<TransactionModel> _transactions = [];
  Map<String, double> _balances = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getTransactions(contactId: _contact.id);
      if (!mounted) return;
      setState(() {
        _transactions = data;
        _balances = ContactBalanceCalculator.calculate(
          data,
          openingBalance: _contact.openingBalance,
          openingBalanceCurrency: _contact.openingBalanceCurrency,
        );
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

  void _notifyChanged() {
    _wasChanged = true;
    widget.onChanged?.call();
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context, _wasChanged);
    }
  }

  Color _colorFor(TransactionModel tr) {
    return switch (tr.transactionType) {
      TransactionType.standard => tr.category?.type == CategoryType.income ? AppColors.success : AppColors.error,
      TransactionType.transfer => AppColors.info,
      TransactionType.investmentIn => AppColors.investmentIn,
      TransactionType.investmentOut => AppColors.investmentOut,
    };
  }

  IconData _iconFor(TransactionModel tr) {
    return switch (tr.transactionType) {
      TransactionType.standard => tr.category?.type == CategoryType.income ? Icons.trending_up : Icons.trending_down,
      TransactionType.transfer => Icons.swap_horiz,
      TransactionType.investmentIn => Icons.download,
      TransactionType.investmentOut => Icons.upload,
    };
  }

  String _labelFor(TransactionModel tr) {
    if (tr.transactionType == TransactionType.standard && tr.category != null) return tr.category!.name;
    return tr.transactionType.label;
  }

  bool _isPositive(TransactionModel tr) {
    if (tr.transactionType == TransactionType.investmentIn) return true;
    if (tr.transactionType == TransactionType.standard) return tr.category?.type == CategoryType.income;
    return false;
  }

  Future<void> _editTransaction(TransactionModel tr) async {
    List<LedgerEntry> ledgers;
    try {
      ledgers = await _db.getLedgerEntriesForTransaction(tr.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      return;
    }
    if (!mounted) return;

    Widget? form;
    if (tr.transactionType == TransactionType.standard) {
      form = TransactionForm(existingTransaction: tr, existingLedgers: ledgers);
    } else if (tr.transactionType == TransactionType.investmentIn) {
      form = InvestmentInForm(existingTransaction: tr, existingLedgers: ledgers);
    } else if (tr.transactionType == TransactionType.investmentOut) {
      form = InvestmentOutForm(existingTransaction: tr, existingLedgers: ledgers);
    }
    // Not: Transfer işlemlerinde contact_id hiç set edilmediğinden bu listede
    // transfer görünmez, bu yüzden transfer için bir dal gerekmiyor.
    if (form == null) return;

    final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => form!));
    if (changed == true) {
      _notifyChanged();
      _loadData();
    }
  }

  Future<void> _deleteTransaction(TransactionModel tr) async {
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
      await _db.deleteTransaction(tr.id);
      _notifyChanged();
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _showEditContactDialog() async {
    List<ContactTypeModel> contactTypes;
    try {
      contactTypes = await _db.getContactTypes();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      return;
    }
    if (!mounted) return;

    String name = _contact.name;
    String? selectedTypeId = _contact.contactTypeId;
    String phone = _contact.phone ?? '';
    String email = _contact.email ?? '';
    String taxOffice = _contact.taxOffice ?? '';
    String iban = _contact.iban ?? '';
    String address = _contact.address ?? '';
    String description = _contact.description ?? '';
    String openingBalanceStr = _contact.openingBalance == 0 ? '' : formatNumberForInput(_contact.openingBalance.abs());
    String openingCurrency = _contact.openingBalanceCurrency;
    bool isDebtor = _contact.openingBalance >= 0; // true: cari bana borçlu
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Cari Düzenle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (contactTypes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          decoration: buildInputDecoration('Cari Türü (Opsiyonel)'),
                          initialValue: selectedTypeId,
                          hint: const Text('Seçiniz'),
                          items: contactTypes.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                          onChanged: (val) => setDialogState(() => selectedTypeId = val),
                        ),
                      ),
                    TextFormField(
                      initialValue: name,
                      decoration: buildInputDecoration('İsim / Kurum Adı'),
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: phone,
                      decoration: buildInputDecoration('Telefon'),
                      onChanged: (val) => phone = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: email,
                      decoration: buildInputDecoration('E-posta'),
                      onChanged: (val) => email = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: taxOffice,
                      decoration: buildInputDecoration('Vergi Dairesi / VKN / TC'),
                      onChanged: (val) => taxOffice = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: iban,
                      decoration: buildInputDecoration('IBAN'),
                      onChanged: (val) => iban = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: address,
                      decoration: buildInputDecoration('Adres'),
                      onChanged: (val) => address = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: description,
                      decoration: buildInputDecoration('Açıklama'),
                      onChanged: (val) => description = val,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Açılış Bakiyesi (Devir) -- Opsiyonel',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: openingBalanceStr,
                            decoration: buildInputDecoration('Tutar'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [ThousandSeparatorInputFormatter()],
                            onChanged: (val) => openingBalanceStr = val,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: buildInputDecoration('Para Birimi'),
                            initialValue: openingCurrency,
                            items: appCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) => setDialogState(() => openingCurrency = val ?? openingCurrency),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => isDebtor = true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isDebtor ? AppColors.success.withValues(alpha: 0.1) : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDebtor ? AppColors.success : AppColors.border),
                              ),
                              child: Text(
                                'Cari Bana Borçlu',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDebtor ? AppColors.success : AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => isDebtor = false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isDebtor ? AppColors.warning.withValues(alpha: 0.1) : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: !isDebtor ? AppColors.warning : AppColors.border),
                              ),
                              child: Text(
                                'Ben Cariye Borçluyum',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: !isDebtor ? AppColors.warning : AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                      setDialogState(() => errorText = 'Lütfen isim girin.');
                      return;
                    }
                    Navigator.pop(dialogCtx);
                    final openingAmount = parseFormattedNumber(openingBalanceStr)?.abs() ?? 0.0;
                    final updated = Contact(
                      id: _contact.id,
                      userId: _contact.userId,
                      name: name.trim(),
                      contactTypeId: selectedTypeId,
                      phone: phone.trim().isEmpty ? null : phone.trim(),
                      email: email.trim().isEmpty ? null : email.trim(),
                      taxOffice: taxOffice.trim().isEmpty ? null : taxOffice.trim(),
                      iban: iban.trim().isEmpty ? null : iban.trim(),
                      address: address.trim().isEmpty ? null : address.trim(),
                      description: description.trim().isEmpty ? null : description.trim(),
                      openingBalance: isDebtor ? openingAmount : -openingAmount,
                      openingBalanceCurrency: openingCurrency,
                    );
                    try {
                      await _db.updateContact(updated);
                      if (!mounted) return;
                      setState(() {
                        _contact = updated;
                        _balances = ContactBalanceCalculator.calculate(
                          _transactions,
                          openingBalance: _contact.openingBalance,
                          openingBalanceCurrency: _contact.openingBalanceCurrency,
                        );
                      });
                      _notifyChanged();
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

  Future<void> _confirmDeleteContact() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text('${_contact.name} kişisi silinecek.'),
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
      await _db.deleteContact(_contact.id);
      _notifyChanged();
      if (!mounted) return;
      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        Navigator.pop(context, true);
      }
    } on DependencyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cari bakiye özeti: pozitif = "Cari bana borçlu", negatif = "Ben cariye borçluyum".
  // Birden fazla para biriminde işlem varsa her biri ayrı rozet olarak gösterilir.
  Widget _buildBalanceSection() {
    if (_balances.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Bakiye: Kapalı (borç/alacak yok)',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      );
    }

    final entries = _balances.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: entries.map((e) {
        final isDebtor = e.value > 0; // cari bana borçlu
        final tintColor = isDebtor ? AppColors.success : AppColors.warning;
        final label = isDebtor ? 'Cari Bana Borçlu' : 'Ben Cariye Borçluyum';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: tintColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tintColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: tintColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.format(e.value.abs(), currency: e.key),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tintColor),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeader() {
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
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  _contact.name.isNotEmpty ? _contact.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_contact.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    if (_contact.contactType != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(_contact.contactType!.name, style: const TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildBalanceSection(),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.border),
          const SizedBox(height: AppSpacing.lg),
          if (_contact.phone != null) _detailRow(Icons.phone_outlined, 'Telefon', _contact.phone!),
          if (_contact.email != null) _detailRow(Icons.email_outlined, 'E-posta', _contact.email!),
          if (_contact.taxOffice != null) _detailRow(Icons.business_outlined, 'VD / VKN / TC', _contact.taxOffice!),
          if (_contact.iban != null) _detailRow(Icons.account_balance_outlined, 'IBAN', _contact.iban!),
          if (_contact.address != null) _detailRow(Icons.location_on_outlined, 'Adres', _contact.address!),
          if (_contact.description != null) _detailRow(Icons.notes_outlined, 'Açıklama', _contact.description!),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showEditContactDialog,
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
                  onPressed: _confirmDeleteContact,
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
    if (_transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              const Text('Bu cariye bağlı işlem yok.', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      itemCount: _transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final tr = _transactions[index];
        final color = _colorFor(tr);
        final isPositive = _isPositive(tr);
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(_iconFor(tr), color: color)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_labelFor(tr), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      tr.transactionDate.toLocal().toString().split(' ')[0],
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (tr.description != null && tr.description!.isNotEmpty)
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
                    '${isPositive ? '+' : '-'}${CurrencyFormatter.format(tr.amount, currency: tr.currency)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                        onPressed: () => _editTransaction(tr),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 14),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        onPressed: () => _deleteTransaction(tr),
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
        title: _contact.name,
        icon: Icons.person_outline,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack),
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
