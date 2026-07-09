import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/form_section_card.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/form_helpers.dart';
import '../../utils/number_input_formatter.dart';
import '../../utils/currency_formatter.dart';
import '../../models/land.dart';
import '../../models/project_investor.dart';
import '../../models/land_sale.dart';
import '../../models/contact.dart';
import '../../models/account.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';

/// Arsa satış formu: satış tutarı + o günkü dolar kuru + tarih + alıcı +
/// GELİRİN GİRECEĞİ KASA + kullanıcının kendine ayırdığı KAR YÜZDESİ.
///
/// Satış + kasa girişi tek Postgres transaction'ında kaydedilir
/// (create_land_sale_with_cash RPC). Dağıtım yüzdesi girilmez: kar payı
/// düşüldükten sonra kalan tutar, proje yatırımcılarına SERMAYE ORANLARINA
/// göre dağıtılır ve yatırımcılara BORÇ olarak cari bakiyelerine yansır.
/// Buradaki liste canlı önizlemedir; kalıcı hesaplamayı DB yapar
/// (fn_distribute_land_sale -- uygulamanın dağıtım tablosuna yazma yetkisi yok).
///
/// Satış tutarı TL olduğundan yalnızca TRY kasalar seçilebilir.
class LandSaleForm extends StatefulWidget {
  final Land land;
  final List<ProjectInvestor> investors;

  const LandSaleForm({super.key, required this.land, required this.investors});

  @override
  State<LandSaleForm> createState() => _LandSaleFormState();
}

class _LandSaleFormState extends State<LandSaleForm> {
  final DatabaseService _db = SupabaseDatabaseService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  final _priceController = TextEditingController();
  final _rateController = TextEditingController();
  final _ownerProfitPctController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _saleDate = DateTime.now();
  String? _buyerContactId;
  String? _accountId;
  List<Contact> _contacts = [];
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _rateController.dispose();
    _ownerProfitPctController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final contacts = await _db.getContacts();
      final accounts = await _db.getAccounts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        // Satış tutarı TL: yalnızca TRY kasalar seçilebilir (para birimi
        // uyumu DB'de de denetlenir -- fn_validate_ledgers).
        _accounts = accounts.where((a) => a.currency == 'TRY').toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  double? get _salePrice => parseFormattedNumber(_priceController.text);
  double? get _usdRate => parseFormattedNumber(_rateController.text);
  double get _ownerProfitPct => parseFormattedNumber(_ownerProfitPctController.text) ?? 0;

  /// Sermayesi olan yatırımcılar (dağıtıma girecekler)
  List<ProjectInvestor> get _fundedInvestors =>
      widget.investors.where((i) => i.totalCapitalTry > 0).toList();

  double get _totalCapital =>
      _fundedInvestors.fold(0.0, (s, i) => s + i.totalCapitalTry);

  Future<void> _save() async {
    final price = _salePrice;
    final rate = _usdRate;
    final pct = _ownerProfitPct;

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Geçerli bir satış tutarı girin.')));
      return;
    }
    if (rate == null || rate <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Geçerli bir dolar kuru girin.')));
      return;
    }
    if (pct < 0 || pct > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kar yüzdesi 0-100 aralığında olmalı.')));
      return;
    }
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satış gelirinin gireceği kasayı seçin.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sale = LandSale(
        id: '',
        landId: widget.land.id,
        salePriceTry: price,
        usdRate: rate,
        ownerProfitPct: pct,
        saleDate: _saleDate,
        buyerContactId: _buyerContactId,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      // Satış + kasa girişi tek Postgres transaction'ında; dağıtımı DB
      // trigger'ı sermaye oranlarına göre yazar.
      await _db.createLandSale(sale, accountId: _accountId!);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Satış kaydedildi: tutar kasaya girdi, arsa "Satıldı" oldu, yatırımcı payları borç olarak yazıldı.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt Hatası: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _salePrice;
    final rate = _usdRate;
    final usd = (price != null && rate != null && rate > 0) ? price / rate : null;
    final pct = _ownerProfitPct;
    final pctOk = pct >= 0 && pct <= 100;
    final ownerProfit = (price != null && pctOk) ? price * pct / 100 : null;
    final distributable =
        (price != null && ownerProfit != null) ? price - ownerProfit : null;
    final totalCapital = _totalCapital;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: 'Satış Kaydet -- ${widget.land.title}', icon: Icons.sell),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: _isLoading,
            child: Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FormSectionCard(
                          title: 'Satış Bilgileri',
                          icon: Icons.sell_outlined,
                          children: [
                            TextFormField(
                              controller: _priceController,
                              decoration: buildInputDecoration('Satış Tutarı (₺)'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [ThousandSeparatorInputFormatter()],
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _rateController,
                              decoration:
                                  buildInputDecoration('O Günkü Dolar Kuru (USD/TRY)'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [ThousandSeparatorInputFormatter()],
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.md),
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
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _saleDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => _saleDate = picked);
                              },
                              child: InputDecorator(
                                decoration: buildInputDecoration('Satış Tarihi'),
                                child: Text(_fmtDate(_saleDate)),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            // Satış geliri bu kasaya 'Satış' işlemi olarak girer
                            // (satış + kasa girişi tek transaction'da kaydedilir).
                            DropdownButtonFormField<String>(
                              initialValue: _accountId,
                              decoration:
                                  buildInputDecoration('Kasa (Gelirin Gireceği Hesap)'),
                              items: _accounts
                                  .map((a) => DropdownMenuItem(
                                      value: a.id, child: Text('${a.name} (TL)')))
                                  .toList(),
                              onChanged: (val) => setState(() => _accountId = val),
                            ),
                            if (_accounts.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: AppSpacing.sm),
                                child: Text(
                                  'TL kasa bulunamadı. Satış tutarı TL olduğundan önce '
                                  'TL bir kasa/hesap açmalısınız.',
                                  style:
                                      TextStyle(fontSize: 12, color: AppColors.error),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<String>(
                              initialValue: _buyerContactId,
                              decoration: buildInputDecoration('Alıcı (opsiyonel)'),
                              items: [
                                const DropdownMenuItem<String>(
                                    value: null, child: Text('Seçilmedi')),
                                ..._contacts.map((c) =>
                                    DropdownMenuItem(value: c.id, child: Text(c.name))),
                              ],
                              onChanged: (val) => setState(() => _buyerContactId = val),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: buildInputDecoration('Açıklama'),
                              maxLines: 2,
                            ),
                          ],
                        ),
                        FormSectionCard(
                          title: 'Kar Payı & Dağıtım',
                          icon: Icons.pie_chart_outline,
                          children: [
                            const Text(
                              'Kendinize ayıracağınız kar yüzdesini girin. Kalan tutar, '
                              'yatırımcılara projeye koydukları sermaye oranında otomatik '
                              'dağıtılır ve size BORÇ olarak cari bakiyelerine yazılır.',
                              style:
                                  TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _ownerProfitPctController,
                              decoration: buildInputDecoration('Kar Yüzdem (%)'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [ThousandSeparatorInputFormatter()],
                              onChanged: (_) => setState(() {}),
                            ),
                            if (!pctOk) ...[
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                'Kar yüzdesi 0-100 aralığında olmalı.',
                                style: TextStyle(fontSize: 12, color: AppColors.error),
                              ),
                            ],
                            if (ownerProfit != null && ownerProfit > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Kar payınız: ${CurrencyFormatter.format(ownerProfit, currency: 'TRY')}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                distributable == null
                                    ? 'Dağıtılacak tutar: satış tutarını girin'
                                    : 'Dağıtılacak tutar: ${CurrencyFormatter.format(distributable, currency: 'TRY')}',
                                style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (_fundedInvestors.isEmpty)
                              const Text(
                                'Projede sermaye ödemesi olan yatırımcı yok -- satış '
                                'kaydedilirse tutar kimseye dağıtılmaz.',
                                style: TextStyle(fontSize: 12, color: AppColors.warning),
                              )
                            else
                              ..._fundedInvestors.map((inv) {
                                final ratio = totalCapital > 0
                                    ? inv.totalCapitalTry / totalCapital
                                    : 0.0;
                                final share = distributable != null && distributable > 0
                                    ? distributable * ratio
                                    : null;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inv.contact?.name ?? 'Yatırımcı',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600, fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Sermaye: ${CurrencyFormatter.format(inv.totalCapitalTry, currency: 'TRY')}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '%${CurrencyFormatter.formatAmount(ratio * 100)}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          share != null
                                              ? CurrencyFormatter.format(share,
                                                  currency: 'TRY')
                                              : '--',
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: _isLoading ? null : _save,
                          icon: const Icon(Icons.check),
                          label: const Text('Satışı Kaydet'),
                        ),
                      ],
                    ),
                  ),
                ),
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
