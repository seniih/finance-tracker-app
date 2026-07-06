import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import 'login_page.dart';
import '../screens/dashboard/dashboard_screen.dart';

/// Supabase oturum durumunu dinleyen ve yönlendirmeyi yöneten widget.
/// Uygulama açılırken [onAuthStateChange] stream'ini dinler:
/// - Aktif session varsa → [DashboardScreen]
/// - Session yoksa       → [LoginPage]
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Bağlantı henüz kurulmadıysa yüklenme göstergesi
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return const DashboardScreen();
        }

        return const LoginPage();
      },
    );
  }
}
