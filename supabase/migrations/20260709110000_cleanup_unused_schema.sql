-- ============================================================================
-- Kullanılmayan şema parçalarının temizliği
--
-- Bu migration, uygulamanın hiçbir yerinde (Flutter tarafı + diğer SQL
-- objeleri) fiilen kullanılmayan tablo/kolonları düşürür. Amaç şemayı
-- sadeleştirmek; şimdilik ihtiyaç duyulmayan alanlar kaldırılıyor.
--
-- NEDEN forward migration (initial_schema düzenlemek yerine)?
-- Migration'lar zaten uygulanmış bir Supabase veritabanında geçerli
-- durumu temsil eder. Eski migration'ı değiştirmek yalnızca sıfırdan
-- kurulan DB'lerde çalışır ve uygulanmış ortamla senkronu bozar. Bu yüzden
-- değişiklik ileri yönlü (DROP) bir migration olarak eklenir.
--
-- KORUNANLAR (bilerek dokunulmadı):
--   * ledger_entries  -> muhasebe sisteminin çekirdeği. account_balances
--     view'i ve create/update_transaction_with_ledgers RPC'leri tamamen
--     buna dayanıyor; ayrıca 6 Flutter dosyasında kullanılıyor. "Kullanılmıyor"
--     değil; silinirse bakiyeler ve işlem kaydı komple çöker.
--   * lands.estimated_value -> şu an hiçbir ekranda gösterilmiyor ama
--     frontend'de (Land modelinde) tanımlı ve ileride kullanılabilir;
--     kullanıcı isteğiyle korundu.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1) audit_log tablosu
--
-- Şemada tanımlı ama hiçbir yerde kullanılmıyordu: içine yazan bir trigger
-- yok, Flutter tarafında hiç referans edilmiyor; yalnızca bir RLS policy'si
-- (audit_log_select_own), bir GRANT ve bir index vardı. DROP TABLE ... CASCADE
-- tabloyla birlikte bağlı policy/grant/index'leri de kaldırır.
-- ────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public.audit_log CASCADE;


-- ────────────────────────────────────────────────────────────────────────────
-- 2) lands tablosundan kullanılmayan kolonlar
--
-- Konum (city/district/neighborhood) ve kadastro (ada/parsel/pafta/tapu_no)
-- alanları şimdilik gerekli değil. Bunlar Flutter model + form + detay
-- ekranından da bu migration ile eşzamanlı olarak temizleniyor.
-- IF EXISTS ile tekrar çalıştırmaya karşı güvenli.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.lands
  DROP COLUMN IF EXISTS city,
  DROP COLUMN IF EXISTS district,
  DROP COLUMN IF EXISTS neighborhood,
  DROP COLUMN IF EXISTS ada,
  DROP COLUMN IF EXISTS parsel,
  DROP COLUMN IF EXISTS pafta,
  DROP COLUMN IF EXISTS tapu_no;
