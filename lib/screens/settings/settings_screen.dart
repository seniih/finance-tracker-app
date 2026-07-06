import 'package:flutter/material.dart';
import '../../models/contact_models.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  List<ContactTypeModel> _contactTypes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final types = await dbService.getContactTypes();
      if (!mounted) return;
      setState(() {
        _contactTypes = types;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _showAddTypeDialog() {
    String newTypeName = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Yeni Cari Türü Ekle', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Tür Adı (Örn: Personel, Ortak)',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => newTypeName = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newTypeName.trim().isEmpty) return;
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  final newType = ContactTypeModel(id: '', name: newTypeName.trim());
                  await dbService.addContactType(newType);
                  _loadData();
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ekleme hatası: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Ekle', style: TextStyle(color: AppColors.sidebarText)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteContactType(String typeName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Türü Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"$typeName" türünü silmek istediğinize emin misiniz?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await dbService.deleteContactType(typeName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tür başarıyla silindi.'), backgroundColor: AppColors.success));
        _loadData();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        // Hata mesajını (Exception'dan gelen mesajı) direkt gösteriyoruz
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring('Exception: '.length);
        }
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Silme İşlemi Başarısız', style: TextStyle(color: AppColors.error)),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: const Icon(Icons.settings_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.lg),
              Text('Sistem Ayarları', style: Theme.of(context).textTheme.headlineLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Cari Türü Yönetimi',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddTypeDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Tür Ekle'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.md),
                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator()))
                else if (_contactTypes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text('Henüz cari türü eklenmemiş.', style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _contactTypes.length,
                    separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final type = _contactTypes[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        title: Text(type.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => _deleteContactType(type.name),
                          tooltip: 'Bu türü sil',
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
