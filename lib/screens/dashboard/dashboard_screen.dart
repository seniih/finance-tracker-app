import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../../models/contact.dart';
import 'widgets/dashboard_sidebar.dart';
import 'widgets/dashboard_content.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedRoute = 'home';
  Account? _selectedAccount;
  Contact? _selectedContact;

  static const List<MenuItem> _menuItems = [
    MenuItem(route: 'home', label: 'Ana Sayfa', icon: Icons.space_dashboard_outlined),
    MenuItem(route: 'transactions_history', label: 'Tüm İşlemler', icon: Icons.list_alt),

    MenuItem(label: 'Finansal İşlemler', isHeader: true),
    MenuItem(route: 'transaction_new_expense', label: 'Gider Ekle', icon: Icons.trending_down),
    MenuItem(route: 'transaction_new_income', label: 'Gelir Ekle', icon: Icons.trending_up),
    MenuItem(route: 'transaction_new_payment', label: 'Ödeme', icon: Icons.call_made),
    MenuItem(route: 'transaction_new_collection', label: 'Tahsilat', icon: Icons.call_received),
    MenuItem(route: 'transaction_new_transfer', label: 'Yeni Transfer', icon: Icons.swap_horiz),
    // Alış: projeye harcama (kasadan çıkar, maliyete yazılır).
    // Satış: arsa seçilir, gelir kasaya girer, yatırımcılara borç dağıtılır.
    MenuItem(route: 'transaction_new_purchase', label: 'Alış', icon: Icons.shopping_cart_outlined),
    MenuItem(route: 'transaction_new_sale', label: 'Satış', icon: Icons.sell_outlined),
    // Not: Yatırım girişi/çıkışı artık Kar Merkezleri > proje detayından (ilgili arsa üzerinden) yapılıyor.

    MenuItem(label: 'Yönetim', isHeader: true),
    MenuItem(route: 'accounts', label: 'Kasalar', icon: Icons.account_balance_wallet),
    MenuItem(route: 'contacts', label: 'Cariler', icon: Icons.people),
    MenuItem(route: 'projects', label: 'Kar Merkezleri', icon: Icons.account_tree_outlined),
    MenuItem(route: 'categories', label: 'Kategoriler', icon: Icons.category),
    
    MenuItem(label: 'Sistem', isHeader: true),
    MenuItem(route: 'settings', label: 'Ayarlar', icon: Icons.settings),
  ];

  void _onRouteSelected(String route) {
    setState(() {
      _selectedRoute = route;
      _selectedAccount = null;
      _selectedContact = null;
    });
  }

  void _onAccountSelected(Account? account) {
    setState(() {
      _selectedRoute = 'accounts';
      _selectedAccount = account;
    });
  }

  void _onContactSelected(Contact? contact) {
    setState(() {
      _selectedRoute = 'contacts';
      _selectedContact = contact;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          DashboardSidebar(
            selectedRoute: _selectedRoute,
            menuItems: _menuItems,
            onRouteSelected: _onRouteSelected,
            onSignOut: () async {
              // Yanlışlıkla tıklamaya karşı onay iste.
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Çıkış yapılsın mı?'),
                  content: const Text('Oturumunuz kapatılacak.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Çıkış Yap'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await Supabase.instance.client.auth.signOut();
              }
            },
          ),
          Expanded(
            child: Scaffold(
              body: SafeArea(
                child: DashboardContent(
                  selectedRoute: _selectedRoute,
                  selectedAccount: _selectedAccount,
                  selectedContact: _selectedContact,
                  onAccountAdded: () => setState(() {}),
                  onAccountSelected: _onAccountSelected,
                  onContactChanged: () => setState(() {}),
                  onContactSelected: _onContactSelected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
