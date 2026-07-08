import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/form_section_card.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/form_helpers.dart';
import '../../utils/number_input_formatter.dart';
import '../../utils/currency_formatter.dart';
import '../../models/land.dart';
import '../../models/land_contact.dart';
import '../../models/land_sale.dart';
import '../../models/land_sale_distribution.dart';
import '../../models/contact.dart';
import '../../services/database_service.dart';
import '../../services/supabase_database_service.dart';

/// Arsa satış formu: satış tutarı + o günkü dolar kuru + tarih + alıcı,
/// ardından satış tutarının yatırımcılara YÜZDE bazlı dağıtımı.
///
/// Dağıtım yüzdeleri kullanıcı tarafından girilir (varsayılan olarak
/// ortaklık yüzdeleriyle doldurulur ama serbestçe değiştirilebilir --
/// yatırımcılar arasındaki anlaşmaya göre farklı olabilir). Pay tutarları
/// canlı önizlemedir; kalıcı hesaplamayı DB trigger'ı yapar
/// (sale_price_try * percentage / 100). Yüzde toplamı 100'ü aşamaz.
class LandSaleForm extends StatefulWidget {
  final Land land;
  final List<LandContact> investors;

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
  final _descriptionController = TextEditingController();
  DateTime _saleDate = DateTime.now();
  String? _buyerContactId;
  List<Contact> _contacts = [];

  /// land_contact_id -> yüzde alanı controller'ı
  late final Map<String, TextEditingController> _pctControllers;

  @override
  void initState() {
    super.initState();
    // Varsayılan dağıtım = ortaklık yüzdesi; kullanıcı değiştirebilir.
    _pctControllers = {
      for (final inv in widget.investors)
        inv.id: TextEditingController(
          text: inv.sharePercentage != null
              ? formatNumberForInput(inv.sharePercentage!)
              : '',
        ),
    };
    _loadContacts();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _rateController.dispose();
    _descriptionController.dispose();
    for (final c in _pctControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _db.getContacts();
      if (!mounted) return;
      setState(() => _contacts = contacts);
    } catch (_) {
      // Alıcı seçimi opsiyonel -- liste yüklenemezse form yine kullanılabilir.
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  double? get _salePrice => parseFormattedNumber(_priceController.text);
  double? get _usdRate => parseFormattedNumber(_rateController.text);

  double get _totalPercentage => _pctControllers.values
      .fold(0.0, (s, c) => s + (parseFormattedNumber(c.text) ?? 0));

  Future<void> _save() async {
    final price = _salePrice;
    final rate = _usdRate;

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

    final total = _totalPercentage;
    if (total > 100.001) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Dağıtım yüzdelerinin toplamı %100\'ü aşamaz (şu an: %${CurrencyFormatter.formatAmount(total)}).')));
      return;
    }

    // %100'den az dağıtım teknik olarak mümkün (kalan pay şirkete kalabilir)
    // ama muhtemelen bir giriş hatasıdır -- kullanıcıya soralım.
    if (total < 99.999) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dağıtım %100 değil'),
          content: Text(
              'Yüzdelerin toplamı %${CurrencyFormatter.formatAmount(total)}. Kalan %${CurrencyFormatter.formatAmount(100 - total)} kimseye dağıtılmayacak. Devam edilsin mi?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Düzelt')),
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

    setState(() => _isLoading = true);

    try {
      final sale = LandSale(
        id: '',
        landId: widget.land.id,
        salePriceTry: price,
        usdRate: rate,
        saleDate: _saleDate,
        buyerContactId: _buyerContactId,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      // Yüzdesi 0 veya boş olan yatırımcılar dağıtıma dahil edilmez.
      final distributions = <LandSaleDistribution>[];
      for (final inv in widget.investors) {
        final pct = parseFormattedNumber(_pctControllers[inv.id]!.text);
        if (pct != null && pct > 0) {
          distributions.add(LandSaleDistribution(
            id: '',
            landSaleId: '',
            landContactId: inv.id,
            percentage: pct,
          ));
        }
      }

      await _db.createLandSale(sale, distributions);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Satış kaydedildi, arsa "Satıldı" durumuna alındı.')));
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
    final total = _totalPercentage;
    final totalOk = total <= 100.001;

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
                          title: 'Yüzdelik Dağıtım',
                          icon: Icons.pie_chart_outline,
                          trailing: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (totalOk ? AppColors.success : AppColors.error)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Toplam: %${CurrencyFormatter.formatAmount(total)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: totalOk ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                          children: [
                            const Text(
                              'Satış tutarı aşağıdaki yüzdelere göre paylaştırılır. '
                              'Varsayılan değerler ortaklık yüzdeleridir, serbestçe değiştirebilirsiniz.',
                              style:
                                  TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ...widget.investors.map((inv) {
                              final pct =
                                  parseFormattedNumber(_pctControllers[inv.id]!.text);
                              final share = (pct != null && price != null)
                                  ? price * pct / 100
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
                                          if (inv.sharePercentage != null)
                                            Text(
                                              'Ortaklık: %${CurrencyFormatter.formatAmount(inv.sharePercentage!)}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _pctControllers[inv.id],
                                        decoration: buildInputDecoration('Pay (%)'),
                                        keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true),
                                        inputFormatters: [
                                          ThousandSeparatorInputFormatter()
                                        ],
                                        onChanged: (_) => setState(() {}),
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
