import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/constants.dart';
import '../../../models/account.dart';
import '../../../models/contact.dart';
import '../../profit_centers_screen.dart';
import '../../accounts_screen.dart';
import '../../contacts_screen.dart';
import '../../settings/settings_screen.dart';
import '../../categories_screen.dart';
import '../../transactions/transactions_history_screen.dart';
import '../../transactions/forms/transaction_form.dart';
import '../../transactions/forms/transfer_form.dart';
import '../../transactions/forms/purchase_form.dart';
import '../../lands/sale_start_screen.dart';
import '../home_screen.dart';

class DashboardContent extends StatelessWidget {
  final String selectedRoute;
  final Account? selectedAccount;
  final Contact? selectedContact;
  final VoidCallback onAccountAdded;
  final void Function(Account?) onAccountSelected;
  final VoidCallback onContactChanged;
  final void Function(Contact?) onContactSelected;

  const DashboardContent({
    super.key,
    required this.selectedRoute,
    required this.selectedAccount,
    this.selectedContact,
    required this.onAccountAdded,
    required this.onAccountSelected,
    required this.onContactChanged,
    required this.onContactSelected,
  });

  @override
  Widget build(BuildContext context) {
    return switch (selectedRoute) {
      'home' => const HomeScreen(),
      // Key önemli: iki route da aynı widget tipini kullandığından, key
      // olmazsa Flutter state'i korur ve gider<->gelir geçişinde eski
      // kategori seçimi (artık listede olmayan bir değer) hataya yol açar.
      'transaction_new_expense' => const TransactionForm(key: ValueKey('new_expense'), fixedType: CategoryType.expense),
      'transaction_new_income' => const TransactionForm(key: ValueKey('new_income'), fixedType: CategoryType.income),
      // Ödeme: cariye para çıkışı (gider) -- Tahsilat: cariden para girişi (gelir).
      'transaction_new_payment' => const TransactionForm(key: ValueKey('new_payment'), fixedType: CategoryType.expense, withContact: true),
      'transaction_new_collection' => const TransactionForm(key: ValueKey('new_collection'), fixedType: CategoryType.income, withContact: true),
      'transaction_new_transfer' => const TransferForm(),
      // Alış: projeye harcama formu (kasadan çıkar, proje maliyetine yazılır)
      'transaction_new_purchase' => const PurchaseForm(key: ValueKey('new_purchase')),
      // Satış: önce satılacak arsa seçilir, sonra satış formu açılır
      'transaction_new_sale' => const SaleStartScreen(),
      'transactions_history' => const TransactionsHistoryScreen(),
      // Kar merkezi -> proje -> arsa + yatırımcı hiyerarşisinin giriş ekranı
      'projects' => const ProfitCentersScreen(),
      'contacts' => ContactsScreen(
          selectedContact: selectedContact,
          onContactChanged: onContactChanged,
          onContactSelected: onContactSelected,
        ),
      'accounts' => const AccountsScreen(),
      'categories' => const CategoriesScreen(),
      'settings' => const SettingsScreen(),
      _ => Center(
          child: Text(
            '$_currentTitle sayfası buraya gelecek',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
    };
  }

  String get _currentTitle {
    if (selectedRoute == 'accounts') {
      return selectedAccount?.name ?? 'Hesaplar / Kasalar';
    }
    if (selectedRoute == 'contacts') {
      return selectedContact?.name ?? 'Cariler';
    }
    return selectedRoute;
  }
}
