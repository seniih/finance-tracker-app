-- ============================================================================
-- Kar Merkezi -> Proje -> Arsa + Yatırımcı yapısına geçiş
--
-- Eski yapı: proje -> arsa -> arsa bazlı yatırımcı (land_contacts) ->
-- ödemeler (land_investments) + satışta kullanıcı yüzdeli dağıtım.
--
-- Yeni yapı:
--   profit_centers (kar merkezi)  -> basit gruplama: isim + açıklama
--     └─ projects                 -> artık bir kar merkezine bağlı
--          ├─ lands               -> projenin ÜRÜNLERİ (alınıp satılan arsalar)
--          └─ project_investors   -> projeye SERMAYE koyan cariler
--               └─ project_investments -> sermaye ödemeleri (TL + kur + USD)
--
-- Satış dağıtımı kuralı (kullanıcı kararı):
--   * Her satışta kullanıcı KENDİSİ için bir kar payı (owner_profit_try) girer.
--   * Kalan tutar (satış - kar payı) yatırımcılara SERMAYE ORANLARINA göre
--     otomatik dağıtılır: pay_i = kalan * sermaye_i / toplam_sermaye.
--
-- Tasarım kararları:
-- 1) Yatırımcıda yüzde kolonu YOK: ortaklık oranı zaten sermaye ödemelerinden
--    türetilir (tek doğruluk kaynağı ilkesi -- elle tutulan yüzde, satır bazlı
--    ödeme kayıtlarıyla çelişebilirdi).
-- 2) Dağıtım satırlarını UYGULAMA DEĞİL, DB hesaplar (SECURITY DEFINER
--    fonksiyon + trigger). authenticated rolüne tabloya yazma GRANT'i
--    verilmez -- istemci dağıtımı manipüle edemez, sadece okur.
-- 3) Dağıtım "güncel sermaye oranını" yansıtır: satış tutarı/kar payı
--    değişince VE proje sermaye ödemeleri değişince (ekle/sil/güncelle)
--    yeniden hesaplanır. Böylece ekranda görünen sermaye oranı ile dağıtım
--    asla çelişmez. capital_basis_try kolonu, hesap anındaki sermayeyi
--    şeffaflık için saklar (denetim/izleme amaçlı).
-- 4) Kuruş yuvarlama farkı en yüksek sermayeli yatırımcıya eklenir --
--    dağıtım toplamı her zaman tam olarak (satış - kar payı) eder.
-- 5) Mevcut projects satırları transactions tarafından referans edildiğinden
--    silinmez; kullanıcı başına "Genel" kar merkezi açılıp oraya bağlanır,
--    sonra profit_center_id NOT NULL yapılır.
-- 6) Eski arsa bazlı yatırımcı verileri kullanıcı onayıyla SİLİNİR
--    (korunacak gerçek veri yok); land_sales kayıtları da eski dağıtım
--    mantığıyla üretildiğinden temizlenir (trigger arsaları 'purchased'a
--    döndürür).
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. Eski yapının sökümü
-- ────────────────────────────────────────────────────────────────────────────

-- Eski satışlar: yeni dağıtım mantığıyla uyumsuz; silinince trg_sync_land_status
-- arsa durumlarını otomatik 'purchased'a döndürür.
DELETE FROM public.land_sales;

DROP TRIGGER IF EXISTS trg_calc_distribution_amount ON public.land_sale_distributions;
DROP TRIGGER IF EXISTS trg_check_distribution_total ON public.land_sale_distributions;
DROP TRIGGER IF EXISTS trg_recalc_distributions ON public.land_sales;

DROP FUNCTION IF EXISTS public.fn_calc_distribution_amount();
DROP FUNCTION IF EXISTS public.fn_check_distribution_total();
DROP FUNCTION IF EXISTS public.fn_recalc_distributions_on_sale_update();

DROP TABLE IF EXISTS public.land_sale_distributions CASCADE;
DROP TABLE IF EXISTS public.land_investments CASCADE;
DROP TABLE IF EXISTS public.land_contacts CASCADE;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. profit_centers: kar merkezi (basit gruplama)
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.profit_centers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    name text NOT NULL,
    description text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX ON public.profit_centers (user_id);

ALTER TABLE public.profit_centers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profit_centers_own" ON public.profit_centers
  FOR ALL
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.profit_centers TO authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- 3. projects.profit_center_id: her proje bir kar merkezine bağlı
--    Mevcut projeler (transactions tarafından referans edilebilir, silinmez)
--    kullanıcı başına açılan "Genel" kar merkezine bağlanır.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.projects
  ADD COLUMN profit_center_id uuid REFERENCES public.profit_centers(id) ON DELETE RESTRICT;

INSERT INTO public.profit_centers (user_id, name, description)
SELECT DISTINCT user_id, 'Genel', 'Yapı değişikliğinde otomatik oluşturuldu'
FROM public.projects;

UPDATE public.projects p
   SET profit_center_id = pc.id
  FROM public.profit_centers pc
 WHERE pc.user_id = p.user_id
   AND pc.name = 'Genel'
   AND p.profit_center_id IS NULL;

ALTER TABLE public.projects
  ALTER COLUMN profit_center_id SET NOT NULL;

CREATE INDEX ON public.projects (profit_center_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 4. project_investors: projeye sermaye koyan cariler
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.project_investors (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
    contact_id uuid NOT NULL REFERENCES public.contacts(id) ON DELETE RESTRICT,

    notes text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),

    -- Aynı cari aynı projeye iki kez yatırımcı olarak eklenemez
    UNIQUE (project_id, contact_id)
);

CREATE INDEX ON public.project_investors (project_id);
CREATE INDEX ON public.project_investors (contact_id);

ALTER TABLE public.project_investors ENABLE ROW LEVEL SECURITY;

-- Sahiplik zinciri: project_investors -> projects.user_id.
-- WITH CHECK ayrıca contact'ın da kullanıcıya ait olduğunu doğrular.
CREATE POLICY "project_investors_own" ON public.project_investors
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.projects WHERE id = project_id AND user_id = (select auth.uid()))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.projects WHERE id = project_id AND user_id = (select auth.uid()))
    AND EXISTS (SELECT 1 FROM public.contacts WHERE id = contact_id AND user_id = (select auth.uid()))
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.project_investors TO authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- 5. project_investments: sermaye ödemeleri (satır bazlı, TL + kur + USD)
--    Eski land_investments ile aynı mantık: USD karşılığı GENERATED kolon,
--    uygulama yazamaz -- tutar/kur/USD çelişkisi imkansız.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.project_investments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    project_investor_id uuid NOT NULL REFERENCES public.project_investors(id) ON DELETE CASCADE,

    amount_try numeric(15,2) NOT NULL CHECK (amount_try > 0),

    -- Ödeme anındaki USD/TRY kuru. NULL = bilinmiyor (eski/devir kayıt).
    usd_rate numeric(15,4) CHECK (usd_rate IS NULL OR usd_rate > 0),

    amount_usd numeric(15,2) GENERATED ALWAYS AS (
      CASE WHEN usd_rate IS NULL OR usd_rate = 0
           THEN NULL
           ELSE round(amount_try / usd_rate, 2)
      END
    ) STORED,

    payment_date date NOT NULL DEFAULT CURRENT_DATE,

    -- İleride kasa entegrasyonu için: ödeme bir işlem kaydına bağlanabilir.
    transaction_id uuid REFERENCES public.transactions(id) ON DELETE SET NULL,

    description text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX ON public.project_investments (project_investor_id);

ALTER TABLE public.project_investments ENABLE ROW LEVEL SECURITY;

-- Sahiplik zinciri: project_investments -> project_investors -> projects.user_id.
-- transaction_id verilirse onun da kullanıcıya ait olması istenir
-- (security_hardening'deki land_investments düzeltmesiyle aynı ders).
CREATE POLICY "project_investments_own" ON public.project_investments
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
        FROM public.project_investors pi
        JOIN public.projects p ON p.id = pi.project_id
       WHERE pi.id = project_investor_id
         AND p.user_id = (select auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
        FROM public.project_investors pi
        JOIN public.projects p ON p.id = pi.project_id
       WHERE pi.id = project_investor_id
         AND p.user_id = (select auth.uid())
    )
    AND (
      transaction_id IS NULL
      OR EXISTS (SELECT 1 FROM public.transactions WHERE id = transaction_id AND user_id = (select auth.uid()))
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.project_investments TO authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- 6. land_sales: kullanıcının kendine yazdığı kar payı
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.land_sales
  ADD COLUMN owner_profit_try numeric(15,2) NOT NULL DEFAULT 0
    CHECK (owner_profit_try >= 0);

-- Kar payı satış tutarını aşamaz (satır bazlı kontrol)
ALTER TABLE public.land_sales
  ADD CONSTRAINT land_sales_owner_profit_lte_price
    CHECK (owner_profit_try <= sale_price_try);


-- ────────────────────────────────────────────────────────────────────────────
-- 7. land_sale_distributions (YENİ): sermaye oranlı otomatik dağıtım
--    Satırları yalnızca DB (fn_distribute_land_sale) yazar; istemciye
--    INSERT/UPDATE/DELETE GRANT'i bilinçli olarak verilmiyor.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.land_sale_distributions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    land_sale_id uuid NOT NULL REFERENCES public.land_sales(id) ON DELETE CASCADE,
    project_investor_id uuid NOT NULL REFERENCES public.project_investors(id) ON DELETE RESTRICT,

    -- Hesap anındaki toplam sermayesi (şeffaflık/denetim için saklanır)
    capital_basis_try numeric(15,2) NOT NULL,

    -- Yatırımcıya düşen pay: (satış - kar payı) * sermaye oranı
    amount_try numeric(15,2) NOT NULL,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),

    UNIQUE (land_sale_id, project_investor_id)
);

CREATE INDEX ON public.land_sale_distributions (land_sale_id);
CREATE INDEX ON public.land_sale_distributions (project_investor_id);

ALTER TABLE public.land_sale_distributions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "land_sale_distributions_select_own" ON public.land_sale_distributions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
        FROM public.land_sales s
        JOIN public.lands l ON l.id = s.land_id
       WHERE s.id = land_sale_id
         AND l.user_id = (select auth.uid())
    )
  );

GRANT SELECT ON public.land_sale_distributions TO authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- 8. Dağıtım hesabı
--
-- fn_distribute_land_sale(sale_id): satışın dağıtım satırlarını komple
-- yeniden kurar. SECURITY DEFINER: tabloya yazma yetkisi istemcide yok,
-- yalnızca bu fonksiyon (tablo sahibi olarak) yazar. search_path=''
-- (security_hardening ile aynı önlem).
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_distribute_land_sale(p_sale_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_sale          public.land_sales%ROWTYPE;
  v_project_id    uuid;
  v_total_capital numeric;
  v_distributable numeric;
  v_sum           numeric;
  v_diff          numeric;
BEGIN
  SELECT * INTO v_sale FROM public.land_sales WHERE id = p_sale_id;
  IF NOT FOUND THEN
    RETURN; -- satış silinmiş; CASCADE dağıtımları da silmiştir
  END IF;

  SELECT project_id INTO v_project_id FROM public.lands WHERE id = v_sale.land_id;

  DELETE FROM public.land_sale_distributions WHERE land_sale_id = p_sale_id;

  IF v_project_id IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(SUM(inv.amount_try), 0)
    INTO v_total_capital
    FROM public.project_investments inv
    JOIN public.project_investors pi ON pi.id = inv.project_investor_id
   WHERE pi.project_id = v_project_id;

  -- Sermaye yoksa dağıtılacak taraf da yok
  IF v_total_capital <= 0 THEN
    RETURN;
  END IF;

  v_distributable := v_sale.sale_price_try - v_sale.owner_profit_try;
  IF v_distributable <= 0 THEN
    RETURN;
  END IF;

  INSERT INTO public.land_sale_distributions
        (land_sale_id, project_investor_id, capital_basis_try, amount_try)
  SELECT p_sale_id,
         pi.id,
         t.capital,
         round(v_distributable * t.capital / v_total_capital, 2)
    FROM (
      SELECT inv.project_investor_id AS pid, SUM(inv.amount_try) AS capital
        FROM public.project_investments inv
        JOIN public.project_investors pi2 ON pi2.id = inv.project_investor_id
       WHERE pi2.project_id = v_project_id
       GROUP BY inv.project_investor_id
    ) t
    JOIN public.project_investors pi ON pi.id = t.pid;

  -- Kuruş yuvarlama farkını en yüksek sermayeli yatırımcıya ekle:
  -- toplam her zaman tam olarak (satış - kar payı) etsin.
  SELECT COALESCE(SUM(amount_try), 0) INTO v_sum
    FROM public.land_sale_distributions WHERE land_sale_id = p_sale_id;

  v_diff := round(v_distributable - v_sum, 2);
  IF v_diff <> 0 THEN
    UPDATE public.land_sale_distributions
       SET amount_try = amount_try + v_diff
     WHERE id = (
       SELECT id FROM public.land_sale_distributions
        WHERE land_sale_id = p_sale_id
        ORDER BY capital_basis_try DESC, id
        LIMIT 1
     );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_distribute_land_sale(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_distribute_land_sale(uuid) TO authenticated;

-- 8a. Satış eklenince / tutar-kar payı değişince dağıt
CREATE OR REPLACE FUNCTION public.fn_trg_distribute_on_sale()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public.fn_distribute_land_sale(NEW.id);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_distribute_on_sale
  AFTER INSERT OR UPDATE OF sale_price_try, owner_profit_try
  ON public.land_sales
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_distribute_on_sale();

-- 8b. Proje sermayesi değişince o projenin TÜM satış dağıtımlarını tazele.
--     Dağıtım "güncel sermaye oranını" yansıtır (tasarım kararı #3):
--     ekranda görünen oran ile dağıtım çelişemez.
CREATE OR REPLACE FUNCTION public.fn_trg_redistribute_on_investment_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_project_id uuid;
  v_sale_id    uuid;
BEGIN
  SELECT pi.project_id INTO v_project_id
    FROM public.project_investors pi
   WHERE pi.id = COALESCE(NEW.project_investor_id, OLD.project_investor_id);

  IF v_project_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  FOR v_sale_id IN
    SELECT s.id
      FROM public.land_sales s
      JOIN public.lands l ON l.id = s.land_id
     WHERE l.project_id = v_project_id
  LOOP
    PERFORM public.fn_distribute_land_sale(v_sale_id);
  END LOOP;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_redistribute_on_investment_change
  AFTER INSERT OR UPDATE OR DELETE
  ON public.project_investments
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_redistribute_on_investment_change();

-- Mevcut fonksiyonlarla aynı sertleştirme düzeyi
ALTER FUNCTION public.fn_trg_distribute_on_sale()                  SET search_path = '';
ALTER FUNCTION public.fn_trg_redistribute_on_investment_change()   SET search_path = '';
