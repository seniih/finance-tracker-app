import '../models/contact.dart';
import '../models/transaction.dart';
import 'constants.dart';

/// Bir carinin işlemlerinden bakiyesini (borç/alacak) para birimine göre hesaplar.
///
/// Sözleşme (kullanıcı ile netleştirildi):
/// - GİDER (cariye para/ödeme verildi) ve YATIRIM ÇIKIŞI (cariye para çıkışı)
///   → pozitif katkı: cari bana borçlanır (ona verdiğim tutarı geri almam gerekir).
/// - GELİR (cariden ödeme alındı) ve YATIRIM GİRİŞİ (cariden para girişi)
///   → negatif katkı: cariye olan borcum artar / carinin bana olan borcu azalır.
/// - Transfer işlemlerinde contact_id hiç set edilmediğinden hesaba katılmaz.
///
/// Dönen haritada: pozitif değer = "Cari bana borçlu", negatif değer = "Ben cariye borçluyum".
abstract final class ContactBalanceCalculator {
  static double _sign(TransactionModel tr) {
    switch (tr.transactionType) {
      case TransactionType.standard:
        if (tr.category == null) return 0.0;
        return tr.category!.type == CategoryType.expense ? 1.0 : -1.0;
      case TransactionType.investmentOut:
        return 1.0;
      case TransactionType.investmentIn:
        return -1.0;
      case TransactionType.transfer:
        return 0.0;
    }
  }

  /// [transactions] tek bir cariye ait olmalı (contactId filtreli liste).
  /// [openingBalance]/[openingBalanceCurrency] o carinin devir bakiyesidir
  /// (bkz. Contact.openingBalance) -- işlemlerden önceki başlangıç değeri
  /// olarak hesaba katılır. Para birimine göre net bakiyeyi döner.
  static Map<String, double> calculate(
    List<TransactionModel> transactions, {
    double openingBalance = 0,
    String openingBalanceCurrency = 'TRY',
  }) {
    final balances = <String, double>{};
    if (openingBalance != 0) {
      balances[openingBalanceCurrency] = openingBalance;
    }
    for (final tr in transactions) {
      final delta = _sign(tr) * tr.amount;
      if (delta == 0) continue;
      balances[tr.currency] = (balances[tr.currency] ?? 0) + delta;
    }
    // Sıfıra yuvarlanan (borç kapanmış) para birimlerini gizle.
    balances.removeWhere((_, v) => v.abs() < 0.005);
    return balances;
  }

  /// [transactions] karışık (birden fazla cariye ait) olabilir; contactId'ye göre
  /// gruplanıp her cari için [calculate] uygulanır (devir bakiyesi [contacts]
  /// listesinden okunur -- işlemi hiç olmayan ama devir bakiyesi olan cariler
  /// de dahil edilsin diye gruplama değil, cari listesi baz alınıyor).
  /// Sonuç: contactId -> (para birimi -> bakiye).
  static Map<String, Map<String, double>> calculateByContact(
    List<TransactionModel> transactions,
    List<Contact> contacts,
  ) {
    final grouped = <String, List<TransactionModel>>{};
    for (final tr in transactions) {
      final cId = tr.contactId;
      if (cId == null) continue;
      grouped.putIfAbsent(cId, () => []).add(tr);
    }
    final result = <String, Map<String, double>>{};
    for (final c in contacts) {
      result[c.id] = calculate(
        grouped[c.id] ?? const [],
        openingBalance: c.openingBalance,
        openingBalanceCurrency: c.openingBalanceCurrency,
      );
    }
    return result;
  }
}
