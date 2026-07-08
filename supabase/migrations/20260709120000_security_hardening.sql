-- ============================================================================
-- Güvenlik Sıkılaştırma (web'e açılış öncesi denetim bulguları)
--
-- Bu migration, uygulama internete açılmadan önce yapılan güvenlik
-- denetiminde bulunan 4 sorunu kapatır:
--
--   1) categories.parent_id çapraz kullanıcı sızıntısı:
--      20260707100000_fix_categories_recursion.sql, sonsuz döngü (42P17)
--      hatasını çözmek için parent_id sahiplik kontrolünü RLS'ten tamamen
--      kaldırmıştı. Sonuç: bir kullanıcı, BAŞKA bir kullanıcının kategori
--      id'sini parent_id olarak yazabiliyordu (FK sadece "var mı" diye
--      bakar, "senin mi" diye bakmaz). Çözüm: kontrolü SECURITY DEFINER
--      bir yardımcı fonksiyona taşımak. Fonksiyon tablo sahibinin
--      yetkisiyle çalıştığı için policy içinden categories'e tekrar
--      girerken RLS devreye girmez -> recursion oluşmaz, kontrol geri gelir.
--
--   2) land_investments.transaction_id sahiplik kontrolü eksikti:
--      RLS policy'si land_contact_id zincirini doğruluyordu ama
--      transaction_id'yi hiç kontrol etmiyordu -- bir kullanıcı, ödeme
--      kaydını başka bir kullanıcının işlem id'sine bağlayabilirdi
--      (FK yine sadece varlık kontrolü yapar). WITH CHECK'e ekleniyor.
--
--   3) anon rolünün varsayılan yetkileri: Supabase, public şemadaki yeni
--      tablo/fonksiyonlara varsayılan olarak anon + authenticated +
--      service_role'e yetki verir (ALTER DEFAULT PRIVILEGES). grants.sql
--      bilinçli olarak anon'a GRANT vermemişti ama var olan varsayılan
--      yetkileri de GERİ ALMAMIŞTI -- yani anon (giriş yapmamış herkes)
--      tablolara sorgu atabiliyor ve RPC'leri çağırabiliyordu. RLS
--      (auth.uid() NULL olduğu için) satır döndürmez, yani veri sızmaz;
--      ama internete açık bir uygulamada saldırı yüzeyini daraltmak için
--      anon'un tüm yetkileri açıkça geri alınıyor (savunma katmanı).
--
--   4) Fonksiyonlarda search_path sabitlenmemişti: Supabase güvenlik
--      linter'ının "function_search_path_mutable" uyarısı. Saldırgan
--      kendi şemasına aynı isimde nesne koyup fonksiyonun onu çözmesini
--      sağlayamasın diye search_path boş string'e sabitleniyor. Tüm
--      fonksiyon gövdeleri zaten şema nitelikli (public.*, auth.uid())
--      yazıldığı için davranış değişmez.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. categories.parent_id sahiplik kontrolünü geri getir (recursion'sız)
-- ────────────────────────────────────────────────────────────────────────────

-- SECURITY DEFINER: fonksiyon, tablo sahibinin yetkisiyle çalışır; sahip
-- RLS'e tabi olmadığı için policy -> fonksiyon -> categories zinciri
-- Postgres tarafından döngü (42P17) sayılmaz.
-- STABLE: aynı sorgu içinde aynı girdiyle aynı sonucu döner (planner dostu).
CREATE OR REPLACE FUNCTION public.fn_is_own_category(p_category_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.categories
    WHERE id = p_category_id AND user_id = (SELECT auth.uid())
  );
$$;

-- SECURITY DEFINER fonksiyonlarda yetkiyi dar tutmak önemli:
-- sadece authenticated çağırabilsin.
REVOKE ALL ON FUNCTION public.fn_is_own_category(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_is_own_category(uuid) TO authenticated;

DROP POLICY IF EXISTS "categories_insert" ON public.categories;
CREATE POLICY "categories_insert" ON public.categories
  FOR INSERT
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND (parent_id IS NULL OR public.fn_is_own_category(parent_id))
  );

DROP POLICY IF EXISTS "categories_update" ON public.categories;
CREATE POLICY "categories_update" ON public.categories
  FOR UPDATE
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND (parent_id IS NULL OR public.fn_is_own_category(parent_id))
  );


-- ────────────────────────────────────────────────────────────────────────────
-- 2. land_investments.transaction_id sahiplik kontrolü
-- ────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "land_investments_own" ON public.land_investments;
CREATE POLICY "land_investments_own" ON public.land_investments
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
        FROM public.land_contacts lc
        JOIN public.lands l ON l.id = lc.land_id
       WHERE lc.id = land_contact_id
         AND l.user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
        FROM public.land_contacts lc
        JOIN public.lands l ON l.id = lc.land_id
       WHERE lc.id = land_contact_id
         AND l.user_id = (SELECT auth.uid())
    )
    -- Yeni: ödeme bir işleme bağlanacaksa o işlem de çağıranın olmalı.
    AND (
      transaction_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.transactions
        WHERE id = transaction_id AND user_id = (SELECT auth.uid())
      )
    )
  );


-- ────────────────────────────────────────────────────────────────────────────
-- 3. anon rolünün tüm yetkilerini geri al
--    (Bu uygulamada login öncesi hiçbir DB erişimi yok; login/signup
--    auth servisi üzerinden yürür, public şemaya dokunmaz.)
-- ────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;

-- İleride eklenecek tablo/fonksiyonlar için de varsayılanı kapat
-- (migration'lar postgres rolüyle koştuğu için o rolün varsayılanı geçerli).
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES    FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Fonksiyonlarda search_path'i sabitle
--    (Gövdeler zaten şema nitelikli; davranış değişmez, sadece
--    "search_path zehirlenmesi" ihtimali kapanır.)
-- ────────────────────────────────────────────────────────────────────────────
ALTER FUNCTION public.fn_calc_distribution_amount()                 SET search_path = '';
ALTER FUNCTION public.fn_recalc_distributions_on_sale_update()      SET search_path = '';
ALTER FUNCTION public.fn_check_distribution_total()                 SET search_path = '';
ALTER FUNCTION public.fn_sync_land_status_on_sale()                 SET search_path = '';
ALTER FUNCTION public.fn_validate_ledgers(jsonb, text)              SET search_path = '';
ALTER FUNCTION public.create_transaction_with_ledgers(text, numeric, text, numeric, timestamptz, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb) SET search_path = '';
ALTER FUNCTION public.update_transaction_with_ledgers(uuid, text, numeric, text, numeric, timestamptz, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb) SET search_path = '';


-- ============================================================================
-- KONTROL SORGULARI
-- ============================================================================
-- anon'da yetki kalmadığını doğrula (sonuç boş olmalı):
-- SELECT grantee, table_name, privilege_type
--   FROM information_schema.role_table_grants
--  WHERE table_schema = 'public' AND grantee = 'anon';
--
-- search_path'i sabitlenmemiş fonksiyon kalmadığını doğrula (boş olmalı):
-- SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--  WHERE n.nspname = 'public'
--    AND NOT COALESCE(p.proconfig::text, '') LIKE '%search_path%';
