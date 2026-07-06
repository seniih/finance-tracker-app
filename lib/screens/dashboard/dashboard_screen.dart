import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/safe_models.dart';
import '../../models/contact_models.dart';
import 'widgets/dashboard_sidebar.dart';
import 'widgets/dashboard_content.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedRoute = 'transaction_alis';
  Safe? _selectedSafe;
  Contact? _selectedContact;

  static const List<MenuItem> _menuItems = [
    MenuItem(label: 'İŞLEMLER', isHeader: true),
    MenuItem(route: 'transaction_alis', label: 'Alış', icon: Icons.shopping_cart_outlined),
    MenuItem(route: 'transaction_satis', label: 'Satış', icon: Icons.sell_outlined),
    MenuItem(route: 'transaction_transfer', label: 'Transfer', icon: Icons.swap_horiz),
    MenuItem(route: 'transaction_odeme', label: 'Ödeme', icon: Icons.payment),
    MenuItem(route: 'transaction_tahsilat', label: 'Tahsilat', icon: Icons.account_balance_wallet_outlined),
    MenuItem(label: 'RAPORLAR', isHeader: true),
    MenuItem(route: 'transactions_history', label: 'İşlem Geçmişi', icon: Icons.history),
    MenuItem(route: 'incomes', label: 'Gelirler', icon: Icons.trending_up),
    MenuItem(route: 'expenses', label: 'Giderler', icon: Icons.trending_down),
    MenuItem(route: 'profit_center_charts', label: 'Kar Merkezi Grafikleri', icon: Icons.pie_chart_outline_rounded),
    MenuItem(label: 'YÖNETİM', isHeader: true),
    MenuItem(route: 'profit_centers', label: 'Kar Merkezleri', icon: Icons.business_center),
    MenuItem(route: 'safes', label: 'Kasalar', icon: Icons.account_balance_wallet),
    MenuItem(label: 'CARİ', isHeader: true),
    MenuItem(route: 'contacts', label: 'Cariler', icon: Icons.people),
    MenuItem(label: 'SİSTEM', isHeader: true),
    MenuItem(route: 'settings', label: 'Ayarlar', icon: Icons.settings),
  ];

  void _onRouteSelected(String route) {
    setState(() {
      _selectedRoute = route;
      _selectedSafe = null;
      _selectedContact = null;
    });
  }

  void _onSafeSelected(Safe? safe) {
    setState(() {
      _selectedRoute = 'safes';
      _selectedSafe = safe;
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
              await Supabase.instance.client.auth.signOut();
              // AuthWrapper stream'i session kapandığında LoginPage'e yönlendirir.
            },
          ),
          Expanded(
            child: Scaffold(
              body: SafeArea(
                child: DashboardContent(
                  selectedRoute: _selectedRoute,
                  selectedSafe: _selectedSafe,
                  selectedContact: _selectedContact,
                  onSafeAdded: () => setState(() {}),
                  onSafeSelected: _onSafeSelected,
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
