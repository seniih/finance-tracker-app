import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';

class SidebarMenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const SidebarMenuItem({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.primaryHover.withValues(alpha: 0.5),
      splashColor: AppColors.primaryPressed.withValues(alpha: 0.5),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPressed : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.sidebarText : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 13,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.sidebarText, size: AppSpacing.xl),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.sidebarText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
