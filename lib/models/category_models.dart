class ProfitCenter {
  final String id;
  String name;
  double balance;
  String currency;
  double? exchangeRate;
  List<MainCategory> mainCategories;

  ProfitCenter({
    required this.id,
    required this.name,
    this.balance = 0.0,
    this.currency = 'TL',
    this.exchangeRate,
    List<MainCategory>? mainCategories,
  }) : mainCategories = mainCategories ?? [];

  double get balanceInTL {
    if (currency == 'TL' || exchangeRate == null) return balance;
    return balance * exchangeRate!;
  }

  factory ProfitCenter.fromJson(Map<String, dynamic> json) {
    return ProfitCenter(
      id: json['id'] as String,
      name: json['name'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'TL',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
      mainCategories: json['main_categories'] != null
          ? (json['main_categories'] as List).map((i) => MainCategory.fromJson(i)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'balance': balance,
      'currency': currency,
      'exchange_rate': exchangeRate,
    };
  }
}

class MainCategory {
  final String id;
  String name;
  double balance;
  String currency;
  double? exchangeRate;
  List<SubCategory> subCategories;

  MainCategory({
    required this.id,
    required this.name,
    this.balance = 0.0,
    this.currency = 'TL',
    this.exchangeRate,
    List<SubCategory>? subCategories,
  }) : subCategories = subCategories ?? [];

  double get balanceInTL {
    if (currency == 'TL' || exchangeRate == null) return balance;
    return balance * exchangeRate!;
  }

  factory MainCategory.fromJson(Map<String, dynamic> json) {
    return MainCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'TL',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
      subCategories: json['sub_categories'] != null
          ? (json['sub_categories'] as List).map((i) => SubCategory.fromJson(i)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson(String profitCenterId) {
    return {
      'name': name,
      'balance': balance,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'profit_center_id': profitCenterId,
    };
  }
}

class SubCategory {
  final String id;
  String name;
  double balance;
  String currency;
  double? exchangeRate;

  SubCategory({
    required this.id,
    required this.name,
    this.balance = 0.0,
    this.currency = 'TL',
    this.exchangeRate,
  });

  double get balanceInTL {
    if (currency == 'TL' || exchangeRate == null) return balance;
    return balance * exchangeRate!;
  }

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'TL',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson(String mainCategoryId) {
    return {
      'name': name,
      'balance': balance,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'main_category_id': mainCategoryId,
    };
  }
}
