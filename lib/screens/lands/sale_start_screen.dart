import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import '../../models/land.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';
import 'land_sale_form.dart';

/// Sidebar'dan "Satış" için giriş ekranı: satılmamış arsalar listelenir,
/// seçilen arsa için satış formu (LandSaleForm) açılır. Satış her zaman
/// arsa bazlıdır; form projenin yatırımcılarını sermaye oranlı dağıtım
/// önizlemesi için kullanır.
class SaleStartScreen extends StatefulWidget {
  const SaleStartScreen({super.key});

  @override
  State<SaleStartScreen> createState() => _SaleStartScreenState();
}

class _SaleStartScreenState extends State<SaleStartScreen> {
  final DatabaseService _db = SupabaseDatabaseService();

  bool _isLoading = false;
  bool _isFirstLoad = true;
  List<Land> _unsoldLands = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final lands = await _db.getLands();
      if (!mounted) return;
      setState(() {
        _unsoldLands = lands.where((l) => l.status != LandStatus.sold).toList()
          ..sort((a, b) => a.title.compareTo(b.title));
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

  Future<void> _startSale(Land land) async {
    if (land.projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bu arsa bir projeye bağlı değil; satış için önce projeye taşıyın.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Dağıtım önizlemesi için projenin yatırımcıları (sermayeleriyle)
      final investors = await _db.getProjectInvestors(land.projectId!);
      if (!mounted) return;
      setState(() => _isLoading = false);
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => LandSaleForm(land: land, investors: investors)),
      );
      if (result == true) _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Satış -- Arsa Seç', icon: Icons.sell_outlined),
      body: _isFirstLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                _unsoldLands.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.landscape_outlined, size: 64, color: AppColors.border),
                            const SizedBox(height: AppSpacing.lg),
                            const Text('Satılabilecek arsa bulunamadı.',
                                style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Önce Kar Merkezleri > proje altına arsa ekleyin.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: _unsoldLands.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final land = _unsoldLands[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: ListTile(
                                  onTap: () => _startSale(land),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg, vertical: 4),
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.landscape_outlined,
                                        color: AppColors.primary, size: 18),
                                  ),
                                  title: Text(land.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text(
                                    '${land.project?.name ?? 'Projesiz'}'
                                    '${land.purchasePrice != null ? '  •  Alış: ${CurrencyFormatter.format(land.purchasePrice!, currency: 'TRY')}' : ''}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  trailing: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Sat',
                                          style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      SizedBox(width: 4),
                                      Icon(Icons.chevron_right,
                                          color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
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
