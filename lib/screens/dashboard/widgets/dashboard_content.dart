import 'package:flutter/material.dart';
import '../../../models/safe_models.dart';
import '../../../models/contact_models.dart';
import '../../profit_centers_screen.dart';
import '../../safes_screen.dart';
import '../../contacts_screen.dart';
import '../../settings/settings_screen.dart';

import '../../transactions/purchase_sale_form.dart';
import '../../transactions/transfer_form.dart';
import '../../transactions/payment_collection_form.dart';
import '../../transactions/transactions_history_screen.dart';
import '../../profit_center_charts_screen.dart';

class DashboardContent extends StatelessWidget {
  final String selectedRoute;
  final Safe? selectedSafe;
  final Contact? selectedContact;
  final VoidCallback onSafeAdded;
  final void Function(Safe?) onSafeSelected;
  final VoidCallback onContactChanged;
  final void Function(Contact?) onContactSelected;

  const DashboardContent({
    super.key,
    required this.selectedRoute,
    required this.selectedSafe,
    this.selectedContact,
    required this.onSafeAdded,
    required this.onSafeSelected,
    required this.onContactChanged,
    required this.onContactSelected,
  });

  @override
  Widget build(BuildContext context) {
    return switch (selectedRoute) {
      'transactions_history' => const TransactionsHistoryScreen(),
      'profit_center_charts' => const ProfitCenterChartsScreen(),
      'transaction_alis' => const PurchaseSaleForm(isSale: false),
      'transaction_satis' => const PurchaseSaleForm(isSale: true),
      'transaction_transfer' => const TransferForm(),
      'transaction_odeme' => const PaymentCollectionForm(isPayment: true),
      'transaction_tahsilat' => const PaymentCollectionForm(isPayment: false),
      'contacts' => ContactsScreen(
          selectedContact: selectedContact,
          onContactChanged: onContactChanged,
          onContactSelected: onContactSelected,
        ),
      'profit_centers' => const ProfitCentersScreen(),
      'settings' => const SettingsScreen(),
      'safes' => SafesScreen(
          selectedSafe: selectedSafe,
          onSafeAdded: onSafeAdded,
          onSafeSelected: onSafeSelected,
        ),
      _ => Center(
          child: Text(
            '$_currentTitle sayfası buraya gelecek',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.grey,
            ),
          ),
        ),
    };
  }

  String get _currentTitle {
    if (selectedRoute == 'safes') {
      return selectedSafe?.name ?? 'Kasalar';
    }
    if (selectedRoute == 'contacts') {
      return selectedContact?.name ?? 'Cariler';
    }
    return selectedRoute;
  }
}
