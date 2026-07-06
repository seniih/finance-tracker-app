import 'package:flutter/material.dart';
import '../models/category_models.dart';
import '../services/database_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/currency_formatter.dart';
import '../utils/number_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfitCentersScreen extends StatefulWidget {
  const ProfitCentersScreen({super.key});

  @override
  State<ProfitCentersScreen> createState() => _ProfitCentersScreenState();
}

class _ProfitCentersScreenState extends State<ProfitCentersScreen> {
  ProfitCenter? _selectedProfitCenter;
  MainCategory? _selectedMainCategory;
  List<ProfitCenter> _profitCenters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await dbService.getProfitCenters();
      setState(() {
        _profitCenters = data;
        if (_selectedProfitCenter != null) {
          try {
            _selectedProfitCenter = data.firstWhere((p) => p.id == _selectedProfitCenter!.id);
          } catch (_) {
            _selectedProfitCenter = null;
            _selectedMainCategory = null;
          }
        }
        if (_selectedMainCategory != null && _selectedProfitCenter != null) {
          try {
            _selectedMainCategory = _selectedProfitCenter!.mainCategories.firstWhere((g) => g.id == _selectedMainCategory!.id);
          } catch (_) {
            _selectedMainCategory = null;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is PostgrestException) {
          msg = e.code == '42P01'
              ? 'Tablolar bulunamadı. Lütfen docs/profit_centers_setup.sql dosyasını Supabase\'de çalıştırın.'
              : e.message;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $msg'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem<T>(T item, String typeName, Future<void> Function(String) deleteFunc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('$typeName Sil', style: const TextStyle(color: AppColors.textPrimary)),
        content: Text('Bu öğeyi ve ona bağlı TÜM verileri silmek istediğinize emin misiniz?', style: const TextStyle(color: AppColors.textSecondary)),
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
        final id = (item as dynamic).id;
        await deleteFunc(id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$typeName silindi.'), backgroundColor: AppColors.success));
        
        if (item is ProfitCenter && _selectedProfitCenter?.id == id) {
          _selectedProfitCenter = null;
          _selectedMainCategory = null;
        }
        if (item is MainCategory && _selectedMainCategory?.id == id) {
          _selectedMainCategory = null;
        }

        _loadData();
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
          Row(
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
                    child: const Icon(Icons.business_center, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text('Kar Merkezleri', style: Theme.of(context).textTheme.headlineLarge),
                ],
              ),
              if (_isLoading)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Üç sütunlu panel
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        // Sütun 1: Kar Merkezleri
                        Expanded(
                          child: _buildColumn<ProfitCenter>(
                            title: 'Kar Merkezleri',
                            icon: Icons.business_center,
                            items: _profitCenters,
                            selectedItem: _selectedProfitCenter,
                            onItemSelected: (item) => setState(() {
                              _selectedProfitCenter = item;
                              _selectedMainCategory = null;
                            }),
                            onAddPressed: _addProfitCenter,
                            itemBuilder: (item) => _GroupCard(
                              name: item.name,
                              balance: item.balance,
                              currency: item.currency,
                              exchangeRate: item.exchangeRate,
                              isSelected: item == _selectedProfitCenter,
                              hasChildren: item.mainCategories.isNotEmpty,
                              onEdit: () => _editItem(item, 'Kar Merkezi'),
                              onDelete: () => _deleteItem(item, 'Kar Merkezi', dbService.deleteProfitCenter),
                            ),
                            addButtonLabel: 'Kar Merkezi Ekle',
                          ),
                        ),
                        const VerticalDivider(width: 1, color: AppColors.border),

                        // Sütun 2: Ana Kategoriler
                        Expanded(
                          child: _buildColumn<MainCategory>(
                            title: 'Ana Kategoriler',
                            icon: Icons.folder_outlined,
                            items: _selectedProfitCenter?.mainCategories ?? [],
                            selectedItem: _selectedMainCategory,
                            onItemSelected: (item) => setState(() => _selectedMainCategory = item),
                            onAddPressed: _selectedProfitCenter != null ? _addMainCategory : null,
                            itemBuilder: (item) => _GroupCard(
                              name: item.name,
                              balance: item.balance,
                              currency: item.currency,
                              exchangeRate: item.exchangeRate,
                              isSelected: item == _selectedMainCategory,
                              hasChildren: item.subCategories.isNotEmpty,
                              onEdit: () => _editItem(item, 'Ana Kategori'),
                              onDelete: () => _deleteItem(item, 'Ana Kategori', dbService.deleteMainCategory),
                            ),
                            addButtonLabel: 'Ana Kategori Ekle',
                            emptyMessage: _selectedProfitCenter == null
                                ? 'Bir Kar Merkezi seçin'
                                : 'Henüz ana kategori yok',
                          ),
                        ),
                        const VerticalDivider(width: 1, color: AppColors.border),

                        // Sütun 3: Alt Kategoriler
                        Expanded(
                          child: _buildColumn<SubCategory>(
                            title: 'Alt Kategoriler',
                            icon: Icons.account_tree_outlined,
                            items: _selectedMainCategory?.subCategories ?? [],
                            selectedItem: null,
                            onItemSelected: (_) {},
                            onAddPressed: _selectedMainCategory != null ? _addSubCategory : null,
                            itemBuilder: (item) => _GroupCard(
                              name: item.name,
                              balance: item.balance,
                              currency: item.currency,
                              exchangeRate: item.exchangeRate,
                              isSelected: false,
                              hasChildren: false,
                              onEdit: () => _editItem(item, 'Alt Kategori'),
                              onDelete: () => _deleteItem(item, 'Alt Kategori', dbService.deleteSubCategory),
                            ),
                            addButtonLabel: 'Alt Kategori Ekle',
                            emptyMessage: _selectedMainCategory == null
                                ? 'Bir Ana Kategori seçin'
                                : 'Henüz alt kategori yok',
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn<T>({
    required String title,
    required IconData icon,
    required List<T> items,
    required T? selectedItem,
    required Function(T) onItemSelected,
    required VoidCallback? onAddPressed,
    required Widget Function(T) itemBuilder,
    required String addButtonLabel,
    String emptyMessage = 'Eleman bulunamadı',
  }) {
    return Column(
      children: [
        // Kolon başlığı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${items.length}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        // Liste
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 36, color: AppColors.border),
                      const SizedBox(height: 8),
                      Text(emptyMessage, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return GestureDetector(
                      onTap: () => onItemSelected(item),
                      child: itemBuilder(item),
                    );
                  },
                ),
        ),
        // Ekle butonu
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.all(10),
          child: ElevatedButton.icon(
            onPressed: onAddPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: onAddPressed != null ? AppColors.primary : AppColors.border,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(addButtonLabel, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  // --- Diyalog ---

  Future<Map<String, dynamic>?> _showFormDialog(String title, String label, {
    String? initialName,
    double? initialBalance,
    String? initialCurrency,
    double? initialExchangeRate,
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    String? selectedCurrency = initialCurrency?.toUpperCase();
    final validCurrencies = ['TL', 'USD', 'EURO', 'GRAM_ALTIN', 'CUMHURIYET_ALTINI'];
    if (selectedCurrency == null || !validCurrencies.contains(selectedCurrency)) {
      selectedCurrency = 'TL';
    }

    final balanceCtrl = TextEditingController(
      text: initialBalance != null && initialBalance != 0 
          ? initialBalance.toStringAsFixed(2).replaceAll('.00', '').replaceAll('.', ',')
          : '',
    );
    final exchangeRateCtrl = TextEditingController(
      text: initialExchangeRate != null && initialExchangeRate != 0
          ? initialExchangeRate.toStringAsFixed(2).replaceAll('.00', '').replaceAll('.', ',')
          : '',
    );

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
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
                    DropdownMenuItem(value: 'EURO', child: Text('Euro')),
                    DropdownMenuItem(value: 'GRAM_ALTIN', child: Text('Gram Altın')),
                    DropdownMenuItem(value: 'CUMHURIYET_ALTINI', child: Text('Cumhuriyet Altını')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedCurrency = val),
                  validator: (val) => val == null ? 'Para birimi seçin' : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç Bakiyesi',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ThousandSeparatorInputFormatter()],
                ),
                if (selectedCurrency != null && selectedCurrency != 'TL') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: exchangeRateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'O Anki Kur Karşılığı (TL)',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [ThousandSeparatorInputFormatter()],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || selectedCurrency == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen isim ve para birimi alanlarını doldurun.')),
                  );
                  return;
                }
                Navigator.of(context).pop({
                  'name': nameCtrl.text,
                  'balance': balanceCtrl.text,
                  'currency': selectedCurrency,
                  'exchange_rate': exchangeRateCtrl.text,
                });
              },
              child: Text(initialName == null ? 'Ekle' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _addProfitCenter() async {
    final data = await _showFormDialog('Yeni Kar Merkezi', 'Kar Merkezi Adı');
    final name = data?['name'] as String?;
    if (name == null || name.trim().isEmpty) return;
    final balance = parseFormattedNumber(data?['balance'] as String? ?? '') ?? 0.0;
    final currency = data?['currency'] as String? ?? 'TL';
    final exchangeRate = parseFormattedNumber(data?['exchange_rate'] as String? ?? '');
    try {
      final newPc = ProfitCenter(id: '', name: name.trim(), balance: balance, currency: currency, exchangeRate: exchangeRate);
      await dbService.addProfitCenter(newPc);
      if (mounted) _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ekleme başarısız: $e'), backgroundColor: AppColors.error));
    }
  }

  void _addMainCategory() async {
    if (_selectedProfitCenter == null) return;
    final data = await _showFormDialog('Yeni Ana Kategori', 'Ana Kategori Adı');
    final name = data?['name'] as String?;
    if (name == null || name.trim().isEmpty) return;
    final balance = parseFormattedNumber(data?['balance'] as String? ?? '') ?? 0.0;
    final currency = data?['currency'] as String? ?? 'TL';
    final exchangeRate = parseFormattedNumber(data?['exchange_rate'] as String? ?? '');
    try {
      final newMc = MainCategory(id: '', name: name.trim(), balance: balance, currency: currency, exchangeRate: exchangeRate);
      await dbService.addMainCategory(newMc, _selectedProfitCenter!.id);
      if (mounted) _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ekleme başarısız: $e'), backgroundColor: AppColors.error));
    }
  }

  void _addSubCategory() async {
    if (_selectedMainCategory == null) return;
    final data = await _showFormDialog('Yeni Alt Kategori', 'Alt Kategori Adı');
    final name = data?['name'] as String?;
    if (name == null || name.trim().isEmpty) return;
    final balance = parseFormattedNumber(data?['balance'] as String? ?? '') ?? 0.0;
    final currency = data?['currency'] as String? ?? 'TL';
    final exchangeRate = parseFormattedNumber(data?['exchange_rate'] as String? ?? '');
    try {
      final newSc = SubCategory(id: '', name: name.trim(), balance: balance, currency: currency, exchangeRate: exchangeRate);
      await dbService.addSubCategory(newSc, _selectedMainCategory!.id);
      if (mounted) _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ekleme başarısız: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _editItem<T>(T item, String typeName) async {
    final dynamic obj = item;
    final data = await _showFormDialog(
      '$typeName Düzenle',
      '$typeName Adı',
      initialName: obj.name,
      initialBalance: obj.balance,
      initialCurrency: obj.currency,
      initialExchangeRate: obj.exchangeRate,
    );
    if (data == null) return;

    final name = data['name'] as String?;
    if (name == null || name.trim().isEmpty) return;
    final balance = parseFormattedNumber(data['balance'] as String? ?? '') ?? 0.0;
    final currency = data['currency'] as String? ?? 'TL';
    final exchangeRate = parseFormattedNumber(data['exchange_rate'] as String? ?? '');

    try {
      if (item is ProfitCenter) {
        item.name = name.trim();
        item.balance = balance;
        item.currency = currency;
        item.exchangeRate = exchangeRate;
        await dbService.updateProfitCenter(item);
      } else if (item is MainCategory) {
        item.name = name.trim();
        item.balance = balance;
        item.currency = currency;
        item.exchangeRate = exchangeRate;
        await dbService.updateMainCategory(item);
      } else if (item is SubCategory) {
        item.name = name.trim();
        item.balance = balance;
        item.currency = currency;
        item.exchangeRate = exchangeRate;
        await dbService.updateSubCategory(item);
      }
      if (mounted) _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Güncelleme başarısız: $e'), backgroundColor: AppColors.error));
    }
  }
}

// ── Grup Kartı Bileşeni ───────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final String name;
  final double balance;
  final String currency;
  final double? exchangeRate;
  final bool isSelected;
  final bool hasChildren;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _GroupCard({
    required this.name,
    required this.balance,
    required this.currency,
    this.exchangeRate,
    this.isSelected = false,
    this.hasChildren = false,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _hovered = false;

  void _showContextMenu(Offset offset) {
    if (widget.onEdit == null && widget.onDelete == null) return;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx + 1, offset.dy + 1),
      items: [
        if (widget.onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Düzenle')]),
          ),
        if (widget.onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [Icon(Icons.delete_outline, size: 20, color: AppColors.error), SizedBox(width: 8), Text('Sil', style: TextStyle(color: AppColors.error))]),
          ),
      ],
    ).then((value) {
      if (value == 'edit') widget.onEdit?.call();
      if (value == 'delete') widget.onDelete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isForeign = widget.currency != 'TL';
    final balanceTL = (isForeign && widget.exchangeRate != null) ? widget.balance * widget.exchangeRate! : null;

    return GestureDetector(
      onSecondaryTapDown: (details) => _showContextMenu(details.globalPosition),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 3),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : _hovered
                    ? AppColors.primary.withValues(alpha: 0.03)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : _hovered
                      ? AppColors.border.withValues(alpha: 0.8)
                      : AppColors.border,
            ),
          ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // İkon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.hasChildren ? Icons.folder : Icons.circle,
                  size: widget.hasChildren ? 16 : 8,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              // İsim + Bakiye
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                        color: widget.isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(widget.balance, currency: widget.currency),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.balance >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                    if (isForeign && balanceTL != null)
                      Text(
                        '≈ ${CurrencyFormatter.format(balanceTL, currency: 'TL')}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // 3 Nokta Menüsü (Hover ile görünür)
              if (widget.onEdit != null || widget.onDelete != null)
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: InkWell(
                    onTapDown: (details) => _showContextMenu(details.globalPosition),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                
              if (widget.hasChildren)
                const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
