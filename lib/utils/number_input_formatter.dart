import 'package:flutter/services.dart';

/// Sayı girişlerini otomatik olarak biçimlendirir:
/// - Binlik ayracı: "." (1.234.567)
/// - Ondalık ayracı: "," (1.234,50)
/// - Sadece rakam ve virgüle izin verir
///
/// Tutar/miktar giren TÜM input alanlarına (`inputFormatters: [ThousandSeparatorInputFormatter()]`)
/// bağlanmalıdır. Kaydederken girilen metni [parseFormattedNumber] ile geri
/// double'a çevirin; mevcut bir kaydı düzenlerken alanı önceden doldururken
/// [formatNumberForInput] kullanın ki görünüm daha kullanıcı hiç yazmadan
/// önce de tutarlı olsun.
class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    if (raw.isEmpty) return newValue;

    // Sadece eksi girildiyse (negatif sayı başlangıcı) izin ver
    if (raw == '-') return newValue;

    // Negatiflik kontrolü
    final isNegative = raw.startsWith('-');

    // Sadece rakam ve virgüle izin ver
    final cleaned = raw.replaceAll(RegExp(r'[^\d,]'), '');

    // Virgülden böl: tam sayı ve ondalık kısım
    final parts = cleaned.split(',');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : null;

    // Ondalık kısmı en fazla 2 haneyle sınırla
    final truncatedDec = decPart != null
        ? (decPart.length > 2 ? decPart.substring(0, 2) : decPart)
        : null;

    // Binlik nokta ekle
    final formattedInt = _addThousandDots(intPart);

    // Birleştir
    String result = truncatedDec != null
        ? '$formattedInt,$truncatedDec'
        : formattedInt;

    // Negatifse başa eksiyi geri ekle
    if (isNegative && result.isNotEmpty) {
      result = '-$result';
    }

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

/// [ThousandSeparatorInputFormatter] ve [formatNumberForInput] tarafından
/// ortak kullanılan binlik nokta ekleme mantığı.
String _addThousandDots(String intPart) {
  if (intPart.isEmpty) return '';
  final buf = StringBuffer();
  final len = intPart.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      buf.write('.');
    }
    buf.write(intPart[i]);
  }
  return buf.toString();
}

/// Formatlı string'i ("1.234,50" gibi) parse edip double döner (null-safe).
/// [ThousandSeparatorInputFormatter] ile biçimlendirilmiş bir input alanının
/// metnini kaydetmeden önce gerçek sayıya çevirmek için kullanılır.
double? parseFormattedNumber(String? input) {
  if (input == null || input.trim().isEmpty) return null;

  // Sadece eksiyse null dön
  if (input.trim() == '-') return null;

  final isNegative = input.trim().startsWith('-');

  // Noktaları (binlik ayracı) sil, virgülü ondalık noktaya çevir, eksiyi at
  String normalized = input.replaceAll('.', '').replaceAll(',', '.').replaceAll('-', '');

  double? parsed = double.tryParse(normalized);
  if (parsed != null && isNegative) {
    parsed = -parsed;
  }
  return parsed;
}

/// Var olan bir sayısal değeri (örn. düzenleme modunda mevcut tutar/bakiye),
/// [ThousandSeparatorInputFormatter] ile aynı görünüme (binlik nokta, virgüllü
/// ondalık, gereksiz ",00" gizlenir) sahip bir metne çevirir -- böylece input
/// alanı kullanıcı hiç yazmadan önce de tutarlı görünür. Değer 0 ise boş
/// string döner (formların "0 girilmemiş" varsayımıyla uyumlu).
String formatNumberForInput(double value) {
  if (value == 0) return '';

  final isNegative = value < 0;
  final abs = value.abs();
  final hasDecimals = (abs - abs.truncateToDouble()) >= 0.005;

  final String result;
  if (hasDecimals) {
    final parts = abs.toStringAsFixed(2).split('.');
    result = '${_addThousandDots(parts[0])},${parts[1]}';
  } else {
    result = _addThousandDots(abs.truncate().toString());
  }
  return isNegative ? '-$result' : result;
}
