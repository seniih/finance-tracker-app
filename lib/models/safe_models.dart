class Safe {
  final String id;
  String name;
  double totalDebit;   // Toplam borç (giren para)
  double totalCredit;  // Toplam alacak (çıkan para)
  String currency;     // Para birimi (Örn: TL, USD)

  Safe({
    required this.id,
    required this.name,
    this.totalDebit = 0.0,
    this.totalCredit = 0.0,
    this.currency = 'TL',
  });

  factory Safe.fromJson(Map<String, dynamic> json) {
    return Safe(
      id: json['id'].toString(),
      name: json['name'] as String,
      totalDebit: (json['balance'] as num?)?.toDouble() ?? 0.0,
      totalCredit: 0.0,
      currency: json['currency'] as String? ?? 'TL',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'balance': balance,
      'currency': currency,
    };
  }

  double get balance => totalDebit - totalCredit;
}

