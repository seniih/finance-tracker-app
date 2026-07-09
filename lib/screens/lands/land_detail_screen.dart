import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import '../../models/project.dart';
import '../../models/land.dart';
import '../../models/project_investor.dart';
import '../../models/land_sale.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';
import 'land_sale_form.dart';

/// Arsa detay ekranı: arsa bilgileri + satış kaydı ve dağıtımı.
///
/// Yatırımcılar artık ARSA değil PROJE seviyesinde yönetilir (proje detay
/// ekranı). Satışta kullanıcı kendi kar payını girer; kalan tutar proje
/// yatırımcılarına sermaye oranlarına göre DB tarafından otomatik dağıtılır.
class LandDetailScreen extends StatefulWidget {
  final Land land;
  final Project? project;

  const LandDetailScreen({super.key, required this.land, this.project});

  @override
  State<LandDetailScreen> createState() => _LandDetailScreenState();
}

class _LandDetailScreenState extends State<LandDetailScreen> {
  final DatabaseService _db = SupabaseDatabaseService();

  bool _isLoading = false;
  bool _isFirstLoad = true;

  late Land _land;
  List<ProjectInvestor> _investors = [];
  LandSale? _sale;

  @override
  void initState() {
    super.initState();
    _land = widget.land;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sale = await _db.getLandSale(_land.id);
      final investors = _land.projectId != null
          ? await _db.getProjectInvestors(_land.projectId!)
          : <ProjectInvestor>[];

      // Arsa durumu satış trigger'ıyla değişmiş olabilir -- yerelde senkron tut.
      final lands = await _db.getLands(projectId: _land.projectId);
      final freshLand = lands.where((l) => l.id == _land.id).toList();

      if (!mounted) return;
      setState(() {
        _sale = sale;
        _investors = investors
          ..sort((a, b) => b.totalCapitalTry.compareTo(a.totalCapitalTry));
        if (freshLand.isNotEmpty) _land = freshLand.first;
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

  // ── Yardımcılar ─────────────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  // ── Satış ───────────────────────────────────────────────────────────────────

  Future<void> _openSaleForm() async {
    final hasCapital = _investors.any((i) => i.totalCapitalTry > 0);
    if (!hasCapital) {
      // Sermaye yoksa dağıtılacak taraf da yok -- yine de satışa izin ver
      // ama kullanıcıyı bilgilendir (tüm tutar dağıtımsız kalır).
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Projede sermaye kaydı yok'),
          content: const Text(
              'Bu projede sermaye ödemesi olan yatırımcı yok. Satış kaydedilirse '
              'tutar kimseye dağıtılmaz. Devam edilsin mi?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Devam Et'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LandSaleForm(land: _land, investors: _investors)),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteSale() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Satış kaydı silinsin mi?'),
        content: const Text(
            'Satış, tüm dağıtım kayıtları (yatırımcı borçları) ve kasadaki satış '
            'geliri işlemi silinecek; arsa tekrar "Portföyde" durumuna dönecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true || _sale == null) return;

    setState(() => _isLoading = true);
    try {
      await _db.deleteLandSale(_sale!.id);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: _land.title, icon: Icons.landscape_outlined),
      body: _isFirstLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        _buildLandSummaryCard(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildSaleSection(),
                        const SizedBox(height: AppSpacing.xxxl),
                      ],
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

  Widget _buildStatusChip() {
    final status = _land.status;
    final (color, icon) = switch (status) {
      LandStatus.sold => (AppColors.error, Icons.sell),
      LandStatus.forSale => (AppColors.warning, Icons.storefront),
      LandStatus.purchased => (AppColors.success, Icons.check_circle_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(status.label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLandSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.project?.name ?? _land.project?.name ?? 'Proje',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_land.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (_land.description != null && _land.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_land.description!,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.md,
            children: [
              _summaryItem('Alış Fiyatı',
                  _land.purchasePrice != null
                      ? CurrencyFormatter.format(_land.purchasePrice!, currency: 'TRY')
                      : '--'),
              if (_land.area != null)
                _summaryItem('Alan (m²)', CurrencyFormatter.formatAmount(_land.area!)),
              if (_land.purchaseDate != null)
                _summaryItem('Alış Tarihi', _fmtDate(_land.purchaseDate!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSaleSection() {
    final sale = _sale;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.sell_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'SATIŞ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5),
                  ),
                ),
                if (sale != null)
                  TextButton.icon(
                    onPressed: _deleteSale,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Satışı Sil'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (sale == null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Text('Bu arsa henüz satılmadı.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: _openSaleForm,
                    icon: const Icon(Icons.sell),
                    label: const Text('Satış Kaydet'),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.xxl,
                    runSpacing: AppSpacing.md,
                    children: [
                      _summaryItem('Satış Tutarı',
                          CurrencyFormatter.format(sale.salePriceTry, currency: 'TRY')),
                      _summaryItem(
                          'Satış Kuru',
                          sale.usdRate != null
                              ? CurrencyFormatter.formatAmount(sale.usdRate!)
                              : '--'),
                      _summaryItem(
                          'USD Karşılığı',
                          sale.salePriceUsd != null
                              ? CurrencyFormatter.format(sale.salePriceUsd!, currency: 'USD')
                              : '--'),
                      _summaryItem('Satış Tarihi', _fmtDate(sale.saleDate)),
                      _summaryItem(
                          'Kar Payım',
                          '%${CurrencyFormatter.formatAmount(sale.ownerProfitPct)}'
                          ' (${CurrencyFormatter.format(sale.ownerProfitTry, currency: 'TRY')})'),
                      if (sale.buyer != null) _summaryItem('Alıcı', sale.buyer!.name),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    'DAĞITIM (SERMAYE ORANINA GÖRE)',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Kar payı düşüldükten sonra kalan tutar, yatırımcılara sermaye '
                    'oranlarına göre otomatik dağıtılır ve BORÇ olarak cari '
                    'bakiyelerine yazılır (Ödeme işlemiyle kapatılır). Sermaye '
                    'ödemeleri değişirse dağıtım da güncellenir.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (sale.distributions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text('Dağıtım kaydı yok (projede sermaye ödemesi bulunmuyor).',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    )
                  else
                    ...(sale.distributions.toList()
                          ..sort((a, b) => b.amountTry.compareTo(a.amountTry)))
                        .map((d) {
                      final investorName = d.projectInvestor?.contact?.name ??
                          _investors
                              .where((i) => i.id == d.projectInvestorId)
                              .map((i) => i.contact?.name)
                              .firstOrNull ??
                          'Yatırımcı';
                      final distributable = sale.salePriceTry - sale.ownerProfitTry;
                      final pct = distributable > 0 ? d.amountTry / distributable * 100 : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(investorName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            if (pct != null)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '%${CurrencyFormatter.formatAmount(pct)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            const SizedBox(width: AppSpacing.lg),
                            Text(
                              CurrencyFormatter.format(d.amountTry, currency: 'TRY'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
