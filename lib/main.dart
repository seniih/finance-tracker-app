import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/app_theme.dart';
import 'utils/env.dart';
import 'auth/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Öncelik: --dart-define-from-file=config.json ile gelen değerler.
  var url = Env.supabaseUrl;
  var key = Env.supabaseAnonKey;

  // 2) Yedek: Uygulama düz `flutter run` ile başlatıldıysa config.json'ı
  //    asset olarak oku. (Önceden burada assert vardı ve dart-define
  //    verilmeden her `flutter run`'da exception atıyordu.)
  if (url.isEmpty || key.isEmpty) {
    try {
      final raw = await rootBundle.loadString('config.json');
      final cfg = jsonDecode(raw) as Map<String, dynamic>;
      url = (cfg['SUPABASE_URL'] as String?) ?? '';
      key = (cfg['SUPABASE_ANON_KEY'] as String?) ?? '';
    } catch (_) {
      // config.json bulunamadı/bozuk -- aşağıda kullanıcıya açıklanır.
    }
  }

  if (url.isEmpty || key.isEmpty) {
    runApp(const _ConfigErrorApp());
    return;
  }

  await Supabase.initialize(
    url: url,
    publishableKey: key,
  );

  runApp(const FinanceTrackerApp());
}

class FinanceTrackerApp extends StatelessWidget {
  const FinanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrendArsa Muhasebe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthWrapper(),
    );
  }
}

/// Supabase bilgileri hiçbir kaynaktan okunamadığında exception fırlatmak
/// yerine ne yapılması gerektiğini anlatan ekran.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_suggest_outlined, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Supabase ayarları bulunamadı',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Proje kökündeki config.json dosyasına SUPABASE_URL ve '
                  'SUPABASE_ANON_KEY değerlerini ekleyip uygulamayı yeniden başlatın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
