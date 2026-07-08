import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../utils/app_colors.dart';
import '../utils/form_helpers.dart';
import '../models/project.dart';
import '../models/land.dart';
import '../services/database_service.dart';
import '../services/supabase_database_service.dart';
import '../utils/app_spacing.dart';
import '../utils/number_input_formatter.dart';
import '../utils/currency_formatter.dart';
import 'transactions/forms/investment_in_form.dart';
import 'transactions/forms/investment_out_form.dart';
import 'lands/land_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final DatabaseService dbService = SupabaseDatabaseService();
  bool _isLoading = false;
  bool _isFirstLoad = true;
  List<Project> _projects = [];
  List<Land> _lands = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final projectsData = await dbService.getProjects();
      final landsData = await dbService.getLands();
      if (!mounted) return;
      setState(() {
        _projects = projectsData;
        _lands = landsData;
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

  void _showAddEditDialog([Project? existingProject]) {
    final isEditing = existingProject != null;
    
    String name = existingProject?.name ?? '';
    String description = existingProject?.description ?? '';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(isEditing ? 'Proje Düzenle' : 'Yeni Proje Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: buildInputDecoration('Proje Adı'),
                  onChanged: (val) => name = val,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: description,
                  decoration: buildInputDecoration('Açıklama'),
                  onChanged: (val) => description = val,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (name.trim().isEmpty) return;
                Navigator.pop(dialogCtx);
                setState(() => _isLoading = true);
                
                final newProject = Project(
                  id: isEditing ? existingProject.id : '',
                  userId: isEditing ? existingProject.userId : '',
                  name: name.trim(),
                  description: description.trim().isEmpty ? null : description.trim(),
                );

                try {
                  if (isEditing) {
                    await dbService.updateProject(newProject);
                  } else {
                    await dbService.addProject(newProject);
                  }
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text('${project.name} projesi silinecek.'),
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
        await dbService.deleteProject(project.id);
        _loadData();
      } on DependencyException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  void _showAddEditLandDialog(Project project, [Land? existingLand]) {
    final isEditing = existingLand != null;
    
    String title = existingLand?.title ?? '';
    final existingPrice = existingLand?.purchasePrice;
    String purchasePriceStr = existingPrice != null ? formatNumberForInput(existingPrice) : '';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(isEditing ? 'Arsa Düzenle' : 'Yeni Arsa Ekle (${project.name})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: title,
                  decoration: buildInputDecoration('Arsa Adı/Başlığı'),
                  onChanged: (val) => title = val,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: purchasePriceStr,
                  decoration: buildInputDecoration('Alış Fiyatı (₺)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ThousandSeparatorInputFormatter()],
                  onChanged: (val) => purchasePriceStr = val,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (title.trim().isEmpty) return;
                Navigator.pop(dialogCtx);
                setState(() => _isLoading = true);
                
                final newLand = Land(
                  id: isEditing ? existingLand.id : '',
                  userId: isEditing ? existingLand.userId : '',
                  projectId: project.id,
                  title: title.trim(),
                  purchasePrice: parseFormattedNumber(purchasePriceStr),
                );

                try {
                  if (isEditing) {
                    await dbService.updateLand(newLand);
                  } else {
                    await dbService.addLand(newLand);
                  }
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteLand(Land land) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text('${land.title} arsası silinecek.'),
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
        await dbService.deleteLand(land.id);
        _loadData();
      } on DependencyException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  // Bir arsa için yatırım girişi/çıkışı ekler. Proje ve arsa önceden
  // (fixedProject/fixedLand) belirlenmiş ve kilitli olarak forma geçilir --
  // kullanıcı yanlış proje/arsa seçemez.
  Future<void> _addInvestment(Project project, Land land, {required bool isIn}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => isIn
            ? InvestmentInForm(fixedProject: project, fixedLand: land)
            : InvestmentOutForm(fixedProject: project, fixedLand: land),
      ),
    );
    if (result == true) _loadData();
  }

  // Arsa detayı: yatırımcılar, ödemeler (TL + kur + USD) ve satış/dağıtım.
  Future<void> _openLandDetail(Project project, Land land) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LandDetailScreen(land: land, project: project)),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Projeler', icon: Icons.business),
      body: _isFirstLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                _projects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_outlined, size: 64, color: AppColors.border),
                            const SizedBox(height: AppSpacing.lg),
                            const Text('Kayıtlı proje bulunamadı.', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Sağ alttaki "Proje Ekle" düğmesiyle başlayın.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: _projects.length,
                        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final project = _projects[index];
                          final projectLands = _lands.where((l) => l.projectId == project.id).toList()
                            ..sort((a, b) => a.title.compareTo(b.title));
                          final totalPurchase = projectLands.fold<double>(0, (s, l) => s + (l.purchasePrice ?? 0));

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
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.business, color: AppColors.primary),
                              ),
                              title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        '${projectLands.length} arsa',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (totalPurchase > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Toplam alış: ${CurrencyFormatter.format(totalPurchase, currency: 'TRY')}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    if (project.description != null && project.description!.isNotEmpty)
                                      Text(
                                        project.description!,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                                              onPressed: () => _showAddEditDialog(project),
                                              icon: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                                              label: const Text('Projeyi Düzenle', style: TextStyle(color: AppColors.primary)),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              onPressed: () => _deleteProject(project),
                                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                                              label: const Text('Projeyi Sil', style: TextStyle(color: AppColors.error)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      if (projectLands.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(24.0),
                                          child: Text('Bu projeye ait arsa bulunamadı.', style: TextStyle(color: AppColors.textSecondary)),
                                        )
                                      else
                                        ...projectLands.map((land) => Container(
                                              decoration: const BoxDecoration(
                                                border: Border(bottom: BorderSide(color: AppColors.border)),
                                              ),
                                              child: ListTile(
                                              onTap: () => _openLandDetail(project, land),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                                              leading: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.landscape_outlined, color: AppColors.primary, size: 18),
                                              ),
                                              title: Text(land.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    land.purchasePrice == null
                                                        ? '--'
                                                        : CurrencyFormatter.format(land.purchasePrice!, currency: 'TRY'),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  PopupMenuButton<String>(
                                                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                                                    onSelected: (value) {
                                                      switch (value) {
                                                        case 'detail':
                                                          _openLandDetail(project, land);
                                                          break;
                                                        case 'invest_in':
                                                          _addInvestment(project, land, isIn: true);
                                                          break;
                                                        case 'invest_out':
                                                          _addInvestment(project, land, isIn: false);
                                                          break;
                                                        case 'edit':
                                                          _showAddEditLandDialog(project, land);
                                                          break;
                                                        case 'delete':
                                                          _deleteLand(land);
                                                          break;
                                                      }
                                                    },
                                                    itemBuilder: (context) => [
                                                      const PopupMenuItem(
                                                        value: 'detail',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.groups_outlined, size: 18, color: AppColors.primary),
                                                            SizedBox(width: AppSpacing.sm),
                                                            Text('Yatırımcılar & Satış'),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuDivider(),
                                                      PopupMenuItem(
                                                        value: 'invest_in',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.download, size: 18, color: AppColors.investmentIn),
                                                            const SizedBox(width: AppSpacing.sm),
                                                            const Text('Yatırım Girişi Ekle'),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'invest_out',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.upload, size: 18, color: AppColors.investmentOut),
                                                            const SizedBox(width: AppSpacing.sm),
                                                            const Text('Yatırım Çıkışı Ekle'),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuDivider(),
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                                            SizedBox(width: AppSpacing.sm),
                                                            Text('Arsayı Düzenle'),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                                            SizedBox(width: AppSpacing.sm),
                                                            Text('Arsayı Sil'),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            )),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(double.infinity, 44),
                                          ),
                                          onPressed: () => _showAddEditLandDialog(project),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Yeni Arsa Ekle'),
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
        label: const Text('Proje Ekle'),
      ),
    );
  }
}
