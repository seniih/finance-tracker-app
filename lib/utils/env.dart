/// Supabase Veritabanı Bağlantı Bilgileri
/// Bu dosya `--dart-define-from-file=config.json` ile okunur.
/// config.json GİT'E GÖNDERİLMEZ — .gitignore'da tanımlıdır.
class Env {
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
}
