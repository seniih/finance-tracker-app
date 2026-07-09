import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/form_helpers.dart';
import '../../utils/number_input_formatter.dart';
import '../../utils/currency_formatter.dart';
import '../../models/project.dart';
import '../../models/land.dart';
import '../../models/project_investor.dart';
import '../../models/project_investment.dart';
import '../../models/contact.dart';
import '../../models/transaction.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';
import '../transactions/forms/investment_in_form.dart';
import '../transactions/forms/investment_out_form.dart';
import '../transactions/forms/purchase_form.dart';
import '../lands/land_detail_screen.dart';

/// Proje detay ekranı: projenin ürünleri (arsalar) ve projeye sermaye
/// koyan yatırımcılar burada yönetilir.
///
/// Veri modeli özeti:
///   lands               -> projenin ürünleri (alınıp satılan arsalar)
///   project_investors   -> projenin yatırımcıları
///   project_investments -> yatırımcının sermaye ödemeleri (TL + kur + USD)
///   transactions(purchase) -> alışlar: kasadan çıkan her tür proje harcaması;
///                             proje maliyeti = bunların toplamı (arsa ayrımı yok)
///
/// Ortaklık oranı elle girilmez; sermaye ödemelerinden türetilir. Arsa
/// satışlarında (satış - kullanıcının kar payı) bu oranlara göre DB
/// tarafından otomatik dağıtılır.
class ProjectDetailScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final DatabaseService _db = SupabaseDatabaseService();

  bool _isLoading = false;
  bool _isFirstLoad = true;

  List<Land> _lands = [];
  List<ProjectInvestor> _investors = [];
  List<Contact> _allContacts = [];
  List<TransactionModel> _purchases = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final lands = await _db.getLands(projectId: widget.project.id);
      final investors = await _db.getProjectInvestors(widget.project.id);
      final contacts = await _db.getContacts();
      // Alışlar: projenin 'purchase' işlemleri (maliyet bunlardan hesaplanır)
      final transactions = await _db.getTransactions(projectId: widget.project.id);
      final purchases = transactions
          .where((t) => t.transactionType == TransactionType.purchase)
          .toList();

      if (!mounted) return;
      setState(() {
        _lands = lands..sort((a, b) => a.title.compareTo(b.title));
        _investors = investors
          ..sort((a, b) => b.totalCapitalTry.compareTo(a.totalCapitalTry));
        _allContacts = contacts;
        _purchases = purchases;
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

  double get _totalCapitalTry => _investors.fold(0.0, (s, i) => s + i.totalCapitalTry);

  double get _totalCapitalUsd => _investors.fold(0.0, (s, i) => s + i.totalCapitalUsd);

  /// Proje maliyeti: alış işlemlerinin para birimine göre toplamı.
  Map<String, double> get _costByCurrency {
    final totals = <String, double>{};
    for (final p in _purchases) {
      totals[p.currency] = (totals[p.currency] ?? 0) + p.amount;
    }
    return totals;
  }

  String get _costLabel {
    final costs = _costByCurrency;
    if (costs.isEmpty) return '--';
    return costs.entries
        .map((e) => CurrencyFormatter.format(e.value, currency: e.key))
        .join('  +  ');
  }

  /// Yatırımcının sermaye oranı (%) -- toplam sermaye 0 ise null.
  double? _capitalShare(ProjectInvestor inv) {
    final total = _totalCapitalTry;
    if (total <= 0) return null;
    return inv.totalCapitalTry / total * 100;
  }

  // ── Yatırımcı ekle / düzenle / sil ──────────────────────────────────────────

  void _showAddEditInvestorDialog([ProjectInvestor? existing]) {
    final isEditing = existing != null;

    String? contactId = existing?.contactId;
    String notes = existing?.notes ?? '';

    // Zaten yatırımcı olan cariler tekrar seçilemesin (düzenlemede kendisi hariç)
    final usedContactIds = _investors
        .where((i) => i.id != existing?.id)
        .map((i) => i.contactId)
        .toSet();
    final selectableContacts =
        _allContacts.where((c) => !usedContactIds.contains(c.id)).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Yatırımcıyı Düzenle' : 'Yatırımcı Ekle'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: contactId,
                      decoration: buildInputDecoration('Cari (Yatırımcı)'),
                      items: selectableContacts
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: isEditing ? null : (val) => setDialogState(() => contactId = val),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      initialValue: notes,
                      decoration: buildInputDecoration('Not'),
                      maxLines: 2,
                      onChanged: (val) => notes = val,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('İptal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  if (contactId == null) return;
                  Navigator.pop(dialogCtx);
                  setState(() => _isLoading = true);

                  final investor = ProjectInvestor(
                    id: existing?.id ?? '',
                    projectId: widget.project.id,
                    contactId: contactId!,
                    notes: notes.trim().isEmpty ? null : notes.trim(),
                  );

                  try {
                    if (isEditing) {
                      await _db.updateProjectInvestor(investor);
                    } else {
                      await _db.addProjectInvestor(investor);
                    }
                    _loadData();
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Hata: $e')));
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _deleteInvestor(ProjectInvestor investor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text(
            '${investor.contact?.name ?? 'Yatırımcı'} bu projeden çıkarılacak. Tüm sermaye ödeme kayıtları da silinir.'),
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
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _db.deleteProjectInvestor(investor.id);
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

  // ── Sermaye ödemesi ekle / sil ──────────────────────────────────────────────

  void _showAddPaymentDialog(ProjectInvestor investor) {
    String amountStr = '';
    String rateStr = '';
    String description = '';
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final amount = parseFormattedNumber(amountStr);
          final rate = parseFormattedNumber(rateStr);
          final usd = (amount != null && rate != null && rate > 0) ? amount / rate : null;

          return AlertDialog(
            title: Text('Sermaye Ödemesi -- ${investor.contact?.name ?? ''}'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: buildInputDecoration('Tutar (₺)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [ThousandSeparatorInputFormatter()],
                      onChanged: (val) => setDialogState(() => amountStr = val),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      decoration: buildInputDecoration('O Günkü Dolar Kuru (USD/TRY)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [ThousandSeparatorInputFormatter()],
                      onChanged: (val) => setDialogState(() => rateStr = val),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // USD karşılığı canlı önizleme -- kayıt sırasında DB kendisi
                    // hesaplar (GENERATED kolon), burası sadece bilgilendirme.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        usd == null
                            ? 'USD karşılığı: tutar ve kuru girin'
                            : 'USD karşılığı: ${CurrencyFormatter.format(usd, currency: 'USD')}',
                        style: const TextStyle(
                            color: AppColors.info, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: paymentDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setDialogState(() => paymentDate = picked);
                      },
                      child: InputDecorator(
                        decoration: buildInputDecoration('Ödeme Tarihi'),
                        child: Text(_fmtDate(paymentDate)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      decoration: buildInputDecoration('Açıklama'),
                      onChanged: (val) => description = val,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('İptal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  final amount = parseFormattedNumber(amountStr);
                  final rate = parseFormattedNumber(rateStr);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Geçerli bir tutar girin.')));
                    return;
                  }
                  if (rate == null || rate <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Geçerli bir dolar kuru girin.')));
                    return;
                  }
                  Navigator.pop(dialogCtx);
                  setState(() => _isLoading = true);

                  final investment = ProjectInvestment(
                    id: '',
                    projectInvestorId: investor.id,
                    amountTry: amount,
                    usdRate: rate,
                    paymentDate: paymentDate,
                    description: description.trim().isEmpty ? null : description.trim(),
                  );

                  try {
                    await _db.addProjectInvestment(investment);
                    _loadData();
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Hata: $e')));
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _deletePayment(ProjectInvestment investment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text(
            '${_fmtDate(investment.paymentDate)} tarihli ${CurrencyFormatter.format(investment.amountTry, currency: 'TRY')} tutarındaki sermaye ödemesi silinecek. '
            'Varsa satış dağıtımları yeni sermaye oranlarına göre otomatik güncellenir.'),
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
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _db.deleteProjectInvestment(investment.id);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // ── Arsa ekle / düzenle / sil ───────────────────────────────────────────────

  void _showAddEditLandDialog([Land? existingLand]) {
    final isEditing = existingLand != null;

    String title = existingLand?.title ?? '';
    final existingPrice = existingLand?.purchasePrice;
    String purchasePriceStr = existingPrice != null ? formatNumberForInput(existingPrice) : '';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(isEditing ? 'Arsa Düzenle' : 'Yeni Arsa Ekle (${widget.project.name})'),
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
                  projectId: widget.project.id,
                  title: title.trim(),
                  purchasePrice: parseFormattedNumber(purchasePriceStr),
                );

                try {
                  if (isEditing) {
                    await _db.updateLand(newLand);
                  } else {
                    await _db.addLand(newLand);
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
        await _db.deleteLand(land.id);
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

  // ── Alışlar (proje maliyeti) ────────────────────────────────────────────────

  Future<void> _openPurchaseForm([TransactionModel? existing]) async {
    // Düzenlemede mevcut ledger'lar (hangi kasa kullanılmış) forma taşınır.
    final ledgers = existing != null
        ? await _db.getLedgerEntriesForTransaction(existing.id)
        : null;
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseForm(
          fixedProject: existing == null ? widget.project : null,
          existingTransaction: existing,
          existingLedgers: ledgers,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deletePurchase(TransactionModel purchase) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text(
            '${CurrencyFormatter.format(purchase.amount, currency: purchase.currency)} tutarındaki alış silinecek. '
            'Kasa hareketi de geri alınır ve proje maliyetinden düşer.'),
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
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _db.deleteTransaction(purchase.id);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // Bir arsa için yatırım girişi/çıkışı (kasa işlemi) ekler. Proje ve arsa
  // kilitli olarak forma geçilir -- kullanıcı yanlış proje/arsa seçemez.
  Future<void> _addInvestmentTransaction(Land land, {required bool isIn}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => isIn
            ? InvestmentInForm(fixedProject: widget.project, fixedLand: land)
            : InvestmentOutForm(fixedProject: widget.project, fixedLand: land),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _openLandDetail(Land land) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LandDetailScreen(land: land, project: widget.project)),
    );
    _loadData();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: widget.project.name, icon: Icons.business),
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
                        _buildSummaryCard(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildLandsSection(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildPurchasesSection(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildInvestorsSection(),
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

  Widget _buildSummaryCard() {
    final soldCount = _lands.where((l) => l.status == LandStatus.sold).length;

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
          Text(
            widget.project.profitCenter?.name ?? 'Kar Merkezi',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(widget.project.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (widget.project.description != null && widget.project.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(widget.project.description!,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.md,
            children: [
              _summaryItem('Arsa', '${_lands.length}${soldCount > 0 ? ' ($soldCount satıldı)' : ''}'),
              // Maliyet = alış işlemlerinin toplamı (arsa alış fiyatı değil)
              _summaryItem('Toplam Maliyet', _costLabel),
              _summaryItem('Toplam Sermaye',
                  CurrencyFormatter.format(_totalCapitalTry, currency: 'TRY')),
              _summaryItem('Toplam Sermaye (USD)',
                  CurrencyFormatter.format(_totalCapitalUsd, currency: 'USD')),
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

  // ── Arsalar (ürünler) ───────────────────────────────────────────────────────

  Widget _buildLandsSection() {
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
                const Icon(Icons.landscape_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'ARSALAR (${_lands.length})',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddEditLandDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Arsa Ekle'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_lands.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Text('Bu projeye ait arsa bulunamadı.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ..._lands.map(_buildLandTile),
        ],
      ),
    );
  }

  Widget _buildLandTile(Land land) {
    final (statusColor, statusIcon) = switch (land.status) {
      LandStatus.sold => (AppColors.error, Icons.sell),
      LandStatus.forSale => (AppColors.warning, Icons.storefront),
      LandStatus.purchased => (AppColors.success, Icons.check_circle_outline),
    };

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListTile(
        onTap: () => _openLandDetail(land),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.landscape_outlined, color: AppColors.primary, size: 18),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(land.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(land.status.label,
                      style: TextStyle(
                          fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              land.purchasePrice == null
                  ? '--'
                  : CurrencyFormatter.format(land.purchasePrice!, currency: 'TRY'),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'detail':
                    _openLandDetail(land);
                    break;
                  case 'invest_in':
                    _addInvestmentTransaction(land, isIn: true);
                    break;
                  case 'invest_out':
                    _addInvestmentTransaction(land, isIn: false);
                    break;
                  case 'edit':
                    _showAddEditLandDialog(land);
                    break;
                  case 'delete':
                    _deleteLand(land);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'detail',
                  child: Row(children: [
                    Icon(Icons.sell_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Text('Detay & Satış'),
                  ]),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'invest_in',
                  child: Row(children: [
                    Icon(Icons.download, size: 18, color: AppColors.investmentIn),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Yatırım Girişi Ekle'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'invest_out',
                  child: Row(children: [
                    Icon(Icons.upload, size: 18, color: AppColors.investmentOut),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Yatırım Çıkışı Ekle'),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Text('Arsayı Düzenle'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    SizedBox(width: AppSpacing.sm),
                    Text('Arsayı Sil'),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Alışlar (maliyet kalemleri) ─────────────────────────────────────────────

  Widget _buildPurchasesSection() {
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
                const Icon(Icons.shopping_cart_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'ALIŞLAR / MALİYET (${_purchases.length})',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openPurchaseForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Alış Ekle'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_purchases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Text(
                  'Henüz alış kaydı yok. Projeye yapılan her harcama (arsa alımı, '
                  'tapu, komisyon...) buradan girilir; kasadan düşer ve maliyete eklenir.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            )
          else
            ..._purchases.map(_buildPurchaseTile),
        ],
      ),
    );
  }

  Widget _buildPurchaseTile(TransactionModel purchase) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shopping_cart_outlined, color: AppColors.error, size: 18),
        ),
        title: Text(
          purchase.description?.isNotEmpty == true ? purchase.description! : 'Alış',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_fmtDate(purchase.transactionDate)}'
          '${purchase.contact != null ? '  •  ${purchase.contact!.name}' : ''}'
          '${purchase.account != null ? '  •  ${purchase.account!.name}' : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '-${CurrencyFormatter.format(purchase.amount, currency: purchase.currency)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 13),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _openPurchaseForm(purchase);
                    break;
                  case 'delete':
                    _deletePurchase(purchase);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Text('Düzenle'),
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
          ],
        ),
      ),
    );
  }

  // ── Yatırımcılar ────────────────────────────────────────────────────────────

  Widget _buildInvestorsSection() {
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
                const Icon(Icons.groups_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'YATIRIMCILAR (${_investors.length})',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddEditInvestorDialog(),
                  icon: const Icon(Icons.person_add_alt, size: 16),
                  label: const Text('Yatırımcı Ekle'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_investors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Text('Henüz yatırımcı eklenmedi.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ..._investors.map(_buildInvestorTile),
        ],
      ),
    );
  }

  Widget _buildInvestorTile(ProjectInvestor investor) {
    final name = investor.contact?.name ?? 'Bilinmeyen Cari';
    final share = _capitalShare(investor);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: AppColors.investmentIn.withValues(alpha: 0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.investmentIn, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (share != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  // Sermaye oranı: elle girilmez, ödemelerden türetilir.
                  '%${CurrencyFormatter.formatAmount(share)} sermaye',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${investor.investments.length} ödeme  •  '
            '${CurrencyFormatter.format(investor.totalCapitalTry, currency: 'TRY')}'
            '${investor.totalCapitalUsd > 0 ? '  •  ${CurrencyFormatter.format(investor.totalCapitalUsd, currency: 'USD')}' : ''}'
            '${investor.hasUnknownRatePayments ? '  •  (bazı ödemelerde kur yok)' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'payment':
                    _showAddPaymentDialog(investor);
                    break;
                  case 'edit':
                    _showAddEditInvestorDialog(investor);
                    break;
                  case 'delete':
                    _deleteInvestor(investor);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'payment',
                  child: Row(children: [
                    Icon(Icons.payments_outlined, size: 18, color: AppColors.investmentIn),
                    SizedBox(width: AppSpacing.sm),
                    Text('Ödeme Ekle'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Text('Düzenle'),
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
        children: [
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
            child: Column(
              children: [
                if (investor.investments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text('Henüz sermaye ödemesi yok.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  )
                else
                  ...investor.investments.map((inv) => ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        leading: const Icon(Icons.receipt_long_outlined,
                            size: 18, color: AppColors.textSecondary),
                        title: Text(
                          CurrencyFormatter.format(inv.amountTry, currency: 'TRY'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${_fmtDate(inv.paymentDate)}'
                          '${inv.usdRate != null ? '  •  Kur: ${CurrencyFormatter.formatAmount(inv.usdRate!)}' : '  •  Kur bilinmiyor'}'
                          '${inv.description != null ? '  •  ${inv.description}' : ''}',
                          style:
                              const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              inv.amountUsd != null
                                  ? CurrencyFormatter.format(inv.amountUsd!, currency: 'USD')
                                  : '--',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.info,
                                  fontSize: 13),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.error),
                              onPressed: () => _deletePayment(inv),
                            ),
                          ],
                        ),
                      )),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddPaymentDialog(investor),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ödeme Ekle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
