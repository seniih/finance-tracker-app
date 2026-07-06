import 'package:flutter/material.dart';
import '../models/safe_models.dart';
import '../services/database_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/currency_formatter.dart';
import '../utils/number_input_formatter.dart';
import 'transactions/transactions_history_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SafesScreen extends StatefulWidget {
  final Safe? selectedSafe;
  final VoidCallback? onSafeAdded;
  final void Function(Safe?)? onSafeSelected;

  const SafesScreen({
    super.key,
    this.selectedSafe,
    this.onSafeAdded,
    this.onSafeSelected,
  });

  @override
  State<SafesScreen> createState() => _SafesScreenState();
}

class _SafesScreenState extends State<SafesScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.selectedSafe != null) {
      return _SafeDetailView(
        safe: widget.selectedSafe!,
        onBack: () => widget.onSafeSelected?.call(null),
        onSafeDeleted: widget.onSafeAdded,
      );
    }
    return _SafeListView(
      onSafeAdded: _handleSafeAdded,
      onSafeSelected: (safe) => widget.onSafeSelected?.call(safe),
    );
  }

  void _handleSafeAdded() {
    setState(() {});
    widget.onSafeAdded?.call();
  }
}

class _SafeListView extends StatefulWidget {
  final VoidCallback onSafeAdded;
  final void Function(Safe) onSafeSelected;

  const _SafeListView({
    required this.onSafeAdded,
    required this.onSafeSelected,
  });

  @override
  State<_SafeListView> createState() => _SafeListViewState();
}

class _SafeListViewState extends State<_SafeListView> {
  Future<List<Safe>>? _safesFuture;

  @override
  void initState() {
    super.initState();
    _loadSafes();
  }

  void _loadSafes() {
    setState(() {
      _safesFuture = dbService.getSafes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SafeListHeader(onAddPressed: _showAddSafeDialog),
          const SizedBox(height: AppSpacing.xxl),
          Expanded(
            child: FutureBuilder<List<Safe>>(
              future: _safesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  String errMsg = snapshot.error.toString();
                  if (snapshot.error is PostgrestException) {
                    final pe = snapshot.error as PostgrestException;
                    if (pe.code == '42P01') {
                      errMsg = 'Veritabanında "safes" tablosu bulunamadı.\nLütfen "docs/safe_table_setup.sql" dosyasındaki SQL komutlarını Supabase üzerinde çalıştırın.';
                    } else {
                      errMsg = pe.message;
                    }
                  }
                  
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Hata: $errMsg',
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final safes = snapshot.data ?? [];
                if (safes.isEmpty) {
                  return Center(
                    child: Text(
                      'Henüz kasa eklenmemiş',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: safes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, index) {
                    final safe = safes[index];
                    return InkWell(
                      onTap: () => widget.onSafeSelected(safe),
                      borderRadius: BorderRadius.circular(14),
                      child: _SafeCard(safe: safe),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSafeDialog() async {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    String? selectedCurrency;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Yeni Kasa Ekle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Kasa Adı',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [ThousandSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Açılış Bakiyesi',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Para Birimi',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TL', child: Text('TL')),
                      DropdownMenuItem(value: 'USD', child: Text('Dolar')),
                      DropdownMenuItem(value: 'EUR', child: Text('Euro')),
                      DropdownMenuItem(value: 'GRAM_ALTIN', child: Text('Gram Altın')),
                      DropdownMenuItem(value: 'CUMHURIYET_ALTINI', child: Text('Cumhuriyet Altını')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCurrency = val);
                      }
                    },
                    validator: (val) => val == null ? 'Para birimi seçin' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.sidebarText,
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  final balance = parseFormattedNumber(balanceController.text) ?? 0.0;
                  if (name.isEmpty || selectedCurrency == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen kasa adı ve para birimi alanlarını doldurun.')),
                    );
                    return;
                  }
                  Navigator.of(context).pop({
                    'name': name,
                    'balance': balance,
                    'currency': selectedCurrency,
                  });
                },
                child: const Text('Ekle'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final newSafe = Safe(
        id: DateTime.now().toString(),
        name: result['name'],
        totalDebit: result['balance'],
        currency: result['currency'],
      );
      
      try {
        await dbService.addSafe(newSafe);
        if (!mounted) return;
        _loadSafes();
        widget.onSafeAdded();
      } on PostgrestException catch (pe) {
        if (!mounted) return;
        String errorMessage = pe.message;
        if (pe.code == '42P01') {
          errorMessage = 'Veritabanında "safes" tablosu bulunamadı! Lütfen Supabase SQL Editor\'den safe_table_setup.sql dosyasını çalıştırın.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beklenmeyen bir hata oluştu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _SafeDetailView extends StatelessWidget {
  final Safe safe;
  final VoidCallback onBack;
  final VoidCallback? onSafeDeleted;

  const _SafeDetailView({
    required this.safe,
    required this.onBack,
    this.onSafeDeleted,
  });

  Future<void> _deleteSafe(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Kasayı Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"${safe.name}" kasasını silmek istediğinize emin misiniz?', style: const TextStyle(color: AppColors.textSecondary)),
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
        await dbService.deleteSafe(safe);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kasa başarıyla silindi.'), backgroundColor: AppColors.success));
        onSafeDeleted?.call();
        onBack();
      } catch (e) {
        if (!context.mounted) return;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(safe.name, style: Theme.of(context).textTheme.headlineLarge),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _deleteSafe(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                ),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Kasayı Sil'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Expanded(
            child: TransactionsHistoryScreen(
              filterSafeId: safe.id,
              showHeader: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeListHeader extends StatelessWidget {
  final VoidCallback onAddPressed;

  const _SafeListHeader({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.md),
              ),
              child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.lg),
            Text('Kasalar', style: Theme.of(context).textTheme.headlineLarge),
          ],
        ),
        ElevatedButton.icon(
          onPressed: onAddPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.sidebarText,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Kasa Ekle'),
        ),
      ],
    );
  }
}

class _SafeCard extends StatefulWidget {
  final Safe safe;

  const _SafeCard({required this.safe});

  @override
  State<_SafeCard> createState() => _SafeCardState();
}

class _SafeCardState extends State<_SafeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered ? AppColors.border.withValues(alpha: 0.9) : AppColors.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            _SafeIcon(),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.safe.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    CurrencyFormatter.getLabel(widget.safe.currency),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            _AmountColumn(
              label: 'Bakiye',
              amount: widget.safe.balance,
              currency: widget.safe.currency,
              color: widget.safe.balance >= 0 ? AppColors.success : AppColors.error,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SafeIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: AppSpacing.xxl),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  final String label;
  final double amount;
  final String? currency;
  final Color color;
  final bool isBold;

  const _AmountColumn({
    required this.label,
    required this.amount,
    this.currency,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            CurrencyFormatter.format(amount, currency: currency),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
