enum ProjectStatus {
  active('Active'),
  completed('Completed'),
  suspended('Suspended'),
  cancelled('Cancelled');

  final String value;
  const ProjectStatus(this.value);

  factory ProjectStatus.fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => ProjectStatus.active,
    );
  }
}

// DB'deki lands.status CHECK kısıtıyla birebir aynı değerler
// (bkz. supabase/migrations/20260708150000_land_investment_system.sql)
enum LandStatus {
  purchased('purchased', 'Portföyde'),
  forSale('for_sale', 'Satışta'),
  sold('sold', 'Satıldı');

  final String value;
  final String label;
  const LandStatus(this.value, this.label);

  factory LandStatus.fromString(String value) {
    return LandStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => LandStatus.purchased,
    );
  }
}

enum CategoryType {
  income('income', 'Gelir'),
  expense('expense', 'Gider');

  final String value;
  final String label;
  const CategoryType(this.value, this.label);

  factory CategoryType.fromString(String value) {
    return CategoryType.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => CategoryType.expense,
    );
  }
}

enum TransactionStatus {
  completed('Completed'),
  pending('Pending'),
  cancelled('Cancelled');

  final String value;
  const TransactionStatus(this.value);

  factory TransactionStatus.fromString(String value) {
    return TransactionStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => TransactionStatus.completed,
    );
  }
}

enum AccountType {
  cash('cash', 'Nakit'),
  bank('bank', 'Banka'),
  creditCard('credit_card', 'Kredi Kartı');

  final String value;
  final String label;
  const AccountType(this.value, this.label);

  factory AccountType.fromString(String value) {
    return AccountType.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => AccountType.bank,
    );
  }
}

enum TransactionType {
  standard('standard', 'Standart İşlem'),
  transfer('transfer', 'Transfer'),
  investmentIn('investment_in', 'Yatırım Girişi'),
  investmentOut('investment_out', 'Yatırım Çıkışı');

  final String value;
  final String label;
  const TransactionType(this.value, this.label);

  factory TransactionType.fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => TransactionType.standard,
    );
  }
}

const List<String> appCurrencies = [
  'TRY',
  'USD',
  'EUR',
  'GBP',
  'Gram Altın',
  'Cumhuriyet Altını',
];
