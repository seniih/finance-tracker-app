import 'package:flutter/material.dart';
import '../../models/safe_models.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'transaction_form_utils.dart';

class TransferForm extends StatefulWidget {
  const TransferForm({super.key});

  @override
  State<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<TransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _draft = _TransferDraft();
  bool _isSaving = false;

  List<Safe> _safes = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<Safe> safes = [];

    try { safes = await dbService.getSafes(); } catch (e) { debugPrint('Kasalar yüklenemedi: $e'); }

    if (mounted) {
      setState(() {
        _safes = safes;
        _isLoadingData = false;
      });
    }
  }

  static const List<String> _typeOptions = ['TL', 'Dolar', 'Euro', 'Gram Altın', 'Cumhuriyet Altını'];

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
                  child: const Icon(Icons.swap_horiz, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(
                  'Kasa Transfer İşlemi',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxl),

            // Bölüm 1: Transfer Bilgileri
            _SectionHeader(title: '1. Transfer Detayları', icon: Icons.account_balance_wallet_outlined),
            const SizedBox(height: AppSpacing.lg),
            FormRow(children: [
              buildAutocomplete(
                'Gönderen Kasa',
                _draft.fromAccount,
                _currentSafeList,
                (val) {
                  setState(() {
                    _draft.fromAccount = val;
                    try {
                      final safe = _safes.firstWhere((s) => s.name == val);
                      _draft.currency = safe.currency;
                    } catch (_) {}
                  });
                },
              ),
              buildAutocomplete(
                'Alan Kasa',
                _draft.toAccount,
                _currentSafeList,
                (val) {
                  setState(() {
                    _draft.toAccount = val;
                    try {
                      final safe = _safes.firstWhere((s) => s.name == val);
                      _draft.currency = safe.currency;
                    } catch (_) {}
                  });
                },
              ),
            ]),
            const SizedBox(height: AppSpacing.xxl),
            FormRow(children: [
              buildAutocomplete(
                'Para Birimi',
                _draft.currency,
                _typeOptions,
                (val) => setState(() => _draft.currency = val),
              ),
              buildTextField('Tutar', (val) => _draft.amount = val, isNumber: true),
            ]),
            const SizedBox(height: AppSpacing.xxxl),

            // Bölüm 2: Açıklama
            _SectionHeader(title: '2. Açıklama', icon: Icons.notes_outlined),
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
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(
                        'Transferi Kaydet',
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
      final fromSafe = _safes.firstWhere((s) => s.name == _draft.fromAccount);
      if (fromSafe.currency != _draft.currency) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderen kasanın para birimi ile işlemin para birimi eşleşmiyor.'), backgroundColor: AppColors.error));
        return;
      }
    } catch (_) {}

    try {
      final toSafe = _safes.firstWhere((s) => s.name == _draft.toAccount);
      if (toSafe.currency != _draft.currency) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alan kasanın para birimi ile işlemin para birimi eşleşmiyor.'), backgroundColor: AppColors.error));
        return;
      }
    } catch (_) {}

    setState(() => _isSaving = true);

    final transactionData = {
      'type': 'transfer',
      'from_account_id': _draft.fromAccount != null ? _safes.firstWhere((s) => s.name == _draft.fromAccount).id : null,
      'main_account_id': _draft.toAccount != null ? _safes.firstWhere((s) => s.name == _draft.toAccount).id : null,
      'currency': _draft.currency,
      'amount': double.tryParse(_draft.amount ?? '0') ?? 0,
      'description': _draft.description,
      'date': DateTime.now().toIso8601String(),
    };

    try {
      await dbService.saveTransaction(transactionData);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer başarıyla kaydedildi!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _isSaving = false;
        _formKey.currentState!.reset();
        _draft.fromAccount = null;
        _draft.toAccount = null;
        _draft.currency = null;
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

class _TransferDraft {
  String? fromAccount;
  String? toAccount;
  String? currency;
  String? amount;
  String? description;
}
