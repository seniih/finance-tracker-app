import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/number_input_formatter.dart';

class FormRow extends StatelessWidget {
  final List<Widget> children;

  const FormRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand(
            (child) => [
              Expanded(child: child),
              if (child != children.last) const SizedBox(width: AppSpacing.xxl),
            ],
          )
          .toList(),
    );
  }
}

Widget buildTextField(
  String label,
  void Function(String?) onSaved, {
  bool isNumber = false,
  int maxLines = 1,
  bool isRequired = true,
}) {
  return TextFormField(
    decoration: buildInputDecoration(label),
    keyboardType: isNumber
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters: isNumber ? [ThousandSeparatorInputFormatter()] : null,
    maxLines: maxLines,
    onSaved: (val) {
      if (isNumber) {
        // Formatlı string'i raw sayıya çevir
        final parsed = parseFormattedNumber(val);
        onSaved(parsed?.toString());
      } else {
        onSaved(val);
      }
    },
    validator: (val) {
      if (!isRequired) return null;
      return (val == null || val.trim().isEmpty) ? '$label gerekli' : null;
    },
  );
}

Widget buildAutocomplete(
  String label,
  String? currentValue,
  List<String> items,
  void Function(String?) onChanged, {
  Key? key,
  bool isRequired = true,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Autocomplete<String>(
        key: key,
        initialValue: TextEditingValue(text: currentValue ?? ''),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return items;
          }
          return items.where((String option) {
            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
          });
        },
        onSelected: (String selection) {
          onChanged(selection);
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppSpacing.sm)),
              ),
              color: AppColors.surface,
              child: SizedBox(
                width: constraints.maxWidth,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      hoverColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        child: Text(
                          option,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: buildInputDecoration(label).copyWith(
              suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
            ),
            onChanged: onChanged,
            validator: (val) {
              if (!isRequired) return null;
              return (val == null || val.trim().isEmpty) ? '$label gerekli' : null;
            },
          );
        },
      );
    }
  );
}

InputDecoration buildInputDecoration(String label) {
  const radius = BorderRadius.all(Radius.circular(AppSpacing.md));
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    filled: true,
    fillColor: AppColors.surface,
  );
}
