import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../models/account.dart';
import '../utils/constants.dart';
import '../services/database_service.dart';
import '../services/supabase_database_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/form_helpers.dart';
import '../utils/currency_formatter.dart';
import '../utils/number_input_formatter.dart';
import 'accounts/account_detail_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final DatabaseService dbService = SupabaseDatabaseService();
  bool _isLoading = false;
  bool _isFirstLoad = true;
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await dbService.getAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _isLoading = false;
        _isFirstLoad = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  void _showAddEditDialog([Account? existingAccount]) {
    final isEditing = existingAccount != null;

    String name = existingAccount?.name ?? '';
    AccountType? selectedType = existingAccount?.accountType;
    String? currency = existingAccount?.currency;
    double openingBalance = existingAccount?.openingBalance ?? 0.0;
    String description = existingAccount?.description ?? '';
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Hesap/Kasa Düzenle' : 'Yeni Hesap/Kasa Ekle'),
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
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
                    Navigator.pop(context);
                    setState(() => _isLoading = true);

                    final newAccount = Account(
                      id: isEditing ? existingAccount.id : '',
                      userId: isEditing ? existingAccount.userId : '',
                      name: name.trim(),
                      accountType: selectedType!,
                      currency: currency!,
                      openingBalance: openingBalance,
                      description: description.trim().isEmpty ? null : description.trim(),
                    );

                    try {
                      if (isEditing) {
                        await dbService.updateAccount(newAccount);
                      } else {
                        await dbService.addAccount(newAccount);
                      }
                      _loadData();
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                      }
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


  Future<void> _openDetail(Account account) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AccountDetailScreen(account: account)),
    );
    if (changed == true) _loadData();
  }

  IconData _accountIcon(AccountType type) {
    return switch (type) {
      AccountType.cash => Icons.payments_outlined,
      AccountType.bank => Icons.account_balance_outlined,
      AccountType.creditCard => Icons.credit_card_outlined,
    };
  }

  Widget _buildTotalsHeader() {
    final totals = <String, double>{};
    for (final a in _accounts) {
      final bal = a.currentBalance ?? a.openingBalance;
      totals[a.currency] = (totals[a.currency] ?? 0) + bal;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: entries.map((e) {
          final isNegative = e.value < 0;
          final tintColor = isNegative ? AppColors.error : AppColors.primary;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: tintColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${CurrencyFormatter.getLabel(e.key)}: ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                Text(
                  CurrencyFormatter.format(e.value, currency: e.key),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tintColor),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Hesaplar / Kasalar', icon: Icons.account_balance_wallet),
      body: _isFirstLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                _accounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.border),
                            const SizedBox(height: AppSpacing.lg),
                            const Text('Henüz hesap/kasa eklenmemiş.', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          _buildTotalsHeader(),
                          const Divider(height: 1, color: AppColors.border),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: _accounts.length,
                              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final account = _accounts[index];
                                return _AccountCard(
                                  account: account,
                                  icon: _accountIcon(account.accountType),
                                  onTap: () => _openDetail(account),
                                );
                              },
                            ),
                          ),
                        ],
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Hesap Ekle'),
      ),
    );
  }
}

// ── Hesap Kartı ───────────────────────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final Account account;
  final IconData icon;
  final VoidCallback onTap;

  const _AccountCard({required this.account, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(account.accountType.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(account.currentBalance ?? account.openingBalance, currency: account.currency),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: (account.currentBalance ?? account.openingBalance) < 0
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Güncel Bakiye', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Hesap detay ekranı artık AccountDetailScreen (accounts/account_detail_screen.dart)
// üzerinden tam sayfa olarak açılıyor -- eski bottom sheet kaldırıldı.
