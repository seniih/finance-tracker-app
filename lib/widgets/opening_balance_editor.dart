import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/form_helpers.dart';
import '../utils/number_input_formatter.dart';

/// Cari ekle/düzenle dialoglarında çoklu açılış bakiyesi (devir) satırlarını
/// tutan mutable satır.
class OpeningBalanceRow {
  String amountStr;
  String currency;
  bool isDebtor;

  OpeningBalanceRow({
    required this.amountStr,
    required this.currency,
    required this.isDebtor,
  });
}

/// Cari ekle/düzenle dialoglarında ortak kullanılan açılış bakiyesi (devir)
/// editörü. `rows` çağıran taraf sahipliğinde mutable tutulur; bir satır
/// eklendiğinde/silindiğinde/değiştiğinde `onChanged` çağrılır (çağıran
/// bunu genelde `StatefulBuilder`'ın `setDialogState(() {})`'i ile sarar).
class OpeningBalanceEditor extends StatelessWidget {
  final List<OpeningBalanceRow> rows;
  final VoidCallback onChanged;

  const OpeningBalanceEditor({
    super.key,
    required this.rows,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Açılış Bakiyesi (Devir) -- Opsiyonel',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((mapEntry) {
          final i = mapEntry.key;
          final row = mapEntry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('bal_amount_${i}_${row.currency}'),
                        initialValue: row.amountStr,
                        decoration: buildInputDecoration('Tutar'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [ThousandSeparatorInputFormatter()],
                        onChanged: (val) => row.amountStr = val,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('bal_currency_${i}_${row.currency}'),
                        decoration: buildInputDecoration('Birim'),
                        initialValue: row.currency,
                        items: appCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          row.currency = val ?? row.currency;
                          onChanged();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.error),
                      onPressed: () {
                        rows.removeAt(i);
                        onChanged();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          row.isDebtor = true;
                          onChanged();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: row.isDebtor ? AppColors.success.withValues(alpha: 0.1) : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: row.isDebtor ? AppColors.success : AppColors.border),
                          ),
                          child: Text(
                            'Cari Bana Borçlu',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: row.isDebtor ? AppColors.success : AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          row.isDebtor = false;
                          onChanged();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !row.isDebtor ? AppColors.warning.withValues(alpha: 0.1) : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !row.isDebtor ? AppColors.warning : AppColors.border),
                          ),
                          child: Text(
                            'Ben Cariye Borçluyum',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: !row.isDebtor ? AppColors.warning : AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (i < rows.length - 1) const Divider(color: AppColors.border, height: 16),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            rows.add(OpeningBalanceRow(amountStr: '', currency: 'TRY', isDebtor: true));
            onChanged();
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Başka Para Birimi Ekle'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }
}
