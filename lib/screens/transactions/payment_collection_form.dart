import 'package:flutter/material.dart';
import '../../models/safe_models.dart';
import '../../models/contact_models.dart';
import '../../models/category_models.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'transaction_form_utils.dart';

class PaymentCollectionForm extends StatefulWidget {
  final bool isPayment;

  const PaymentCollectionForm({super.key, required this.isPayment});

  @override
  State<PaymentCollectionForm> createState() => _PaymentCollectionFormState();
}

enum TargetType { contact, category }

class _PaymentCollectionFormState extends State<PaymentCollectionForm> {
  final _formKey = GlobalKey<FormState>();
  final _draft = _PaymentDraft();
  bool _isSaving = false;
  TargetType _targetType = TargetType.contact;

  List<Safe> _safes = [];
  List<ContactTypeModel> _contactTypes = [];
  List<Contact> _allContacts = [];
  List<ProfitCenter> _profitCenters = [];
  bool _isLoadingData = true;

  ProfitCenter? _selectedProfitCenter;
  MainCategory? _selectedMainCategory;
  String? _selectedContactType; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<Safe> safes = [];
    List<ContactTypeModel> contactTypes = [];
    List<Contact> allContacts = [];
    List<ProfitCenter> profitCenters = [];

    try { safes = await dbService.getSafes(); } catch (e) { debugPrint('Kasalar yüklenemedi: $e'); }
    try { contactTypes = await dbService.getContactTypes(); } catch (e) { debugPrint('Cari türleri yüklenemedi: $e'); }
    try { allContacts = await dbService.getContacts(); } catch (e) { debugPrint('Cariler yüklenemedi: $e'); }
    try { profitCenters = await dbService.getProfitCenters(); } catch (e) { debugPrint('Kar Merkezleri yüklenemedi: $e'); }

    if (mounted) {
      setState(() {
        _safes = safes;
        _contactTypes = contactTypes;
        _allContacts = allContacts;
        _profitCenters = profitCenters;
        _isLoadingData = false;
      });
    }
  }

  static const List<String> _typeOptions = ['TL', 'Dolar', 'Euro', 'Gram Altın', 'Cumhuriyet Altını'];

  List<String> get _currentContactList {
    if (_selectedContactType == null) return [];
    return _allContacts.where((c) {
      if (c.type != _selectedContactType) return false;
      if (_draft.currency != null && _draft.currency!.isNotEmpty && c.currency != _draft.currency) return false;
      return true;
    }).map((c) => c.name).toList();
  }

  List<String> get _currentSafeList {
    if (_draft.currency == null || _draft.currency!.isEmpty) {
      return _safes.map((s) => s.name).toList();
    }
    return _safes.where((s) => s.currency == _draft.currency).map((s) => s.name).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: Icon(
                    widget.isPayment ? Icons.payment : Icons.account_balance_wallet_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(
                  widget.isPayment ? 'Yeni Ödeme Kaydı' : 'Yeni Tahsilat Kaydı',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxl),

            // Bölüm 1: Kasa Bilgileri
            _SectionHeader(title: '1. Kasa Bilgileri', icon: Icons.account_balance_wallet_outlined),
            const SizedBox(height: AppSpacing.lg),
            FormRow(children: [
              buildAutocomplete(
                'Kasa',
                _draft.account,
                _currentSafeList,
                (val) {
                  setState(() {
                    _draft.account = val;
                    try {
                      final safe = _safes.firstWhere((s) => s.name == val);
                      _draft.currency = safe.currency;
                    } catch (_) {}
                  });
                },
              ),
              buildAutocomplete(
                'Para Birimi',
                _draft.currency,
                _typeOptions,
                (val) => setState(() => _draft.currency = val),
              ),
            ]),
            const SizedBox(height: AppSpacing.xxl),
            buildTextField('Tutar', (val) => _draft.amount = val, isNumber: true),
            const SizedBox(height: AppSpacing.xxxl),

            // İşlem Hedefi Seçimi
            _SectionHeader(title: '2. İşlem Hedefi', icon: Icons.ads_click),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TargetType>(
                segments: const [
                  ButtonSegment(
                    value: TargetType.contact,
                    label: Text('Cariye (Müşteri/Tedarikçi)'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment(
                    value: TargetType.category,
                    label: Text('Kategoriye (Masraf/Gelir)'),
                    icon: Icon(Icons.category_outlined),
                  ),
                ],
                selected: {_targetType},
                onSelectionChanged: (Set<TargetType> newSelection) {
                  setState(() {
                    _targetType = newSelection.first;
                    if (_targetType == TargetType.contact) {
                      // Clear category selections
                      _draft.profitCenter = null;
                      _draft.mainCategory = null;
                      _draft.subCategory = null;
                      _selectedProfitCenter = null;
                      _selectedMainCategory = null;
                    } else {
                      // Clear contact selections
                      _selectedContactType = null;
                      _draft.contactName = null;
                    }
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),

            if (_targetType == TargetType.category) ...[
              // Bölüm 3: Kar Merkezi
              _SectionHeader(title: '3. Kategori Detayları', icon: Icons.category_outlined),
              const SizedBox(height: AppSpacing.lg),
              FormRow(children: [
                buildAutocomplete(
                  'Kar Merkezi',
                  _draft.profitCenter,
                  _profitCenters.map((pc) => pc.name).toList(),
                  (val) {
                    setState(() {
                      _draft.profitCenter = val;
                      try {
                        _selectedProfitCenter = _profitCenters.firstWhere((pc) => pc.name == val);
                      } catch (_) {
                        _selectedProfitCenter = null;
                      }
                      _selectedMainCategory = null;
                      _draft.mainCategory = null;
                      _draft.subCategory = null;
                    });
                  },
                  isRequired: false,
                ),
                buildAutocomplete(
                  'Ana Kategori',
                  _draft.mainCategory,
                  _selectedProfitCenter?.mainCategories.map((mc) => mc.name).toList() ?? [],
                  (val) {
                    setState(() {
                      _draft.mainCategory = val;
                      if (_selectedProfitCenter != null) {
                        try {
                          _selectedMainCategory = _selectedProfitCenter!.mainCategories.firstWhere((mc) => mc.name == val);
                        } catch (_) {
                          _selectedMainCategory = null;
                        }
                      } else {
                        _selectedMainCategory = null;
                      }
                      _draft.subCategory = null;
                    });
                  },
                  key: ValueKey('mc_${_selectedProfitCenter?.name ?? "none"}'),
                  isRequired: false,
                ),
              ]),
              const SizedBox(height: AppSpacing.xxl),
              FormRow(children: [
                buildAutocomplete(
                  'Alt Kategori',
                  _draft.subCategory,
                  _selectedMainCategory?.subCategories.map((sc) => sc.name).toList() ?? [],
                  (val) => setState(() => _draft.subCategory = val),
                  key: ValueKey('sc_${_selectedMainCategory?.name ?? "none"}'),
                  isRequired: false,
                ),
                const SizedBox(),
              ]),
              const SizedBox(height: AppSpacing.xxxl),
            ] else ...[
              // Bölüm 3: Cari Bilgileri
              _SectionHeader(title: '3. Cari Bilgileri', icon: Icons.person_outline),
              const SizedBox(height: AppSpacing.lg),
              FormRow(children: [
                DropdownButtonFormField<String>(
                  decoration: buildInputDecoration('Cari Türü'),
                  initialValue: _selectedContactType,
                  hint: const Text('Seçiniz', style: TextStyle(color: AppColors.textSecondary)),
                  items: _contactTypes.map((t) => DropdownMenuItem(value: t.name, child: Text(t.name))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedContactType = val;
                      _draft.contactName = null;
                    });
                  },
                ),
                buildAutocomplete(
                  'İlgili Kişi / Kurum',
                  _draft.contactName,
                  _currentContactList,
                  (val) => setState(() => _draft.contactName = val),
                  key: ValueKey('contact_$_selectedContactType'),
                ),
              ]),
              const SizedBox(height: AppSpacing.xxxl),
            ],

            // Bölüm 4: Açıklama
            _SectionHeader(title: '4. Açıklama', icon: Icons.notes_outlined),
            const SizedBox(height: AppSpacing.lg),
            buildTextField('Açıklama (isteğe bağlı)', (val) => _draft.description = val, maxLines: 3, isRequired: false),
            const SizedBox(height: 40),

            // Kaydet Butonu
            Align(
              alignment: Alignment.centerRight,
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _saveForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.sidebarText,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: AppSpacing.xl),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.md),
                        ),
                      ),
                      icon: Icon(widget.isPayment ? Icons.payment : Icons.account_balance_wallet_outlined),
                      label: Text(
                        widget.isPayment ? 'Ödemeyi Kaydet' : 'Tahsilatı Kaydet',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.sidebarText,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Para birimi eşleşme kontrolleri
    try {
      final safe = _safes.firstWhere((s) => s.name == _draft.account);
      if (safe.currency != _draft.currency) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilen kasanın para birimi ile işlemin para birimi eşleşmiyor.'), backgroundColor: AppColors.error));
        return;
      }
    } catch (_) {}

    if (_targetType == TargetType.contact && _draft.contactName != null) {
      try {
        final contact = _allContacts.firstWhere((c) => c.name == _draft.contactName);
        if (contact.currency != _draft.currency) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilen carinin para birimi ile işlemin para birimi eşleşmiyor.'), backgroundColor: AppColors.error));
          return;
        }
      } catch (_) {}
    }

    setState(() => _isSaving = true);

    final transactionData = {
      'type': widget.isPayment ? 'payment' : 'collection',
      'main_account_id': _draft.account != null ? _safes.firstWhere((s) => s.name == _draft.account).id : null,
      'currency': _draft.currency,
      'amount': double.tryParse(_draft.amount ?? '0') ?? 0,
      'profit_center_id': _draft.profitCenter != null ? _profitCenters.firstWhere((p) => p.name == _draft.profitCenter).id : null,
      'main_category_id': _draft.mainCategory != null ? _selectedProfitCenter?.mainCategories.firstWhere((m) => m.name == _draft.mainCategory).id : null,
      'sub_category_id': _draft.subCategory != null ? _selectedMainCategory?.subCategories.firstWhere((s) => s.name == _draft.subCategory).id : null,
      'contact_id': _draft.contactName != null ? _allContacts.firstWhere((c) => c.name == _draft.contactName).id : null,
      'contact_type': _selectedContactType,
      'description': _draft.description,
      'date': DateTime.now().toIso8601String(),
    };

    try {
      await dbService.saveTransaction(transactionData);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.isPayment ? "Ödeme" : "Tahsilat"} başarıyla kaydedildi!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isSaving = false;
        _formKey.currentState!.reset();
        _selectedContactType = null;
        _selectedProfitCenter = null;
        _selectedMainCategory = null;
        _draft.account = null;
        _draft.currency = null;
        _draft.contactName = null;
        _draft.profitCenter = null;
        _draft.mainCategory = null;
        _draft.subCategory = null;
        _draft.amount = null;
        _draft.description = null;
      });
    } on PostgrestException catch (pe) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      String errorMessage = pe.message;
      if (pe.code == '42P01') {
        errorMessage = 'Tablo bulunamadı. Lütfen docs/transactions_setup.sql dosyasını Supabase\'de çalıştırın.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veritabanı hatası: $errorMessage'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beklenmeyen hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _PaymentDraft {
  String? account;
  String? currency;
  String? contactName;
  String? profitCenter;
  String? mainCategory;
  String? subCategory;
  String? amount;
  String? description;
}
