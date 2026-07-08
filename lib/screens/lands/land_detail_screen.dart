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
import '../../models/land_contact.dart';
import '../../models/land_investment.dart';
import '../../models/land_sale.dart';
import '../../models/contact.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';
import 'land_sale_form.dart';

/// Arsa detay ekranı: yatırımcılar (ortaklık yüzdesi, ödemeler, USD
/// karşılıkları), satış kaydı ve yüzdelik dağıtım burada yönetilir.
///
/// Veri modeli özeti:
///   land_contacts      -> arsanın yatırımcısı (% ortaklık)
///   land_investments   -> yatırımcının tek tek ödemeleri (TL + kur + USD)
///   land_sales         -> satış kaydı (TL + kur + USD)
///   land_sale_distributions -> satışın kullanıcı yüzdeleriyle dağıtımı
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
  List<LandContact> _investors = [];
  List<Contact> _allContacts = [];
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
      final investors = await _db.getLandContacts(_land.id);
      final contacts = await _db.getContacts();
      final sale = await _db.getLandSale(_land.id);

      // Arsa durumu satış trigger'ıyla değişmiş olabilir -- yerelde senkron tut.
      final lands = await _db.getLands(projectId: _land.projectId);
      final freshLand = lands.where((l) => l.id == _land.id).toList();

      if (!mounted) return;
      setState(() {
        _investors = investors
          ..sort((a, b) => (b.sharePercentage ?? 0).compareTo(a.sharePercentage ?? 0));
        _allContacts = contacts;
        _sale = sale;
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

  double get _totalSharePercentage =>
      _investors.fold(0.0, (s, i) => s + (i.sharePercentage ?? 0));

  double get _totalPaidTry => _investors.fold(0.0, (s, i) => s + i.totalPaidTry);

  double get _totalPaidUsd => _investors.fold(0.0, (s, i) => s + i.totalPaidUsd);

  bool get _isSold => _sale != null;

  // ── Yatırımcı ekle / düzenle ────────────────────────────────────────────────

  void _showAddEditInvestorDialog([LandContact? existing]) {
    final isEditing = existing != null;

    String? contactId = existing?.contactId;
    String shareStr =
        existing?.sharePercentage != null ? formatNumberForInput(existing!.sharePercentage!) : '';
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
                      initialValue: shareStr,
                      decoration: buildInputDecoration('Ortaklık Yüzdesi (%)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [ThousandSeparatorInputFormatter()],
                      onChanged: (val) => shareStr = val,
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
                  final share = parseFormattedNumber(shareStr);
                  if (share != null && (share < 0 || share > 100)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Yüzde 0-100 aralığında olmalı.')));
                    return;
                  }
                  // Toplam ortaklık %100'ü aşmasın
                  final othersTotal = _investors
                      .where((i) => i.id != existing?.id)
                      .fold(0.0, (s, i) => s + (i.sharePercentage ?? 0));
                  if (share != null && othersTotal + share > 100.001) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Toplam ortaklık %100\'ü aşıyor (diğerleri: %${CurrencyFormatter.formatAmount(othersTotal)}).')));
                    return;
                  }
                  Navigator.pop(dialogCtx);
                  setState(() => _isLoading = true);

                  final lc = LandContact(
                    id: existing?.id ?? '',
                    landId: _land.id,
                    contactId: contactId!,
                    role: existing?.role ?? 'investor',
                    sharePercentage: share,
                    notes: notes.trim().isEmpty ? null : notes.trim(),
                  );

                  try {
                    if (isEditing) {
                      await _db.updateLandContact(lc);
                    } else {
                      await _db.addLandContact(lc);
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

  Future<void> _deleteInvestor(LandContact investor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text(
            '${investor.contact?.name ?? 'Yatırımcı'} bu arsadan çıkarılacak. Tüm ödeme kayıtları da silinir.'),
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
      await _db.deleteLandContact(investor.id);
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

  // ── Ödeme ekle / sil ────────────────────────────────────────────────────────

  void _showAddPaymentDialog(LandContact investor) {
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
            title: Text('Ödeme Ekle -- ${investor.contact?.name ?? ''}'),
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

                  final investment = LandInvestment(
                    id: '',
                    landContactId: investor.id,
                    amountTry: amount,
                    usdRate: rate,
                    paymentDate: paymentDate,
                    description: description.trim().isEmpty ? null : description.trim(),
                  );

                  try {
                    await _db.addLandInvestment(investment);
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

  Future<void> _deletePayment(LandInvestment investment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text(
            '${_fmtDate(investment.paymentDate)} tarihli ${CurrencyFormatter.format(investment.amountTry, currency: 'TRY')} tutarındaki ödeme silinecek.'),
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
      await _db.deleteLandInvestment(investment.id);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // ── Satış ───────────────────────────────────────────────────────────────────

  Future<void> _openSaleForm() async {
    if (_investors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Satış kaydetmeden önce en az bir yatırımcı ekleyin.')));
      return;
    }
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
            'Satış ve tüm dağıtım kayıtları silinecek, arsa tekrar "Portföyde" durumuna dönecek.'),
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
                        _buildInvestorsSection(),
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
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.md,
            children: [
              _summaryItem('Alış Fiyatı',
                  _land.purchasePrice != null
                      ? CurrencyFormatter.format(_land.purchasePrice!, currency: 'TRY')
                      : '--'),
              _summaryItem('Toplam Yatırım',
                  CurrencyFormatter.format(_totalPaidTry, currency: 'TRY')),
              _summaryItem('Toplam Yatırım (USD)',
                  CurrencyFormatter.format(_totalPaidUsd, currency: 'USD')),
              _summaryItem('Ortaklık Toplamı',
                  '%${CurrencyFormatter.formatAmount(_totalSharePercentage)}'),
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
                  onPressed: _isSold ? null : () => _showAddEditInvestorDialog(),
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

  Widget _buildInvestorTile(LandContact investor) {
    final name = investor.contact?.name ?? 'Bilinmeyen Cari';

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
            if (investor.sharePercentage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '%${CurrencyFormatter.formatAmount(investor.sharePercentage!)} ortak',
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
            '${CurrencyFormatter.format(investor.totalPaidTry, currency: 'TRY')}'
            '${investor.totalPaidUsd > 0 ? '  •  ${CurrencyFormatter.format(investor.totalPaidUsd, currency: 'USD')}' : ''}'
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
                if (!_isSold)
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
                    child: Text('Henüz ödeme kaydı yok.',
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
                            if (!_isSold)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppColors.error),
                                onPressed: () => _deletePayment(inv),
                              ),
                          ],
                        ),
                      )),
                if (!_isSold)
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
                      if (sale.buyer != null) _summaryItem('Alıcı', sale.buyer!.name),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    'DAĞITIM',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...sale.distributions.map((d) {
                    final investorName = d.landContact?.contact?.name ??
                        _investors
                            .where((i) => i.id == d.landContactId)
                            .map((i) => i.contact?.name)
                            .firstOrNull ??
                        'Yatırımcı';
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
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '%${CurrencyFormatter.formatAmount(d.percentage)}',
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
