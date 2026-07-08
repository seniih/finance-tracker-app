import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../models/category.dart';
import '../utils/constants.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/form_helpers.dart';
import '../services/database_service.dart';
import '../services/supabase_database_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final DatabaseService dbService = SupabaseDatabaseService();
  bool _isLoading = false;
  bool _isFirstLoad = true;
  List<Category> _allCategories = [];

  /// null: tümü, aksi halde yalnızca o tipteki kategoriler listelenir.
  CategoryType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await dbService.getCategories();
      if (!mounted) return;
      setState(() {
        _allCategories = categories;
        _isLoading = false;
        _isFirstLoad = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Kapat',
              onPressed: () {},
            ),
          )
        );
      }
    }
  }

  void _showAddEditDialog([Category? existingCategory, Category? parentCategory]) {
    final isEditing = existingCategory != null;

    String name = existingCategory?.name ?? '';
    // Alt kategori eklerken tip, ebeveynden geliyor (iş kuralı: alt kategori
    // ebeveynle aynı tipte olmalı). Bunun dışında hiçbir şey otomatik seçili
    // gelmemeli.
    CategoryType? selectedType = existingCategory?.type ?? parentCategory?.type;
    String? selectedParentId = existingCategory?.parentId ?? parentCategory?.id;
    String? errorText;

    // Sadece en üst düzey (parent_id == null) kategoriler ebeveyn olabilir
    final availableParents = _allCategories.where((c) => c.parentId == null && c.id != existingCategory?.id).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Kategori Düzenle' : 'Yeni Kategori Ekle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<CategoryType>(
                      decoration: buildInputDecoration('Kategori Tipi'),
                      initialValue: selectedType,
                      hint: const Text('Seçiniz'),
                      items: CategoryType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedType = val;
                          // Tip değiştiyse ebeveyni sıfırla çünkü ebeveyn ve alt kategori aynı tipte olmalı
                          selectedParentId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      decoration: buildInputDecoration('Ana Kategori (İsteğe Bağlı)'),
                      initialValue: selectedParentId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Yok (Ana Kategori Yap)')),
                        ...availableParents
                            .where((c) => c.type == selectedType) // Sadece aynı tipteki ana kategoriler seçilebilir
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) => setDialogState(() => selectedParentId = val),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: name,
                      decoration: buildInputDecoration('Kategori Adı'),
                      onChanged: (val) => name = val,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(errorText!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (name.trim().isEmpty) {
                      setDialogState(() => errorText = 'Lütfen kategori adı girin.');
                      return;
                    }
                    if (selectedType == null) {
                      setDialogState(() => errorText = 'Lütfen kategori tipi seçin.');
                      return;
                    }
                    Navigator.pop(context);
                    setState(() => _isLoading = true);

                    final newCategory = Category(
                      id: isEditing ? existingCategory.id : '',
                      userId: isEditing ? existingCategory.userId : '',
                      name: name.trim(),
                      type: selectedType!,
                      parentId: selectedParentId,
                    );

                    try {
                      if (isEditing) {
                        await dbService.updateCategory(newCategory);
                      } else {
                        await dbService.addCategory(newCategory);
                      }
                      _loadData();
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: 'Kapat',
                              onPressed: () {},
                            ),
                          )
                        );
                      }
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text('${category.name} kategorisi silinecek.'),
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

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await dbService.deleteCategory(category.id);
        _loadData();
      } on DependencyException catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  Color _getTypeColor(CategoryType type) {
    return switch (type) {
      CategoryType.income => AppColors.success,
      CategoryType.expense => AppColors.error,
    };
  }

  IconData _getTypeIcon(CategoryType type) {
    return switch (type) {
      CategoryType.income => Icons.arrow_downward_rounded,
      CategoryType.expense => Icons.arrow_upward_rounded,
    };
  }

  /// Üstteki "Tümü / Gelir / Gider" filtre çipleri.
  Widget _buildFilterBar() {
    final incomeCount = _allCategories.where((c) => c.type == CategoryType.income).length;
    final expenseCount = _allCategories.where((c) => c.type == CategoryType.expense).length;

    ChoiceChip chip(String label, CategoryType? value, Color color) {
      final selected = _typeFilter == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _typeFilter = value),
        selectedColor: color.withValues(alpha: 0.15),
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? color : AppColors.border),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? color : AppColors.textSecondary,
        ),
        showCheckmark: false,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          chip('Tümü (${incomeCount + expenseCount})', null, AppColors.primary),
          chip('Gelir ($incomeCount)', CategoryType.income, AppColors.success),
          chip('Gider ($expenseCount)', CategoryType.expense, AppColors.error),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentCategories = _allCategories
        .where((c) => c.parentId == null)
        .where((c) => _typeFilter == null || c.type == _typeFilter)
        .toList()
      ..sort((a, b) {
        // Önce gelirler, sonra giderler; kendi içinde alfabetik.
        final t = a.type.index.compareTo(b.type.index);
        return t != 0 ? t : a.name.compareTo(b.name);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Kategoriler', icon: Icons.category),
      body: _isFirstLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                parentCategories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 64, color: AppColors.border),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              _typeFilter == null
                                  ? 'Kayıtlı kategori bulunamadı.'
                                  : 'Bu tipte kategori bulunamadı.',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: parentCategories.length + 1,
                        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: _buildFilterBar(),
                              ),
                            );
                          }
                          final parentCat = parentCategories[index - 1];
                          final children = _allCategories.where((c) => c.parentId == parentCat.id).toList()
                            ..sort((a, b) => a.name.compareTo(b.name));
                          final typeColor = _getTypeColor(parentCat.type);

                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            color: AppColors.surface,
                            child: ExpansionTile(
                              backgroundColor: AppColors.surface,
                              collapsedBackgroundColor: AppColors.surface,
                              tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                              shape: const RoundedRectangleBorder(side: BorderSide.none),
                              collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                              leading: CircleAvatar(
                                backgroundColor: typeColor.withValues(alpha: 0.1),
                                child: Icon(_getTypeIcon(parentCat.type), color: typeColor),
                              ),
                              title: Text(parentCat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text(parentCat.type.label, style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.w600)),
                                    ),
                                    if (children.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Text(
                                          '${children.length} alt kategori',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              children: [
                                Container(
                                  color: AppColors.background,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _showAddEditDialog(parentCat),
                                              icon: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                                              label: const Text('Düzenle', style: TextStyle(color: AppColors.primary)),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              onPressed: () => _deleteCategory(parentCat),
                                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                                              label: const Text('Sil', style: TextStyle(color: AppColors.error)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1, color: AppColors.border),
                                      if (children.isNotEmpty)
                                        ...children.map((child) => Container(
                                              decoration: const BoxDecoration(
                                                border: Border(bottom: BorderSide(color: AppColors.border)),
                                              ),
                                              child: ListTile(
                                                dense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 2),
                                                leading: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.6), shape: BoxShape.circle),
                                                ),
                                                minLeadingWidth: 16,
                                                title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                                      onPressed: () => _showAddEditDialog(child),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                                      onPressed: () => _deleteCategory(child),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl, vertical: AppSpacing.lg),
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: const BorderSide(color: AppColors.primary),
                                            minimumSize: const Size(double.infinity, 44),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () => _showAddEditDialog(null, parentCat),
                                          icon: const Icon(Icons.add, size: 20),
                                          label: const Text('Alt Kategori Ekle'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                            ),
                          );
                        },
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
        label: const Text('Kategori Ekle'),
      ),
    );
  }
}
