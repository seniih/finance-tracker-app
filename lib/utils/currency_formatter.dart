abstract final class CurrencyFormatter {
  // Binlik nokta, virgülden sonra 2 hane (00 ise gizli), para birimine göre sembol
  // Örnek: 1234567.5 → "1.234.567,50 ₺"  |  1234000 → "1.234.000 ₺"

  static String format(double amount, {String? currency}) {
    final symbol = _symbol(currency);
    final prefix = amount < 0 ? '-' : '';
    final abs = amount.abs();
    return '$prefix${_formatNumber(abs)}$symbol';
  }

  static String _formatNumber(double abs) {
    final hasDecimals = (abs - abs.truncateToDouble()) >= 0.005;

    if (hasDecimals) {
      // İki ondalık hane
      final parts = abs.toStringAsFixed(2).split('.');
      return '${_addThousandDots(parts[0])},${parts[1]}';
    } else {
      return _addThousandDots(abs.truncate().toString());
    }
  }

  static String _addThousandDots(String intPart) {
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

  static String _symbol(String? currency) {
    switch (currency?.toUpperCase()) {
      case 'USD':
      case 'DOLAR':
        return ' \$';
      case 'EUR':
      case 'EURO':
        return ' €';
      case 'GRAM_ALTIN':
        return ' gr';
      case 'CUMHURIYET_ALTINI':
        return ' C.Altını';
      default:
        return ' ₺';
    }
  }

  static String getLabel(String? currency) {
    if (currency == 'CUMHURIYET_ALTINI') return 'Cumhuriyet Altını';
    if (currency == 'GRAM_ALTIN') return 'Gram Altın';
    return currency ?? 'TL';
  }
}
