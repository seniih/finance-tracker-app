import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import 'sidebar_menu_item.dart';

class MenuItem {
  final String? route;
  final String label;
  final IconData? icon;
  final bool isHeader;

  const MenuItem({
    this.route,
    required this.label,
    this.icon,
    this.isHeader = false,
  });
}

class DashboardSidebar extends StatelessWidget {
  final String selectedRoute;
  final List<MenuItem> menuItems;
  final void Function(String route) onRouteSelected;
  final VoidCallback? onSignOut;

  static const double _width = 220;

  const DashboardSidebar({
    super.key,
    required this.selectedRoute,
    required this.menuItems,
    required this.onRouteSelected,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrand(context),
          const Divider(color: AppColors.sidebarDivider, height: 0, indent: 10, endIndent: 10),
          const SizedBox(height: AppSpacing.xs),
          Expanded(child: _buildMenuList(context)),
          _buildUserFooter(context),
        ],
      ),
    );
  }

  Widget _buildBrand(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Text(
        'TrendArsa Finans',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppColors.sidebarText,
          fontSize: 18,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildMenuList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
      children: menuItems.map((item) {
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xs),
            child: Text(
              item.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.sidebarText.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          );
        }
        return SidebarMenuItem(
          label: item.label,
          icon: item.icon!,
          isSelected: selectedRoute == item.route,
          onTap: () => onRouteSelected(item.route!),
        );
      }).toList(),
    );
  }

  Widget _buildUserFooter(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email;
    return Column(
      children: [
        const Divider(color: AppColors.sidebarDivider, height: 0, indent: 10, endIndent: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.sidebarTextMuted, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  email ?? '',
                  style: const TextStyle(color: AppColors.sidebarTextMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Çıkış Yap',
                icon: const Icon(Icons.logout_rounded, color: AppColors.sidebarTextMuted, size: 18),
                onPressed: onSignOut,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
