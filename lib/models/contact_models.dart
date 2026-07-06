class ContactTypeModel {
  final String id;
  final String name;

  ContactTypeModel({required this.id, required this.name});

  factory ContactTypeModel.fromJson(Map<String, dynamic> json) {
    return ContactTypeModel(
      id: json['id'].toString(),
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }
}

class Contact {
  final String id;
  final String name;
  final String type;
  final String? phone;
  final String? address;
  final String? tc;
  final String? description;
  final double balance;
  final String currency;

  Contact({
    required this.id,
    required this.name,
    required this.type,
    this.phone,
    this.address,
    this.tc,
    this.description,
    this.balance = 0.0,
    this.currency = 'TL',
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'].toString(),
      name: json['name'] as String,
      type: json['type'] as String? ?? 'Diğer',
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      tc: json['tc_no'] as String?,
      description: json['description'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'TL',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'phone': phone,
      'address': address,
      'tc_no': tc,
      'description': description,
      'balance': balance,
      'currency': currency,
    };
  }
}

