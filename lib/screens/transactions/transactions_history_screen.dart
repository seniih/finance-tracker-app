import 'package:flutter/material.dart';
import '../../models/transaction_models.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/currency_formatter.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  final String? filterSafeId;
  final String? filterContactId;
  final bool showHeader;

  const TransactionsHistoryScreen({
    super.key,
    this.filterSafeId,
    this.filterContactId,
    this.showHeader = true,
  });

  @override
  State<TransactionsHistoryScreen> createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends State<TransactionsHistoryScreen> {
  late Future<List<TransactionModel>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = dbService.getTransactions(
      safeId: widget.filterSafeId,
      contactId: widget.filterContactId,
    );
  }

  Future<void> _deleteTx(TransactionModel tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('İşlemi Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Bu işlemi silmek istediğinize emin misiniz?\nİlgili kasa bakiyeleri geri alınacaktır.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await dbService.deleteTransaction(tx);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem silindi ve bakiye geri alındı.'), backgroundColor: AppColors.success));
        setState(() {
          _transactionsFuture = dbService.getTransactions(
            safeId: widget.filterSafeId,
            contactId: widget.filterContactId,
          );
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (widget.showHeader) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: const Icon(Icons.history, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text('İşlem Geçmişi', style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],

          // Liste
          Expanded(
            child: FutureBuilder<List<TransactionModel>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'İşlemler yüklenirken bir hata oluştu:\n${snapshot.error}',
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: AppColors.border),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Henüz hiçbir işlem bulunmuyor.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _TransactionCard(transaction: tx, onDelete: () => _deleteTx(tx));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatefulWidget {
  final TransactionModel transaction;
  final VoidCallback onDelete;

  const _TransactionCard({required this.transaction, required this.onDelete});

  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<_TransactionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final typeInfo = _getTypeInfo(widget.transaction.type);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surface : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? AppColors.border.withValues(alpha: 0.8) : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.05 : 0.02),
              blurRadius: _hovered ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              // İkon Alanı
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: typeInfo.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeInfo.icon, color: typeInfo.color, size: 24),
              ),
              const SizedBox(width: AppSpacing.lg),

              // Detaylar (Orta Kısım)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeInfo.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (widget.transaction.mainAccountName != null) ...[
                          const Icon(Icons.account_balance_wallet, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.transaction.type == 'transfer' && widget.transaction.fromAccountName != null
                                ? '${widget.transaction.fromAccountName} ➤ ${widget.transaction.mainAccountName}'
                                : widget.transaction.mainAccountName!,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (widget.transaction.contactName != null && widget.transaction.contactName!.isNotEmpty) ...[
                          const Icon(Icons.person, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.transaction.contactName!,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                    if (widget.transaction.description != null && widget.transaction.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.transaction.description!,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),

              // Tutar ve Tarih (Sağ Kısım)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${typeInfo.sign}${CurrencyFormatter.format(widget.transaction.amount, currency: widget.transaction.currency)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: typeInfo.amountColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(widget.transaction.date),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Hover ile görünen silme butonu
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md),
                  child: Tooltip(
                    message: 'İşlemi Sil',
                    child: InkWell(
                      onTap: widget.onDelete,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  _TransactionTypeInfo _getTypeInfo(String type) {
    switch (type) {
      case 'sale':
        return _TransactionTypeInfo(
          title: 'Satış',
          icon: Icons.sell_outlined,
          color: AppColors.success,
          amountColor: AppColors.success,
          sign: '+',
        );
      case 'purchase':
        return _TransactionTypeInfo(
          title: 'Alış',
          icon: Icons.shopping_cart_outlined,
          color: AppColors.error,
          amountColor: AppColors.error,
          sign: '-',
        );
      case 'collection':
        return _TransactionTypeInfo(
          title: 'Tahsilat',
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.success,
          amountColor: AppColors.success,
          sign: '+',
        );
      case 'payment':
        return _TransactionTypeInfo(
          title: 'Ödeme',
          icon: Icons.payment,
          color: AppColors.error,
          amountColor: AppColors.error,
          sign: '-',
        );
      case 'transfer':
        return _TransactionTypeInfo(
          title: 'Transfer',
          icon: Icons.swap_horiz,
          color: Colors.blue,
          amountColor: AppColors.textPrimary,
          sign: '',
        );
      default:
        return _TransactionTypeInfo(
          title: 'Bilinmeyen İşlem',
          icon: Icons.help_outline,
          color: Colors.grey,
          amountColor: Colors.grey,
          sign: '',
        );
    }
  }
}

class _TransactionTypeInfo {
  final String title;
  final IconData icon;
  final Color color;
  final Color amountColor;
  final String sign;

  _TransactionTypeInfo({
    required this.title,
    required this.icon,
    required this.color,
    required this.amountColor,
    required this.sign,
  });
}
