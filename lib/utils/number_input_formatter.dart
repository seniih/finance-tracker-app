import 'package:flutter/services.dart';

/// Sayı girişlerini otomatik olarak biçimlendirir:
/// - Binlik ayracı: "." (1.234.567)
/// - Ondalık ayracı: "," (1.234,50)
/// - Sadece rakam ve virgüle izin verir
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

  static String _addThousandDots(String intPart) {
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
}

/// Formatlı string'i parse edip double döner (null-safe)
double? parseFormattedNumber(String? input) {
  if (input == null || input.trim().isEmpty) return null;
  
  // Sadece eksiyse null dön
  if (input.trim() == '-') return null;

  final isNegative = input.trim().startsWith('-');
  
  // Noktaları sil, virgülü noktaya çevir, eksiyi at
  String normalized = input.replaceAll('.', '').replaceAll(',', '.').replaceAll('-', '');
  
  double? parsed = double.tryParse(normalized);
  if (parsed != null && isNegative) {
    parsed = -parsed;
  }
  return parsed;
}
