import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/app_theme.dart';
import 'utils/env.dart';
import 'auth/auth_wrapper.dart';
import 'services/database_service.dart';
import 'services/supabase_database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty,
    '\n\n'
    '🚨 Supabase credentials eksik!\n'
    'config.json dosyasını doldurup şu komutla çalıştırın:\n'
    '  flutter run -d macos --dart-define-from-file=config.json\n',
  );

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  dbService = SupabaseDatabaseService();

  runApp(const FinanceTrackerApp());
}

class FinanceTrackerApp extends StatelessWidget {
  const FinanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrendArsa Muhasabe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthWrapper(),
    );
  }
}
