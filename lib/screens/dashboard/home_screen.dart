import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../accounts_screen.dart';
import '../transactions/transactions_history_screen.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../utils/constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';

const List<String> _turkishMonthsShort = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];
const List<String> _turkishMonthsFull = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
const List<String> _turkishWeekdays = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

const List<Color> _pieColors = [
  AppColors.primary,
  AppColors.info,
  AppColors.warning,
  AppColors.investmentOut,
  AppColors.investmentIn,
  AppColors.error,
  Color(0xFF64748B),
];

class _MonthBucket {
  final int year;
  final int month;
  double income = 0;
  double expense = 0;
  _MonthBucket(this.year, this.month);
}

/// Anasayfa raporlarının kapsadığı dönem. Aylık = içinde bulunulan ay,
/// Yıllık = içinde bulunulan yıl. Sayfanın tamamı (özet kartları, nakit akışı,
/// gider dağılımı) seçilen döneme göre güncellenir.
enum _ReportPeriod { month, year }

/// Ana Sayfa / Raporlar Ekranı.
/// Kasa bakiyeleri, seçilen döneme (aylık/yıllık) göre gelir/gider özeti,
/// nakit akışı grafiği, kategoriye göre gider dağılımı ve son işlemleri
/// tek ekranda gösterir.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = SupabaseDatabaseService();

  bool _isLoading = true;
  bool _isFirstLoad = true;
  String? _error;

  // Aktif rapor dönemi. Veri seti hem son 6 ayı hem de içinde bulunulan yılı
  // kapsadığından dönem değişince yeniden yükleme gerekmez; sadece türetilen
  // değerler yeniden hesaplanır.
  _ReportPeriod _period = _ReportPeriod.month;

  List<Account> _accounts = [];
  // Son 6 ayı VE içinde bulunulan yılı kapsayan işlemler (özet kartları + iki
  // grafik + son işlemler listesi hepsi bu tek veri setinden türetiliyor).
  List<TransactionModel> _rangeTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      // Aylık görünüm son 6 ayı, yıllık görünüm ise Ocak'tan bugüne kadar olan
      // dönemi gerektirir. İkisini de kapsayacak şekilde en erken tarihten
      // itibaren tek sorguda çekiyoruz.
      final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
      final yearStart = DateTime(now.year, 1, 1);
      final rangeStart = sixMonthsAgo.isBefore(yearStart) ? sixMonthsAgo : yearStart;
      final futures = await Future.wait([
        _db.getAccounts(),
        _db.getTransactions(startDate: rangeStart, endDate: now),
      ]);
      if (!mounted) return;
      setState(() {
        _accounts = futures[0] as List<Account>;
        _rangeTransactions = futures[1] as List<TransactionModel>;
        _isLoading = false;
        _isFirstLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isFirstLoad = false;
        _error = '$e';
      });
    }
  }

  // ── Hesaplamalar ─────────────────────────────────────────────────────────

  Map<String, double> _balanceByCurrency() {
    final map = <String, double>{};
    for (final a in _accounts) {
      final bal = a.currentBalance ?? a.openingBalance;
      map[a.currency] = (map[a.currency] ?? 0) + bal;
    }
    return map;
  }

  String _dominantCurrency() {
    final balances = _balanceByCurrency();
    if (balances.isEmpty) return 'TRY';
    final sorted = balances.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    return sorted.first.key;
  }

  // Bir tarih, seçili dönemin (ay veya yıl) içinde mi?
  bool _inCurrentPeriod(DateTime d) {
    final now = DateTime.now();
    if (_period == _ReportPeriod.year) return d.year == now.year;
    return d.year == now.year && d.month == now.month;
  }

  bool get _isYear => _period == _ReportPeriod.year;
  String get _periodWord => _isYear ? 'Bu Yıl' : 'Bu Ay';

  Map<String, double> _incomeByCurrencyThisPeriod() {
    final map = <String, double>{};
    for (final t in _rangeTransactions) {
      if (t.transactionType != TransactionType.standard) continue;
      if (t.category?.type != CategoryType.income) continue;
      if (!_inCurrentPeriod(t.transactionDate.toLocal())) continue;
      map[t.currency] = (map[t.currency] ?? 0) + t.amount;
    }
    return map;
  }

  Map<String, double> _expenseByCurrencyThisPeriod() {
    final map = <String, double>{};
    for (final t in _rangeTransactions) {
      if (t.transactionType != TransactionType.standard) continue;
      if (t.category?.type != CategoryType.expense) continue;
      if (!_inCurrentPeriod(t.transactionDate.toLocal())) continue;
      map[t.currency] = (map[t.currency] ?? 0) + t.amount;
    }
    return map;
  }

  List<_MonthBucket> _buildMonthlyBuckets(String currency) {
    final now = DateTime.now();
    final buckets = <_MonthBucket>[];
    final indexByKey = <String, int>{};
    if (_isYear) {
      // Yıllık görünüm: Ocak–Aralık, içinde bulunulan yıl.
      for (int m = 1; m <= 12; m++) {
        indexByKey['${now.year}-$m'] = buckets.length;
        buckets.add(_MonthBucket(now.year, m));
      }
    } else {
      // Aylık görünüm: son 6 ay.
      for (int i = 5; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        indexByKey['${d.year}-${d.month}'] = buckets.length;
        buckets.add(_MonthBucket(d.year, d.month));
      }
    }

    for (final t in _rangeTransactions) {
      if (t.transactionType != TransactionType.standard) continue;
      if (t.currency != currency) continue;
      final type = t.category?.type;
      if (type == null) continue;
      final local = t.transactionDate.toLocal();
      final idx = indexByKey['${local.year}-${local.month}'];
      if (idx == null) continue;
      if (type == CategoryType.income) {
        buckets[idx].income += t.amount;
      } else {
        buckets[idx].expense += t.amount;
      }
    }
    return buckets;
  }

  Map<String, double> _expenseByCategoryThisPeriod(String currency) {
    final map = <String, double>{};
    for (final t in _rangeTransactions) {
      if (t.transactionType != TransactionType.standard) continue;
      if (t.category?.type != CategoryType.expense) continue;
      if (t.currency != currency) continue;
      if (!_inCurrentPeriod(t.transactionDate.toLocal())) continue;
      final name = t.category?.name ?? 'Diğer';
      map[name] = (map[name] ?? 0) + t.amount;
    }
    return map;
  }

  List<MapEntry<String, double>> _topWithOther(Map<String, double> data, {int topN = 5}) {
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.length <= topN) return entries;
    final top = entries.take(topN).toList();
    final otherSum = entries.skip(topN).fold<double>(0, (s, e) => s + e.value);
    if (otherSum > 0) top.add(MapEntry('Diğer', otherSum));
    return top;
  }

  IconData _accountIcon(AccountType type) {
    return switch (type) {
      AccountType.cash => Icons.payments_outlined,
      AccountType.bank => Icons.account_balance_outlined,
      AccountType.creditCard => Icons.credit_card_outlined,
    };
  }

  String _formatFullDate(DateTime d) {
    return '${d.day} ${_turkishMonthsFull[d.month - 1]} ${d.year}, ${_turkishWeekdays[d.weekday - 1]}';
  }

  String _axisLabel(double value) {
    if (value.abs() >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Ana Sayfa',
        icon: Icons.space_dashboard_outlined,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isFirstLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildErrorState()
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final greeting = _buildGreeting();
                                final toggle = _buildPeriodToggle();
                                if (constraints.maxWidth > 520) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: greeting),
                                      toggle,
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    greeting,
                                    const SizedBox(height: AppSpacing.md),
                                    toggle,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _buildSummaryCards(),
                            const SizedBox(height: AppSpacing.xxl),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 900;
                                final cashFlow = _buildCashFlowCard();
                                final expensePie = _buildExpenseByCategoryCard();
                                if (isWide) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 3, child: cashFlow),
                                      const SizedBox(width: AppSpacing.xl),
                                      Expanded(flex: 2, child: expensePie),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    cashFlow,
                                    const SizedBox(height: AppSpacing.xl),
                                    expensePie,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 900;
                                final accountsCard = _buildAccountsCard();
                                final recentCard = _buildRecentTransactionsCard();
                                if (isWide) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 2, child: accountsCard),
                                      const SizedBox(width: AppSpacing.xl),
                                      Expanded(flex: 3, child: recentCard),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    accountsCard,
                                    const SizedBox(height: AppSpacing.xl),
                                    recentCard,
                                  ],
                                );
                              },
                            ),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
            child: Text(
              'Veriler yüklenemedi: $_error',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Genel Bakış',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(_formatFullDate(DateTime.now()), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      ],
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _periodChip('Aylık', _ReportPeriod.month),
          _periodChip('Yıllık', _ReportPeriod.year),
        ],
      ),
    );
  }

  Widget _periodChip(String label, _ReportPeriod value) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () {
        if (_period != value) setState(() => _period = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final dominant = _dominantCurrency();
    final balances = _balanceByCurrency();
    final income = _incomeByCurrencyThisPeriod();
    final expense = _expenseByCurrencyThisPeriod();

    final totalBalance = balances[dominant] ?? 0;
    final periodIncome = income[dominant] ?? 0;
    final periodExpense = expense[dominant] ?? 0;
    final net = periodIncome - periodExpense;

    final otherCurrencies = balances.keys.where((c) => c != dominant).toList();

    final cards = [
      _StatCard(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Toplam Bakiye',
        value: CurrencyFormatter.format(totalBalance, currency: dominant),
        color: totalBalance >= 0 ? AppColors.primary : AppColors.error,
      ),
      _StatCard(
        icon: Icons.trending_up,
        label: '$_periodWord Gelir',
        value: CurrencyFormatter.format(periodIncome, currency: dominant),
        color: AppColors.success,
      ),
      _StatCard(
        icon: Icons.trending_down,
        label: '$_periodWord Gider',
        value: CurrencyFormatter.format(periodExpense, currency: dominant),
        color: AppColors.error,
      ),
      _StatCard(
        icon: Icons.savings_outlined,
        label: 'Net Durum ($_periodWord)',
        value: CurrencyFormatter.format(net, currency: dominant),
        color: net >= 0 ? AppColors.success : AppColors.error,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 760;
            if (isWide) {
              // IntrinsicHeight, Row'a en uzun kart kadar SINIRLI bir yükseklik
              // verir; böylece CrossAxisAlignment.stretch kartları eşit boya
              // getirirken, dikeyde sınırsız (SingleChildScrollView) bir ortamda
              // "BoxConstraints forces an infinite height" hatası oluşmaz.
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: AppSpacing.lg),
                    ],
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i != cards.length - 1) const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
        if (otherCurrencies.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: otherCurrencies.map((c) {
              final val = balances[c] ?? 0;
              return Chip(
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                label: Text(
                  '${CurrencyFormatter.getLabel(c)}: ${CurrencyFormatter.format(val, currency: c)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCashFlowCard() {
    final dominant = _dominantCurrency();
    final buckets = _buildMonthlyBuckets(dominant);
    final hasData = buckets.any((b) => b.income != 0 || b.expense != 0);
    final maxVal = buckets.fold<double>(0, (m, b) {
      final localMax = b.income > b.expense ? b.income : b.expense;
      return localMax > m ? localMax : m;
    });
    final maxY = maxVal <= 0 ? 100.0 : maxVal * 1.25;
    final interval = maxY / 4;

    final now = DateTime.now();
    return _ChartCard(
      title: _isYear ? '${now.year} Nakit Akışı' : 'Son 6 Ay Nakit Akışı',
      subtitle: _isYear
          ? 'Aylık gelir / gider (${CurrencyFormatter.getLabel(dominant)})'
          : '${CurrencyFormatter.getLabel(dominant)} cinsinden gelir / gider',
      legend: const [
        _LegendDot(color: AppColors.success, label: 'Gelir'),
        _LegendDot(color: AppColors.error, label: 'Gider'),
      ],
      child: SizedBox(
        height: 260,
        child: !hasData
            ? _EmptyChartPlaceholder(
                message: _isYear ? 'Bu yıl işlem bulunamadı.' : 'Son 6 ayda işlem bulunamadı.')
            : BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: interval,
                        getTitlesWidget: (value, meta) => Text(
                          _axisLabel(value),
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= buckets.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _turkishMonthsShort[buckets[idx].month - 1],
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: _isYear ? 2 : 4,
                        barRods: [
                          BarChartRodData(
                            toY: buckets[i].income,
                            color: AppColors.success,
                            width: _isYear ? 7 : 12,
                            borderRadius: BorderRadius.circular(_isYear ? 2 : 4),
                          ),
                          BarChartRodData(
                            toY: buckets[i].expense,
                            color: AppColors.error,
                            width: _isYear ? 7 : 12,
                            borderRadius: BorderRadius.circular(_isYear ? 2 : 4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildExpenseByCategoryCard() {
    final dominant = _dominantCurrency();
    final data = _topWithOther(_expenseByCategoryThisPeriod(dominant));
    final total = data.fold<double>(0, (s, e) => s + e.value);

    return _ChartCard(
      title: 'Gider Dağılımı',
      subtitle: '${_isYear ? 'Bu yıl' : 'Bu ay'}, kategoriye göre (${CurrencyFormatter.getLabel(dominant)})',
      child: SizedBox(
        height: 260,
        child: total <= 0
            ? _EmptyChartPlaceholder(
                message: _isYear ? 'Bu yıl henüz gider işlenmedi.' : 'Bu ay henüz gider işlenmedi.')
            : Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          for (int i = 0; i < data.length; i++)
                            PieChartSectionData(
                              value: data[i].value,
                              color: _pieColors[i % _pieColors.length],
                              title: '${(data[i].value / total * 100).toStringAsFixed(0)}%',
                              radius: 54,
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: _pieColors[i % _pieColors.length], shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data[i].key,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAccountsCard() {
    return _SectionCard(
      title: 'Kasalar / Hesaplar',
      trailing: TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
        child: const Text('Tümünü Gör'),
      ),
      child: _accounts.isEmpty
          ? const _EmptyChartPlaceholder(message: 'Henüz hesap/kasa eklenmemiş.')
          : Column(
              children: _accounts.take(6).map((a) {
                final bal = a.currentBalance ?? a.openingBalance;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_accountIcon(a.accountType), color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          a.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(bal, currency: a.currency),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: bal >= 0 ? AppColors.textPrimary : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    final recent = _rangeTransactions.take(6).toList();
    return _SectionCard(
      title: 'Son İşlemler',
      trailing: TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsHistoryScreen())),
        child: const Text('Tümünü Gör'),
      ),
      child: recent.isEmpty
          ? const _EmptyChartPlaceholder(message: 'Henüz işlem yok.')
          : Column(
              children: recent.map((tr) {
                final isIncome = tr.transactionType == TransactionType.standard && tr.category?.type == CategoryType.income;
                final color = switch (tr.transactionType) {
                  TransactionType.standard => isIncome ? AppColors.success : AppColors.error,
                  TransactionType.transfer => AppColors.info,
                  TransactionType.investmentIn => AppColors.investmentIn,
                  TransactionType.investmentOut => AppColors.investmentOut,
                };
                final icon = switch (tr.transactionType) {
                  TransactionType.standard => isIncome ? Icons.trending_up : Icons.trending_down,
                  TransactionType.transfer => Icons.swap_horiz,
                  TransactionType.investmentIn => Icons.download,
                  TransactionType.investmentOut => Icons.upload,
                };
                final label = tr.transactionType == TransactionType.standard && tr.category != null
                    ? tr.category!.name
                    : tr.transactionType.label;
                final prefix = tr.transactionType == TransactionType.transfer
                    ? ''
                    : ((isIncome || tr.transactionType == TransactionType.investmentIn) ? '+' : '-');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              tr.transactionDate.toLocal().toString().split(' ')[0],
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$prefix${CurrencyFormatter.format(tr.amount, currency: tr.currency)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ── Yardımcı Widget'lar ────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? legend;
  final Widget child;

  const _ChartCard({required this.title, this.subtitle, this.legend, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (legend != null) Row(mainAxisSize: MainAxisSize.min, children: legend!),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  final String message;

  const _EmptyChartPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
