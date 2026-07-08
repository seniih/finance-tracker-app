-- ============================================================================
-- RLS (Row Level Security) Policy Dosyası
-- Proje: Emlak/Arazi Yatırım Yönetim Uygulaması
-- Not: Backend yok, Flutter frontend doğrudan Supabase'e (anon/authenticated
--      key ile) bağlanıyor. Bu yüzden RLS tek güvenlik katmanı -- her policy
--      hem SELECT/UPDATE/DELETE için USING, hem INSERT/UPDATE için WITH CHECK
--      koşulu taşıyor. Aralarında ekstra bir backend filtrelemesi YOK.
--
-- Sıra önemli: Bir tablo başka bir tabloya join ile referans veriyorsa,
-- o tablonun RLS'i de aktif ve doğru olmalı, yoksa join'li kontrol
-- güvenilir olmaz.
--
-- Test için: Supabase SQL Editor'de farklı user context'leriyle deneyin,
-- ya da Supabase Dashboard > Authentication üzerinden iki test kullanıcısı
-- açıp Flutter tarafında çapraz erişim deneyin (biri diğerinin id'sini
-- kullanmayı denesin).
-- ============================================================================


-- ============================================================================
-- 1. PROFILES
-- ============================================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_own" ON profiles;
CREATE POLICY "profiles_own" ON profiles
  FOR ALL
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));


-- ============================================================================
-- 2. CONTACT_TYPES
-- ============================================================================
ALTER TABLE contact_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "contact_types_own" ON contact_types;
CREATE POLICY "contact_types_own" ON contact_types
  FOR ALL
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));


-- ============================================================================
-- 3. ACCOUNTS
-- ============================================================================
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "accounts_own" ON accounts;
CREATE POLICY "accounts_own" ON accounts
  FOR ALL
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));


-- ============================================================================
-- 4. PROJECTS
-- ============================================================================
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "projects_own" ON projects;
CREATE POLICY "projects_own" ON projects
  FOR ALL
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));


-- ============================================================================
-- 5. CONTACTS
-- contact_type_id başka bir kullanıcıya ait olamaz (FK constraint id'nin
-- var olduğunu garanti eder ama "senin mi" diye bakmaz -- onu burada
-- WITH CHECK ile kapatıyoruz).
-- ============================================================================
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "contacts_own" ON contacts;
CREATE POLICY "contacts_own" ON contacts
  FOR ALL
  USING (user_id = (select auth.uid()))
  WITH CHECK (
    user_id = (select auth.uid())
    AND (
      contact_type_id IS NULL
      OR EXISTS (
        SELECT 1 FROM contact_types
        WHERE id = contact_type_id AND user_id = (select auth.uid())
      )
    )
  );


-- ============================================================================
-- 6. LANDS
-- project_id başka bir kullanıcıya ait olamaz.
-- ============================================================================
ALTER TABLE lands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "lands_own" ON lands;
CREATE POLICY "lands_own" ON lands
  FOR ALL
  USING (user_id = (select auth.uid()))
  WITH CHECK (
    user_id = (select auth.uid())
    AND (
      project_id IS NULL
      OR EXISTS (
        SELECT 1 FROM projects
        WHERE id = project_id AND user_id = (select auth.uid())
      )
    )
  );


-- ============================================================================
-- 7. CATEGORIES
-- parent_id (kendi kendine referans) başka bir kullanıcıya ait olamaz.
-- ============================================================================
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "categories_own" ON categories;
CREATE POLICY "categories_own" ON categories
  FOR ALL
  USING (user_id = (select auth.uid()))
  WITH CHECK (
    user_id = (select auth.uid())
    AND (
      parent_id IS NULL
      OR EXISTS (
        SELECT 1 FROM categories
        WHERE id = parent_id AND user_id = (select auth.uid())
      )
    )
  );


-- ============================================================================
-- 8. TRANSACTIONS
-- En kritik tablo. 6 farklı FK var: project_id, land_id, contact_id,
-- account_id, to_account_id, category_id. Backend olmadığı için bu
-- kontrollerin HEPSİ burada, DB seviyesinde yapılmak zorunda -- yoksa bir
-- kullanıcı kendi transaction'ını başka birinin hesabına/carisine
-- bağlayabilir.
-- ============================================================================
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "transactions_own" ON transactions;
CREATE POLICY "transactions_own" ON transactions
  FOR ALL
  USING (user_id = (select auth.uid()))
  WITH CHECK (
    user_id = (select auth.uid())
    AND (
      project_id IS NULL
      OR EXISTS (SELECT 1 FROM projects WHERE id = project_id AND user_id = (select auth.uid()))
    )
    AND (
      land_id IS NULL
      OR EXISTS (SELECT 1 FROM lands WHERE id = land_id AND user_id = (select auth.uid()))
    )
    AND (
      contact_id IS NULL
      OR EXISTS (SELECT 1 FROM contacts WHERE id = contact_id AND user_id = (select auth.uid()))
    )
    AND (
      account_id IS NULL
      OR EXISTS (SELECT 1 FROM accounts WHERE id = account_id AND user_id = (select auth.uid()))
    )
    AND (
      to_account_id IS NULL
      OR EXISTS (SELECT 1 FROM accounts WHERE id = to_account_id AND user_id = (select auth.uid()))
    )
    AND (
      category_id IS NULL
      OR EXISTS (SELECT 1 FROM categories WHERE id = category_id AND user_id = (select auth.uid()))
    )
  );


-- ============================================================================
-- 9. LAND_CONTACTS
-- user_id kolonu yok -- sahiplik land_id VE contact_id üzerinden dolaylı.
-- İkisinin de aynı kullanıcıya ait olması gerekiyor.
-- ============================================================================
ALTER TABLE land_contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "land_contacts_own" ON land_contacts;
CREATE POLICY "land_contacts_own" ON land_contacts
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM lands WHERE id = land_id AND user_id = (select auth.uid()))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM lands WHERE id = land_id AND user_id = (select auth.uid()))
    AND EXISTS (SELECT 1 FROM contacts WHERE id = contact_id AND user_id = (select auth.uid()))
  );


-- ============================================================================
-- 10. LEDGER_ENTRIES
-- user_id kolonu yok -- sahiplik transaction_id üzerinden dolaylı.
-- account_id de ayrıca kontrol ediliyor (transaction'ın hesabıyla
-- ledger entry'nin hesabı tutarsız olabilir, bunu da kapatıyoruz).
--
-- ÖNEMLİ: Backend olmadığı için ledger_entries'i kim yazacak?
--   a) Flutter'dan direkt insert ediliyorsa -- WITH CHECK aşağıdaki gibi
--      kalmalı.
--   b) Bir trigger (transaction insert olunca otomatik ledger_entries
--      oluşturan) varsa -- o trigger fonksiyonunun SECURITY DEFINER
--      olması lazım, yoksa RLS onu da bloke edebilir.
-- Şu an şemanda bu triggerlar yok, yani muhtemelen (a) durumundasın.
-- Çift taraflı kayıt (her transaction için debit=credit toplamı) DB
-- seviyesinde enforce edilmiyor -- bunu Flutter tarafında dikkatli
-- yönetmen gerekiyor, ya da ayrıca bir trigger eklenmeli.
-- ============================================================================
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ledger_entries_own" ON ledger_entries;
CREATE POLICY "ledger_entries_own" ON ledger_entries
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM transactions WHERE id = transaction_id AND user_id = (select auth.uid()))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM transactions WHERE id = transaction_id AND user_id = (select auth.uid()))
    AND (
      account_id IS NULL
      OR EXISTS (SELECT 1 FROM accounts WHERE id = account_id AND user_id = (select auth.uid()))
    )
  );


-- ============================================================================
-- 11. AUDIT_LOG
-- user_id yok, changed_by var. Normal kullanıcı buraya elle yazmamalı --
-- bu tablo trigger'lar tarafından otomatik doldurulmalı (SECURITY DEFINER
-- fonksiyon ile, RLS'i bypass ederek). Şu an şemanda audit trigger'ı yok;
-- eklersen fonksiyonu SECURITY DEFINER yapmayı unutma, yoksa RLS onu da
-- engeller.
--
-- Kullanıcıya sadece SELECT (kendi işlemlerinin logu) izni veriyoruz.
-- INSERT/UPDATE/DELETE policy'si YOK -- yani hiçbir authenticated kullanıcı
-- (client'tan) bu tabloya yazamaz. Sadece SECURITY DEFINER trigger'lar
-- yazabilir.
-- ============================================================================
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "audit_log_select_own" ON audit_log;
CREATE POLICY "audit_log_select_own" ON audit_log
  FOR SELECT
  USING (changed_by = (select auth.uid()));


-- ============================================================================
-- KONTROL SORGUSU
-- Tüm tablolarda RLS'in gerçekten aktif olduğunu doğrulamak için:
-- ============================================================================
-- SELECT schemaname, tablename, rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;
--
-- rowsecurity = true olmayan bir tablo varsa o tablo TAMAMEN AÇIK demektir.