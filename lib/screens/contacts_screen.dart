import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../models/contact.dart';
import '../models/contact_type.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/supabase_database_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/form_helpers.dart';
import '../utils/contact_balance.dart';
import '../utils/currency_formatter.dart';
import '../utils/number_input_formatter.dart';
import '../utils/constants.dart';
import 'contacts/contact_detail_screen.dart';

class ContactsScreen extends StatefulWidget {
  final Contact? selectedContact;
  final VoidCallback? onContactChanged;
  final void Function(Contact?)? onContactSelected;

  const ContactsScreen({
    super.key,
    this.selectedContact,
    this.onContactChanged,
    this.onContactSelected,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final DatabaseService dbService = SupabaseDatabaseService();
  bool _isLoading = false;
  bool _isFirstLoad = true;
  List<Contact> _allContacts = [];
  List<ContactTypeModel> _contactTypes = [];
  String? _selectedTypeFilter;
  Map<String, Map<String, double>> _balancesByContact = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        dbService.getContacts(_selectedTypeFilter),
        dbService.getContactTypes(),
        // Cari borç/alacak rozetleri için: tüm işlemleri tek seferde çekip
        // client-side cariye göre grupluyoruz (her cari için ayrı sorgu atmamak için).
        dbService.getTransactions(),
        // Arsa satışlarından yatırımcılara doğan borçlar (dağıtım satırları)
        dbService.getInvestorSaleDebts(),
      ]);
      if (!mounted) return;
      setState(() {
        _allContacts = futures[0] as List<Contact>;
        _contactTypes = futures[1] as List<ContactTypeModel>;
        _balancesByContact = ContactBalanceCalculator.calculateByContact(
          futures[2] as List<TransactionModel>,
          futures[0] as List<Contact>,
          saleDebtsByContact: futures[3] as Map<String, double>,
        );
        _isLoading = false;
        _isFirstLoad = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  void _showAddEditDialog([Contact? existingContact]) {
    final isEditing = existingContact != null;

    String name = existingContact?.name ?? '';
    String? selectedTypeId = existingContact?.contactTypeId;
    String phone = existingContact?.phone ?? '';
    String email = existingContact?.email ?? '';
    String taxOffice = existingContact?.taxOffice ?? '';
    String iban = existingContact?.iban ?? '';
    String address = existingContact?.address ?? '';
    String description = existingContact?.description ?? '';

    final balanceRows = <_OpeningBalanceRow>[];
    if (existingContact != null) {
      for (final entry in existingContact.openingBalances.entries) {
        balanceRows.add(_OpeningBalanceRow(
          amountStr: formatNumberForInput(entry.value.abs()),
          currency: entry.key,
          isDebtor: entry.value >= 0,
        ));
      }
    }
    if (balanceRows.isEmpty) {
      balanceRows.add(_OpeningBalanceRow(amountStr: '', currency: 'TRY', isDebtor: true));
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Cari Düzenle' : 'Yeni Cari Ekle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_contactTypes.isEmpty)
                      const Text('Önce Ayarlardan Cari Türü Ekleyin.', style: TextStyle(color: AppColors.error)),
                    if (_contactTypes.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: buildInputDecoration('Cari Türü (Opsiyonel)'),
                        initialValue: selectedTypeId,
                        hint: const Text('Seçiniz'),
                        items: _contactTypes.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                        onChanged: (val) => setDialogState(() => selectedTypeId = val),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: name,
                      decoration: buildInputDecoration('İsim / Kurum Adı'),
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: phone,
                      decoration: buildInputDecoration('Telefon'),
                      onChanged: (val) => phone = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: email,
                      decoration: buildInputDecoration('E-posta'),
                      onChanged: (val) => email = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: taxOffice,
                      decoration: buildInputDecoration('Vergi Dairesi / VKN / TC'),
                      onChanged: (val) => taxOffice = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: iban,
                      decoration: buildInputDecoration('IBAN'),
                      onChanged: (val) => iban = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: address,
                      decoration: buildInputDecoration('Adres'),
                      onChanged: (val) => address = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: description,
                      decoration: buildInputDecoration('Açıklama'),
                      onChanged: (val) => description = val,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Açılış Bakiyesi (Devir) -- Opsiyonel',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...balanceRows.asMap().entries.map((mapEntry) {
                      final i = mapEntry.key;
                      final row = mapEntry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: ValueKey('bal_amount_${i}_${row.currency}'),
                                    initialValue: row.amountStr,
                                    decoration: buildInputDecoration('Tutar'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [ThousandSeparatorInputFormatter()],
                                    onChanged: (val) => row.amountStr = val,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey('bal_currency_${i}_${row.currency}'),
                                    decoration: buildInputDecoration('Birim'),
                                    initialValue: row.currency,
                                    items: appCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                    onChanged: (val) => setDialogState(() => row.currency = val ?? row.currency),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20, color: AppColors.error),
                                  onPressed: () => setDialogState(() => balanceRows.removeAt(i)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => row.isDebtor = true),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: row.isDebtor ? AppColors.success.withValues(alpha: 0.1) : AppColors.background,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: row.isDebtor ? AppColors.success : AppColors.border),
                                      ),
                                      child: Text(
                                        'Cari Bana Borçlu',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: row.isDebtor ? AppColors.success : AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => row.isDebtor = false),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !row.isDebtor ? AppColors.warning.withValues(alpha: 0.1) : AppColors.background,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: !row.isDebtor ? AppColors.warning : AppColors.border),
                                      ),
                                      child: Text(
                                        'Ben Cariye Borçluyum',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: !row.isDebtor ? AppColors.warning : AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (i < balanceRows.length - 1)
                              const Divider(color: AppColors.border, height: 16),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => setDialogState(() {
                        balanceRows.add(_OpeningBalanceRow(amountStr: '', currency: 'TRY', isDebtor: true));
                      }),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Başka Para Birimi Ekle'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (name.trim().isEmpty) return;
                    Navigator.pop(context);
                    setState(() => _isLoading = true);

                    // Çoklu açılış bakiyesini Map'e çevir
                    final openingBalances = <String, double>{};
                    for (final row in balanceRows) {
                      final amount = parseFormattedNumber(row.amountStr)?.abs() ?? 0.0;
                      if (amount > 0) {
                        final signed = row.isDebtor ? amount : -amount;
                        openingBalances[row.currency] = (openingBalances[row.currency] ?? 0) + signed;
                      }
                    }
                    // Sıfıra yuvarlanmış olanları temizle
                    openingBalances.removeWhere((_, v) => v.abs() < 0.005);

                    final newContact = Contact(
                      id: isEditing ? existingContact.id : '',
                      userId: isEditing ? existingContact.userId : '',
                      name: name.trim(),
                      contactTypeId: selectedTypeId,
                      phone: phone.trim().isEmpty ? null : phone.trim(),
                      email: email.trim().isEmpty ? null : email.trim(),
                      taxOffice: taxOffice.trim().isEmpty ? null : taxOffice.trim(),
                      iban: iban.trim().isEmpty ? null : iban.trim(),
                      address: address.trim().isEmpty ? null : address.trim(),
                      description: description.trim().isEmpty ? null : description.trim(),
                      openingBalances: openingBalances,
                    );

                    try {
                      if (isEditing) {
                        await dbService.updateContact(newContact);
                      } else {
                        await dbService.addContact(newContact);
                      }
                      _loadData();
                      widget.onContactChanged?.call();
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _openDetail(Contact contact) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ContactDetailScreen(contact: contact)),
    );
    if (changed == true) {
      _loadData();
      widget.onContactChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedContact != null) {
      return ContactDetailScreen(
        contact: widget.selectedContact!,
        onBack: () => widget.onContactSelected?.call(null),
        onChanged: () {
          widget.onContactChanged?.call();
          _loadData();
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Cariler', icon: Icons.people),
      body: Column(
        children: [
          // Filtre satırı
          if (_contactTypes.isNotEmpty)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Text('Filtrele:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Tümü',
                            isSelected: _selectedTypeFilter == null,
                            onTap: () {
                              setState(() => _selectedTypeFilter = null);
                              _loadData();
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ..._contactTypes.map((t) => Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.xs),
                                child: _FilterChip(
                                  label: t.name,
                                  isSelected: _selectedTypeFilter == t.id,
                                  onTap: () {
                                    setState(() => _selectedTypeFilter = t.id);
                                    _loadData();
                                  },
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: AppColors.border),
          // Liste
          Expanded(
            child: _isFirstLoad
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : Stack(
                    children: [
                      _allContacts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 64, color: AppColors.border),
                                  const SizedBox(height: AppSpacing.lg),
                                  const Text('Kayıtlı cari bulunamadı.', style: TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: _allContacts.length,
                              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final contact = _allContacts[index];
                                return _ContactCard(
                                  contact: contact,
                                  balances: _balancesByContact[contact.id] ?? const {},
                                  onTap: () {
                                    if (widget.onContactSelected != null) {
                                      widget.onContactSelected!(contact);
                                    } else {
                                      _openDetail(contact);
                                    }
                                  },
                                );
                              },
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Cari Ekle'),
      ),
    );
  }
}

// ── Filtre Chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Cari Kartı ────────────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final Contact contact;
  final Map<String, double> balances;
  final VoidCallback onTap;

  const _ContactCard({required this.contact, required this.balances, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
    final balanceEntries = balances.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (contact.contactType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(contact.contactType!.name, style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600)),
                          ),
                        if (contact.phone != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.phone_outlined, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(contact.phone!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Bakiye rozeti: kasa kartındaki (_AccountCard) "tutar + alt başlık"
              // düzeniyle birebir aynı stil -- burada birden fazla para birimi
              // olabileceğinden ilk (en büyük) tutar öne çıkarılır, diğerleri
              // altına daha küçük punto ile eklenir.
              if (balanceEntries.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < balanceEntries.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _ContactBalanceCell(entry: balanceEntries[i], prominent: i == 0),
                    ],
                  ],
                ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cari Bakiye Hücresi (_AccountCard'daki "tutar + alt başlık" stiliyle aynı) ──
class _ContactBalanceCell extends StatelessWidget {
  final MapEntry<String, double> entry;
  final bool prominent;

  const _ContactBalanceCell({required this.entry, required this.prominent});

  @override
  Widget build(BuildContext context) {
    final isDebtor = entry.value > 0; // cari bana borçlu
    final tintColor = isDebtor ? AppColors.success : AppColors.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          CurrencyFormatter.format(entry.value.abs(), currency: entry.key),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: prominent ? 15 : 13, color: tintColor),
        ),
        const SizedBox(height: 2),
        Text(
          isDebtor ? 'Borçlu' : 'Alacaklı',
          style: TextStyle(fontSize: 11, color: tintColor),
        ),
      ],
    );
  }
}

// Cari detay ekranı artık ContactDetailScreen (contacts/contact_detail_screen.dart)
// üzerinden tam sayfa olarak açılıyor -- eski bottom sheet kaldırıldı.

/// Dialog içinde çoklu açılış bakiyesi satırlarını yönetmek için
/// mutable yardımcı sınıf (contact_detail_screen'deki ile aynı desen --
/// private olduğundan her iki dosyada da ayrı tanımlı).
class _OpeningBalanceRow {
  String amountStr;
  String currency;
  bool isDebtor;

  _OpeningBalanceRow({
    required this.amountStr,
    required this.currency,
    required this.isDebtor,
  });
}
