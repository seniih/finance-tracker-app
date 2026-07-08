-- ============================================================================
-- GRANT Yetkileri
-- Not: Bu GRANT'ler tablo seviyesinde "erişim var mı" sorusunu cevaplar.
-- RLS policy'leri hâlâ devrede kalır ve "hangi satırlar" sorusunu cevaplar.
-- İkisi birlikte çalışır, biri diğerinin yerine geçmez.
--
-- authenticated: giriş yapmış kullanıcılar
-- anon: giriş yapmamış (misafir) kullanıcılar -- bu uygulamada muhtemelen
--       hiçbir tabloya ihtiyacı yok, o yüzden anon'a GRANT vermiyoruz.
--       Eğer login öncesi görünmesi gereken bir şey varsa (ör. public bir
--       sayfa) o zaman ayrıca eklenir.
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.contact_types TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.contacts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.accounts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.projects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lands TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.land_contacts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ledger_entries TO authenticated;

-- audit_log: sadece SELECT -- kullanıcı buraya elle yazmamalı,
-- bu RLS dosyasındaki kararla tutarlı (yazma sadece SECURITY DEFINER
-- trigger üzerinden olmalı, trigger zaten table owner yetkisiyle çalışır).
GRANT SELECT ON public.audit_log TO authenticated;


-- ============================================================================
-- KONTROL SORGUSU
-- Hangi rollerin hangi tablolarda ne yetkisi var, görmek için:
-- ============================================================================
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE table_schema = 'public'
-- ORDER BY table_name, grantee;