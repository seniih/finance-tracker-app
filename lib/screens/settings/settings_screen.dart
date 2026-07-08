import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/custom_app_bar.dart';
import 'contact_types_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Ayarlar', icon: Icons.settings),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Profil & Güvenlik'),
            const SizedBox(height: AppSpacing.md),
            _buildProfileCard(context),
            const SizedBox(height: AppSpacing.xxxl),

            _buildSectionHeader('Veri Yönetimi'),
            const SizedBox(height: AppSpacing.md),
            _buildSettingsGroup(
              context: context,
              items: [
                _SettingsItem(
                  icon: Icons.category,
                  title: 'Cari Türleri',
                  subtitle: 'Müşteri, Tedarikçi, Ortak gibi türleri düzenleyin',
                  iconColor: AppColors.info,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactTypesScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxl),

            _buildSectionHeader('Tercihler'),
            const SizedBox(height: AppSpacing.md),
            _buildSettingsGroup(
              context: context,
              items: [
                _SettingsItem(
                  icon: Icons.dark_mode,
                  title: 'Görünüm',
                  subtitle: 'Tema seçeneklerini ayarlayın (Aydınlık / Karanlık)',
                  iconColor: Colors.deepPurple,
                  onTap: () {
                    _showComingSoonDialog(context, 'Tema Seçenekleri');
                  },
                ),
                _SettingsItem(
                  icon: Icons.notifications,
                  title: 'Bildirimler',
                  subtitle: 'Uygulama içi ve e-posta bildirim ayarları',
                  iconColor: AppColors.primary,
                  onTap: () {
                    _showComingSoonDialog(context, 'Bildirim Ayarları');
                  },
                ),
                _SettingsItem(
                  icon: Icons.language,
                  title: 'Dil / Bölge',
                  subtitle: 'Türkçe (TR) - TRY (₺)',
                  iconColor: AppColors.info,
                  onTap: () {
                    _showComingSoonDialog(context, 'Dil ve Bölge Ayarları');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Bilinmiyor';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, size: 30, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kullanıcı Hesabı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              // Sign out logic is handled in the sidebar, but we can also have it here.
              Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
            label: const Text('Çıkış Yap', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({
    required BuildContext context,
    required List<_SettingsItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final int idx = entry.key;
          final _SettingsItem item = entry.value;

          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(
                  items.length == 1
                      ? 16
                      : idx == 0
                          ? 16 // top radius only
                          : idx == items.length - 1
                              ? 16 // bottom radius only
                              : 0,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: item.iconColor, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (idx < items.length - 1)
                const Divider(height: 1, thickness: 1, color: AppColors.border, indent: 64),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(featureName),
        content: const Text('Bu özellik yakında eklenecektir. Şimdilik yapım aşamasındadır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.iconColor,
    required this.onTap,
  });
}
