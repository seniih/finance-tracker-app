import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/category_models.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/currency_formatter.dart';

// ─── Renk Paleti ──────────────────────────────────────────────────────────────
const _kPalette = [
  Color(0xFF61BC45),
  Color(0xFF0EA5E9),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
  Color(0xFF6366F1),
  Color(0xFF22D3EE),
];

Color _colorAt(int i) => _kPalette[i % _kPalette.length];

// ─── Ana Sayfa ─────────────────────────────────────────────────────────────────
class ProfitCenterChartsScreen extends StatefulWidget {
  const ProfitCenterChartsScreen({super.key});

  @override
  State<ProfitCenterChartsScreen> createState() =>
      _ProfitCenterChartsScreenState();
}

class _ProfitCenterChartsScreenState extends State<ProfitCenterChartsScreen> {
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
      final pcs = await dbService.getProfitCenters();
      if (mounted) setState(() => _profitCenters = pcs);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: const Icon(Icons.pie_chart_outline_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kar Merkezi Grafikleri',
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 2),
                  Text('Kategorilere göre dağılım analizi',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Yenile',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),

          // ── İçerik ──
          if (_isLoading)
            const Expanded(
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary)))
          else if (_profitCenters.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('Henüz kar merkezi eklenmemiş.',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _profitCenters.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xxl),
                itemBuilder: (context, index) =>
                    _ProfitCenterChartCard(pc: _profitCenters[index]),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Tek Kar Merkezi Kartı ─────────────────────────────────────────────────────
class _ProfitCenterChartCard extends StatefulWidget {
  final ProfitCenter pc;
  const _ProfitCenterChartCard({required this.pc});

  @override
  State<_ProfitCenterChartCard> createState() => _ProfitCenterChartCardState();
}

class _ProfitCenterChartCardState extends State<_ProfitCenterChartCard>
    with SingleTickerProviderStateMixin {
  int? _touchedIndex;
  MainCategory? _selectedMainCategory;
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  List<MainCategory> get _validMains => widget.pc.mainCategories
      .where((mc) => mc.balance.abs() > 0)
      .toList();

  List<SubCategory> get _validSubs =>
      (_selectedMainCategory?.subCategories ?? [])
          .where((sc) => sc.balance.abs() > 0)
          .toList();

  void _selectMainCategory(MainCategory? mc) {
    _animCtrl.reset();
    setState(() {
      _selectedMainCategory = mc;
      _touchedIndex = null;
    });
    _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    // items: MainCategory ya da SubCategory — ikisi de balanceInTL özelliğine sahip
    final List<dynamic> items =
        _selectedMainCategory == null ? _validMains : _validSubs;
    final total = items.fold<double>(
        0,
        (s, item) => s +
            (item is MainCategory
                ? item.balance.abs()
                : (item as SubCategory).balance.abs()));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Kart Başlığı ──
          _buildCardHeader(),
          const Divider(height: 0, color: AppColors.border),

          // ── Breadcrumb ──
          if (_selectedMainCategory != null) _buildBreadcrumb(),

          // ── Ana İçerik ──
          if (items.isEmpty)
            _buildEmpty()
          else
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sol: Pasta Grafik
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 280,
                        child: _buildPieChart(items, total),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    // Sağ: Efsane + Bar listesi
                    Expanded(
                      flex: 6,
                      child: _buildLegendList(items, total),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardHeader() {
    final balance = widget.pc.balance;
    final isPositive = balance >= 0;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.business_center_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.pc.name,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(
                  '${widget.pc.mainCategories.length} ana kategori',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(balance.abs(),
                    currency: widget.pc.currency),
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isPositive ? AppColors.success : AppColors.error),
              ),
              Text(
                isPositive ? 'Alacak' : 'Borç',
                style: TextStyle(
                    color: isPositive ? AppColors.success : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      color: AppColors.background,
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 10),
      child: Row(
        children: [
          InkWell(
            onTap: () => _selectMainCategory(null),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Ana Kategoriler',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            _selectedMainCategory!.name,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List items, double total) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.touchedSection == null) {
              if (mounted) setState(() => _touchedIndex = null);
              return;
            }
            final idx = response.touchedSection!.touchedSectionIndex;
            if (mounted) setState(() => _touchedIndex = idx);

            // Tıkla → alt kategoriye gir
            if (event is FlTapUpEvent &&
                _selectedMainCategory == null &&
                idx >= 0 &&
                idx < _validMains.length) {
              final mc = _validMains[idx];
              if (mc.subCategories.isNotEmpty) {
                _selectMainCategory(mc);
              }
            }
          },
        ),
        sectionsSpace: 3,
        centerSpaceRadius: 52,
        startDegreeOffset: -90,
        sections: List.generate(items.length, (i) {
          final item = items[i];
          final balance = item.balance.abs();
          final pct = total > 0 ? (balance / total * 100) : 0.0;
          final isTouched = _touchedIndex == i;
          return PieChartSectionData(
            color: _colorAt(i),
            value: balance * _anim.value,
            title: pct >= 8 ? '%${pct.toStringAsFixed(0)}' : '',
            titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold),
            radius: isTouched ? 88 : 76,
            titlePositionPercentageOffset: 0.65,
          );
        }),
      ),
    );
  }

  Widget _buildLegendList(List items, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedMainCategory == null
              ? 'Ana Kategoriler'
              : 'Alt Kategoriler',
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        ...List.generate(items.length, (i) {
          final item = items[i];
          final double balance = item is MainCategory
              ? item.balance.abs()
              : (item as SubCategory).balance.abs();
          final String itemCurrency = item is MainCategory
              ? item.currency
              : (item as SubCategory).currency;
          final String itemName = item is MainCategory
              ? item.name
              : (item as SubCategory).name;
          final pct = total > 0 ? balance / total : 0.0;
          final isTouched = _touchedIndex == i;

          final canDrillDown = _selectedMainCategory == null &&
              item is MainCategory &&
              item.subCategories.isNotEmpty;

          return GestureDetector(
            onTap: () {
              if (canDrillDown) {
                _selectMainCategory(item);
              } else {
                setState(() =>
                    _touchedIndex = _touchedIndex == i ? null : i);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isTouched
                    ? _colorAt(i).withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isTouched
                      ? _colorAt(i).withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _colorAt(i),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                itemName,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isTouched
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (canDrillDown) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded,
                                  size: 15, color: _colorAt(i)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct * _anim.value,
                                  backgroundColor:
                                      _colorAt(i).withValues(alpha: 0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      _colorAt(i)),
                                  minHeight: 5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '%${(pct * 100).toStringAsFixed(1)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _colorAt(i),
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    CurrencyFormatter.format(balance,
                        currency: itemCurrency),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.donut_small_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _selectedMainCategory == null
                  ? 'Bu kar merkezinde henüz kategorisi veya bakiyesi olan kategori yok.'
                  : 'Bu ana kategoride alt kategori bakiyesi bulunamadı.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
