import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/form_helpers.dart';
import '../models/profit_center.dart';
import '../models/project.dart';
import '../models/land.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/supabase_database_service.dart';
import '../utils/app_spacing.dart';
import '../utils/currency_formatter.dart';
import 'projects/project_detail_screen.dart';

/// Portföy hiyerarşisinin giriş ekranı: kar merkezi -> proje.
/// Kar merkezi basit bir gruplamadır (isim + açıklama); projeler bir kar
/// merkezine bağlıdır. Proje detayında arsalar (ürünler) ve projeye sermaye
/// koyan yatırımcılar yönetilir.
class ProfitCentersScreen extends StatefulWidget {
  const ProfitCentersScreen({super.key});

  @override
  State<ProfitCentersScreen> createState() => _ProfitCentersScreenState();
}

class _ProfitCentersScreenState extends State<ProfitCentersScreen> {
  final DatabaseService dbService = SupabaseDatabaseService();
  bool _isLoading = false;
  bool _isFirstLoad = true;
  List<ProfitCenter> _profitCenters = [];
  List<Project> _projects = [];
  List<Land> _lands = [];
  // Alış işlemleri: proje/kar merkezi maliyet rozetleri bunlardan hesaplanır
  List<TransactionModel> _purchases = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final centers = await dbService.getProfitCenters();
      final projects = await dbService.getProjects();
      final lands = await dbService.getLands();
      final transactions = await dbService.getTransactions();
      if (!mounted) return;
      setState(() {
        _profitCenters = centers;
        _projects = projects;
        _lands = lands;
        _purchases = transactions
            .where((t) => t.transactionType == TransactionType.purchase)
            .toList();
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

  // ── Kar merkezi ekle / düzenle / sil ────────────────────────────────────────

  void _showAddEditCenterDialog([ProfitCenter? existing]) {
    final isEditing = existing != null;

    String name = existing?.name ?? '';
    String description = existing?.description ?? '';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(isEditing ? 'Kar Merkezi Düzenle' : 'Yeni Kar Merkezi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: buildInputDecoration('Kar Merkezi Adı'),
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

                final center = ProfitCenter(
                  id: isEditing ? existing.id : '',
                  userId: isEditing ? existing.userId : '',
                  name: name.trim(),
                  description: description.trim().isEmpty ? null : description.trim(),
                );

                try {
                  if (isEditing) {
                    await dbService.updateProfitCenter(center);
                  } else {
                    await dbService.addProfitCenter(center);
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

  Future<void> _deleteCenter(ProfitCenter center) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text('${center.name} kar merkezi silinecek.'),
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
        await dbService.deleteProfitCenter(center.id);
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

  // ── Proje ekle / düzenle / sil ──────────────────────────────────────────────

  void _showAddEditProjectDialog(ProfitCenter center, [Project? existing]) {
    final isEditing = existing != null;

    String name = existing?.name ?? '';
    String description = existing?.description ?? '';
    // Düzenlemede proje başka bir kar merkezine taşınabilir.
    String profitCenterId = existing?.profitCenterId ?? center.id;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Proje Düzenle' : 'Yeni Proje (${center.name})'),
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
                  if (isEditing) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: profitCenterId,
                      decoration: buildInputDecoration('Kar Merkezi'),
                      items: _profitCenters
                          .map((pc) => DropdownMenuItem(value: pc.id, child: Text(pc.name)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => profitCenterId = val);
                      },
                    ),
                  ],
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

                  final project = Project(
                    id: isEditing ? existing.id : '',
                    userId: isEditing ? existing.userId : '',
                    profitCenterId: profitCenterId,
                    name: name.trim(),
                    description: description.trim().isEmpty ? null : description.trim(),
                  );

                  try {
                    if (isEditing) {
                      await dbService.updateProject(project);
                    } else {
                      await dbService.addProject(project);
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
        });
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

  Future<void> _openProjectDetail(Project project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
    );
    _loadData();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Kar Merkezleri', icon: Icons.account_tree_outlined),
      body: _isFirstLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                _profitCenters.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_tree_outlined, size: 64, color: AppColors.border),
                            const SizedBox(height: AppSpacing.lg),
                            const Text('Kayıtlı kar merkezi bulunamadı.',
                                style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Sağ alttaki "Kar Merkezi Ekle" düğmesiyle başlayın.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: _profitCenters.length,
                        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final center = _profitCenters[index];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: _buildCenterCard(center),
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
        onPressed: () => _showAddEditCenterDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Kar Merkezi Ekle'),
      ),
    );
  }

  /// Verilen projelerin toplam maliyeti (alış işlemlerinden, para birimine göre).
  String? _costLabelFor(Set<String> projectIds) {
    final totals = <String, double>{};
    for (final p in _purchases) {
      if (p.projectId == null || !projectIds.contains(p.projectId)) continue;
      totals[p.currency] = (totals[p.currency] ?? 0) + p.amount;
    }
    if (totals.isEmpty) return null;
    return totals.entries
        .map((e) => CurrencyFormatter.format(e.value, currency: e.key))
        .join(' + ');
  }

  Widget _buildCenterCard(ProfitCenter center) {
    final centerProjects = _projects.where((p) => p.profitCenterId == center.id).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final centerProjectIds = centerProjects.map((p) => p.id).toSet();
    final costLabel = _costLabelFor(centerProjectIds);

    return Card(
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
          child: const Icon(Icons.account_tree_outlined, color: AppColors.primary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showAddEditCenterDialog(center);
                    break;
                  case 'delete':
                    _deleteCenter(center);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: Colors.amber),
                    SizedBox(width: AppSpacing.sm),
                    Text('Düzenle', style: TextStyle(color: Colors.amber)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    SizedBox(width: AppSpacing.sm),
                    Text('Sil'),
                  ]),
                ),
              ],
            ),
            const Icon(Icons.expand_more, color: AppColors.textSecondary),
          ],
        ),
        title: Text(center.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  '${centerProjects.length} proje',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
              if (costLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Maliyet: $costLabel',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              if (center.description != null && center.description!.isNotEmpty)
                Text(
                  center.description!,
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

                if (centerProjects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('Bu kar merkezine ait proje bulunamadı.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ...centerProjects.map((project) => _buildProjectTile(center, project)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: () => _showAddEditProjectDialog(center),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Proje Ekle'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectTile(ProfitCenter center, Project project) {
    final projectLands = _lands.where((l) => l.projectId == project.id).toList();
    final costLabel = _costLabelFor({project.id});

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListTile(
        onTap: () => _openProjectDetail(project),
        contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.business, color: AppColors.primary, size: 18),
        ),
        title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${projectLands.length} arsa'
          '${costLabel != null ? '  •  Maliyet: $costLabel' : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'detail':
                    _openProjectDetail(project);
                    break;
                  case 'edit':
                    _showAddEditProjectDialog(center, project);
                    break;
                  case 'delete':
                    _deleteProject(project);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'detail',
                  child: Row(children: [
                    Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Text('Arsalar & Yatırımcılar'),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: Colors.amber),
                    SizedBox(width: AppSpacing.sm),
                    Text('Projeyi Düzenle', style: TextStyle(color: Colors.amber)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    SizedBox(width: AppSpacing.sm),
                    Text('Projeyi Sil'),
                  ]),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
