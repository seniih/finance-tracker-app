import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/constants.dart';
import '../../models/transaction.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';
import '../../models/ledger_entry.dart';
import 'forms/transaction_form.dart';
import 'forms/transfer_form.dart';
import 'forms/investment_in_form.dart';
import 'forms/investment_out_form.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  State<TransactionsHistoryScreen> createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends State<TransactionsHistoryScreen> {
  final DatabaseService dbService = SupabaseDatabaseService();
  bool _isLoading = false;
  bool _isFirstLoad = true;
  List<TransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await dbService.getTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = data;
        _isLoading = false;
        _isFirstLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isFirstLoad = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Bir işlemi tipine uygun formda düzenlemeye açar. Hesap bilgisi
  /// ledger_entries'te tutulduğundan (transactions.account_id her zaman
  /// dolu değil) önce ledger'lar çekilir -- account_detail'daki akışla aynı.
  Future<void> _editTransaction(TransactionModel tr) async {
    List<LedgerEntry> ledgers;
    try {
      ledgers = await dbService.getLedgerEntriesForTransaction(tr.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    if (!mounted) return;

    final form = switch (tr.transactionType) {
      TransactionType.standard => TransactionForm(existingTransaction: tr, existingLedgers: ledgers),
      TransactionType.transfer => TransferForm(existingTransaction: tr, existingLedgers: ledgers),
      TransactionType.investmentIn => InvestmentInForm(existingTransaction: tr, existingLedgers: ledgers),
      TransactionType.investmentOut => InvestmentOutForm(existingTransaction: tr, existingLedgers: ledgers),
    };

    final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => form));
    if (changed == true) _loadData();
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: const Text('Bu işlem kalıcı olarak silinecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await dbService.deleteTransaction(transaction.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İşlem silindi.')),
          );
        }
        _loadData();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Color _getTransactionColor(TransactionModel tr) {
    switch (tr.transactionType) {
      case TransactionType.standard:
        return tr.category?.type == CategoryType.income ? AppColors.success : AppColors.error;
      case TransactionType.transfer:
        return AppColors.info;
      case TransactionType.investmentIn:
        return AppColors.investmentIn;
      case TransactionType.investmentOut:
        return AppColors.investmentOut;
    }
  }

  IconData _getTransactionIcon(TransactionModel tr) {
    switch (tr.transactionType) {
      case TransactionType.standard:
        return tr.category?.type == CategoryType.income ? Icons.trending_up : Icons.trending_down;
      case TransactionType.transfer:
        return Icons.swap_horiz;
      case TransactionType.investmentIn:
        return Icons.download;
      case TransactionType.investmentOut:
        return Icons.upload;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Tüm İşlemler', icon: Icons.list_alt),
      body: _isFirstLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                _transactions.isEmpty
                    ? _buildEmptyState()
                    : _buildTransactionList(),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showAddTransactionOptions,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Henüz İşlem Yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Kayıtlı herhangi bir finansal işlem bulunamadı.\nYeni işlem eklemek için + butonuna tıklayın.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final tr = _transactions[index];
        final typeColor = _getTransactionColor(tr);
        final isPositive = tr.transactionType == TransactionType.investmentIn || 
            (tr.transactionType == TransactionType.standard && tr.category?.type == CategoryType.income);
        final amountPrefix = tr.transactionType == TransactionType.transfer ? '' : (isPositive ? '+' : '-');
        final displayLabel = tr.transactionType == TransactionType.standard && tr.category != null 
            ? tr.category!.name 
            : tr.transactionType.label;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            leading: CircleAvatar(
              backgroundColor: typeColor.withValues(alpha: 0.1),
              child: Icon(_getTransactionIcon(tr), color: typeColor),
            ),
            title: Text(
              displayLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  tr.transactionDate.toLocal().toString().split(' ')[0],
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (tr.description != null && tr.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tr.description!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$amountPrefix${CurrencyFormatter.formatAmount(tr.amount)} ${tr.currency}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: tr.transactionType == TransactionType.transfer
                        ? AppColors.textPrimary
                        : typeColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                  tooltip: 'Seçenekler',
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editTransaction(tr);
                        break;
                      case 'delete':
                        _deleteTransaction(tr);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                          SizedBox(width: AppSpacing.sm),
                          Text('Düzenle'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          SizedBox(width: AppSpacing.sm),
                          Text('Sil', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddTransactionOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'İşlem Türü Seçin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              _buildBottomSheetItem(
                ctx: ctx,
                icon: Icons.trending_down,
                color: AppColors.error,
                title: 'Gider Ekle',
                targetForm: const TransactionForm(fixedType: CategoryType.expense),
              ),
              _buildBottomSheetItem(
                ctx: ctx,
                icon: Icons.trending_up,
                color: AppColors.success,
                title: 'Gelir Ekle',
                targetForm: const TransactionForm(fixedType: CategoryType.income),
              ),
              _buildBottomSheetItem(
                ctx: ctx,
                icon: Icons.swap_horiz,
                color: AppColors.info,
                title: 'Transfer Ekle',
                targetForm: const TransferForm(),
              ),
              // Not: Yatırım girişi/çıkışı artık burada değil, Projeler ekranında
              // ilgili arsa üzerinden (proje/arsa önceden seçili olarak) yapılıyor.
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetItem({
    required BuildContext ctx,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required Widget targetForm,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
      onTap: () {
        Navigator.pop(ctx);
        Navigator.push(context, MaterialPageRoute(builder: (_) => targetForm)).then((_) => _loadData());
      },
    );
  }
}
