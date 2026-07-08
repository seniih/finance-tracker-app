import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';

/// İşlem formlarında (gelir/gider, transfer, yatırım) alanları anlamlı
/// gruplar halinde göstermek için kullanılan ortak kart bileşeni.
/// Amaç: tüm input'ların art arda tek bir sütunda sıralandığı karışık
/// görünüm yerine, ilgili alanları başlıklı kartlar altında toplamak.
class FormSectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final Widget? trailing;

  const FormSectionCard({
    super.key,
    required this.title,
    this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Bir alanın seçili durumuna göre küçük "Gelir" / "Gider" gibi renkli
/// rozet göstermek için kullanılır (kategori seçildiğinde tipini vurgular).
class InlineTypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const InlineTypeBadge({super.key, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
