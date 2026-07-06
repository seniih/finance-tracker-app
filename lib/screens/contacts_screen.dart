import 'package:flutter/material.dart';
import '../models/contact_models.dart';
import '../services/database_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/currency_formatter.dart';
import '../utils/number_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'transactions/transactions_history_screen.dart';

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
  @override
  Widget build(BuildContext context) {
    if (widget.selectedContact != null) {
      return _ContactDetailView(
        contact: widget.selectedContact!,
        onBack: () => widget.onContactSelected?.call(null),
        onContactDeleted: widget.onContactChanged,
        onContactUpdated: (updated) {
          widget.onContactSelected?.call(updated);
          widget.onContactChanged?.call();
        },
      );
    }
    return _ContactListView(
      onContactAdded: _handleContactChanged,
      onContactSelected: (c) => widget.onContactSelected?.call(c),
    );
  }

  void _handleContactChanged() {
    setState(() {});
    widget.onContactChanged?.call();
  }
}

class _ContactListView extends StatefulWidget {
  final VoidCallback onContactAdded;
  final void Function(Contact) onContactSelected;

  const _ContactListView({
    required this.onContactAdded,
    required this.onContactSelected,
  });

  @override
  State<_ContactListView> createState() => _ContactListViewState();
}

class _ContactListViewState extends State<_ContactListView> {
  bool _isLoading = false;
  List<ContactTypeModel> _contactTypes = [];
  List<Contact> _allContacts = [];
  String? _selectedTypeId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final types = await dbService.getContactTypes();
      final contacts = await dbService.getContacts();
      if (!mounted) return;
      setState(() {
        _contactTypes = types;
        _allContacts = contacts;
        if (_contactTypes.isNotEmpty && _selectedTypeId == null) {
          _selectedTypeId = _contactTypes.first.name;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _showAddContactDialog() {
    if (_contactTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen önce Ayarlar menüsünden bir Cari Türü ekleyin.'), backgroundColor: AppColors.error));
      return;
    }

    String newName = '';
    String selectedType = _selectedTypeId ?? _contactTypes.first.name;
    String phone = '';
    String tc = '';
    String address = '';
    String description = '';
    String currency = 'TL';
    String balanceStr = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Yeni Cari Ekle', style: TextStyle(color: AppColors.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Cari Türü',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                      initialValue: selectedType,
                      items: _contactTypes.map((t) => DropdownMenuItem(value: t.name, child: Text(t.name))).toList(),
                      onChanged: (val) => setDialogState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'İsim / Kurum Adı',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => newName = val,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Başlangıç Bakiyesi',
                              labelStyle: TextStyle(color: AppColors.textSecondary),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            inputFormatters: [ThousandSeparatorInputFormatter()],
                            onChanged: (val) => balanceStr = val,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Para Birimi',
                              labelStyle: TextStyle(color: AppColors.textSecondary),
                              border: OutlineInputBorder(),
                            ),
                            initialValue: currency,
                            items: const [
                              DropdownMenuItem(value: 'TL', child: Text('TL')),
                              DropdownMenuItem(value: 'USD', child: Text('Dolar')),
                              DropdownMenuItem(value: 'EUR', child: Text('Euro')),
                              DropdownMenuItem(value: 'GRAM_ALTIN', child: Text('Gram Altın')),
                              DropdownMenuItem(value: 'CUMHURIYET_ALTINI', child: Text('Cumhuriyet Altını')),
                            ],
                            onChanged: (val) => setDialogState(() => currency = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'TC No / Vergi No',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => tc = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => phone = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Adres',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => address = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => description = val,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (newName.trim().isEmpty) return;
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    final balance = parseFormattedNumber(balanceStr) ?? 0.0;
                    final newContact = Contact(
                      id: DateTime.now().toString(),
                      name: newName.trim(),
                      type: selectedType,
                      phone: phone.trim().isEmpty ? null : phone.trim(),
                      tc: tc.trim().isEmpty ? null : tc.trim(),
                      address: address.trim().isEmpty ? null : address.trim(),
                      description: description.trim().isEmpty ? null : description.trim(),
                      balance: balance,
                      currency: currency,
                    );

                    try {
                      await dbService.addContact(newContact);
                      _loadData();
                      widget.onContactAdded();
                    } on PostgrestException catch (pe) {
                      if (!context.mounted) return;
                      setState(() => _isLoading = false);
                      String errorMessage = pe.message;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error, duration: const Duration(seconds: 5)));
                    } catch (e) {
                      if (!context.mounted) return;
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: AppColors.error));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Ekle', style: TextStyle(color: AppColors.sidebarText)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _allContacts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayContacts = _selectedTypeId == null
        ? _allContacts
        : _allContacts.where((c) => c.type == _selectedTypeId).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                    ),
                    child: const Icon(Icons.people_outline, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text('Cariler', style: Theme.of(context).textTheme.headlineLarge),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddContactDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.sidebarText,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Cari Ekle'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          if (_contactTypes.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TypeTab(
                    title: 'Tümü',
                    isSelected: _selectedTypeId == null,
                    onTap: () => setState(() => _selectedTypeId = null),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ..._contactTypes.map((type) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _TypeTab(
                          title: type.name,
                          isSelected: _selectedTypeId == type.name,
                          onTap: () => setState(() => _selectedTypeId = type.name),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (displayContacts.isEmpty)
            Expanded(
              child: Center(
                child: Text('Bu türde cari bulunmuyor.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: displayContacts.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final contact = displayContacts[index];
                  return InkWell(
                    onTap: () => widget.onContactSelected(contact),
                    borderRadius: BorderRadius.circular(14),
                    child: _ContactCard(contact: contact),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeTab({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Contact contact;

  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: const Icon(Icons.person, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  contact.type,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (contact.phone != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Telefon', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  Text(contact.phone!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          else
            const Expanded(child: SizedBox()),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  contact.balance > 0
                      ? 'Alacak: ${CurrencyFormatter.format(contact.balance.abs(), currency: contact.currency)}'
                      : contact.balance < 0
                          ? 'Borç: ${CurrencyFormatter.format(contact.balance.abs(), currency: contact.currency)}'
                          : CurrencyFormatter.format(0, currency: contact.currency),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
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

class _ContactDetailView extends StatelessWidget {
  final Contact contact;
  final VoidCallback onBack;
  final VoidCallback? onContactDeleted;
  final void Function(Contact)? onContactUpdated;

  const _ContactDetailView({
    required this.contact,
    required this.onBack,
    this.onContactDeleted,
    this.onContactUpdated,
  });

  Future<void> _deleteContact(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cariyi Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"${contact.name}" carisini silmek istediğinize emin misiniz?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await dbService.deleteContact(contact);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cari başarıyla silindi.'), backgroundColor: AppColors.success));
        onContactDeleted?.call();
        onBack();
      } catch (e) {
        if (!context.mounted) return;
        // Exception mesajını düzgün göster
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring('Exception: '.length);
        }
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Silme İşlemi Başarısız', style: TextStyle(color: AppColors.error)),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              )
            ],
          ),
        );
      }
    }
  }

  Future<void> _showEditContactDialog(BuildContext context) async {
    final types = await dbService.getContactTypes();
    if (types.isEmpty) return;

    String newName = contact.name;
    String selectedType = contact.type;
    String phone = contact.phone ?? '';
    String tc = contact.tc ?? '';
    String address = contact.address ?? '';
    String description = contact.description ?? '';
    String currency = contact.currency.toUpperCase();
    final validCurrencies = ['TL', 'USD', 'EUR', 'GRAM_ALTIN', 'CUMHURIYET_ALTINI'];
    if (!validCurrencies.contains(currency)) currency = 'TL';
    
    final balanceCtrl = TextEditingController(
      text: contact.balance != 0 
          ? contact.balance.toStringAsFixed(2).replaceAll('.00', '').replaceAll('.', ',')
          : '',
    );
    final nameCtrl = TextEditingController(text: newName);
    final tcCtrl = TextEditingController(text: tc);
    final phoneCtrl = TextEditingController(text: phone);
    final addressCtrl = TextEditingController(text: address);
    final descCtrl = TextEditingController(text: description);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Cariyi Düzenle', style: TextStyle(color: AppColors.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Cari Türü',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                      initialValue: selectedType,
                      items: types.map((t) => DropdownMenuItem(value: t.name, child: Text(t.name))).toList(),
                      onChanged: (val) => setDialogState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'İsim / Kurum Adı',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: balanceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Başlangıç Bakiyesi',
                              labelStyle: TextStyle(color: AppColors.textSecondary),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            inputFormatters: [ThousandSeparatorInputFormatter()],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Para Birimi',
                              labelStyle: TextStyle(color: AppColors.textSecondary),
                              border: OutlineInputBorder(),
                            ),
                            initialValue: currency,
                            items: const [
                              DropdownMenuItem(value: 'TL', child: Text('TL')),
                              DropdownMenuItem(value: 'USD', child: Text('Dolar')),
                              DropdownMenuItem(value: 'EUR', child: Text('Euro')),
                              DropdownMenuItem(value: 'GRAM_ALTIN', child: Text('Gram Altın')),
                              DropdownMenuItem(value: 'CUMHURIYET_ALTINI', child: Text('Cumhuriyet Altını')),
                            ],
                            onChanged: (val) => setDialogState(() => currency = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tcCtrl,
                      decoration: const InputDecoration(
                        labelText: 'TC No / Vergi No',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Adres',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final balance = parseFormattedNumber(balanceCtrl.text) ?? 0.0;
                    final newContact = Contact(
                      id: contact.id,
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      tc: tcCtrl.text.trim().isEmpty ? null : tcCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      balance: balance,
                      currency: currency,
                    );
                    Navigator.pop(context);
                    await dbService.updateContact(newContact);
                    onContactUpdated?.call(newContact);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Kaydet', style: TextStyle(color: AppColors.sidebarText)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(contact.name, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(contact.type, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showEditContactDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                      foregroundColor: AppColors.warning,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('Düzenle'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: () => _deleteContact(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                      foregroundColor: AppColors.error,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Sil'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _buildInfoCol(
                  contact.balance > 0 ? 'Alacak' : contact.balance < 0 ? 'Borç' : 'Bakiye',
                  CurrencyFormatter.format(contact.balance.abs(), currency: contact.currency),
                  color: AppColors.textPrimary,
                  isBold: true,
                ),
                _buildInfoCol('Telefon', contact.phone ?? '-'),
                _buildInfoCol('TC / Vergi No', contact.tc ?? '-'),
                _buildInfoCol('Adres', contact.address ?? '-'),
              ],
            ),
          ),
          if (contact.description != null && contact.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Açıklama', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(contact.description!, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
          Text('İşlem Geçmişi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TransactionsHistoryScreen(
              filterContactId: contact.id,
              showHeader: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, {Color? color, bool isBold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value, 
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
