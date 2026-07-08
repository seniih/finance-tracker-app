-- ============================================================================
-- Arsa Yatırımcı Sistemi (Proje -> Arsa -> Yatırımcı -> Ödeme -> Satış)
--
-- İhtiyaç: Bir projenin arsa blokları ve bu arsaların yatırımcıları var.
-- Her yatırımcı için:
--   * % kaç ortak olduğu (share_percentage -- land_contacts'ta zaten var)
--   * ne zaman, kaç TL yatırdığı
--   * yatırdığı andaki dolar kuru ve TL tutarın USD karşılığı
-- Arsa satılırsa:
--   * satış tutarı (TL + o günkü kur + USD karşılığı)
--   * kullanıcının girdiği yüzdelerle yatırımcılara paylaştırma
--
-- Tasarım kararları:
-- 1) Ödemeler tek tutar yerine SATIR SATIR tutulur (land_investments).
--    Bir yatırımcı farklı tarihlerde, farklı kurlarla ödeme yapabilir;
--    "toplam yatırım" bu satırların toplamıdır. land_contacts üzerindeki
--    eski investment_amount / paid_amount / remaining_amount kolonları bu
--    yüzden KALDIRILDI -- tek tutar + türetilmiş alanları elle tutmak,
--    satır bazlı kayıtla çelişki riski yaratırdı (tek doğruluk kaynağı ilkesi).
--    Mevcut paid_amount verisi varsa kayıp olmasın diye land_investments'a
--    tek satır olarak aktarılıyor (kur bilinmediği için usd_rate NULL).
-- 2) amount_usd / sale_price_usd GENERATED kolon: TL tutar ve kurdan DB
--    hesaplar, uygulama yazamaz -- "tutar ile USD karşılığı çelişiyor"
--    durumu imkansız hale gelir. usd_rate NULL bırakılabilir (eski/devir
--    kayıtlar için); o durumda USD karşılığı da NULL olur. UI yeni
--    kayıtlarda kuru zorunlu tutar.
-- 3) Satış tek tablo (land_sales, land_id UNIQUE -- bir arsa bir kez
--    satılır) + dağıtım satırları (land_sale_distributions). Dağıtım
--    yüzdesini KULLANICI girer (ortaklık yüzdesinden farklı olabilir --
--    aralarındaki anlaşmaya göre); tutarı DB trigger'ı hesaplar ve satış
--    fiyatı güncellenirse tüm dağıtım tutarları otomatik yeniden hesaplanır.
--    Yüzde toplamının 100'ü aşması DB seviyesinde engellenir.
-- 4) Satış kaydı eklenince arsanın durumu otomatik 'sold' olur, satış
--    silinirse 'purchased'a döner (trigger). lands.status ve
--    land_contacts.role kolonları Dart modellerinde zaten vardı ama DB'de
--    yoktu -- bu migration şemayı modellerle hizalıyor.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. Şema hizalama: lands.status + land_contacts.role
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.lands
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'purchased'
    CHECK (status IN ('purchased', 'for_sale', 'sold'));

ALTER TABLE public.land_contacts
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'investor'
    CHECK (role IN ('investor', 'partner', 'broker', 'other'));

-- Aynı arsaya aynı cari iki kez yatırımcı olarak eklenemesin
CREATE UNIQUE INDEX IF NOT EXISTS land_contacts_land_contact_uniq
  ON public.land_contacts (land_id, contact_id);

-- Ortaklık yüzdesi 0-100 aralığında olmalı
ALTER TABLE public.land_contacts
  DROP CONSTRAINT IF EXISTS land_contacts_share_percentage_check,
  ADD CONSTRAINT land_contacts_share_percentage_check
    CHECK (share_percentage IS NULL OR (share_percentage >= 0 AND share_percentage <= 100));


-- ────────────────────────────────────────────────────────────────────────────
-- 2. land_investments: yatırımcı ödemeleri (satır bazlı)
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.land_investments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    land_contact_id uuid NOT NULL REFERENCES public.land_contacts(id) ON DELETE CASCADE,

    amount_try numeric(15,2) NOT NULL CHECK (amount_try > 0),

    -- Ödeme anındaki USD/TRY kuru. NULL = bilinmiyor (eski/devir kayıt).
    usd_rate numeric(15,4) CHECK (usd_rate IS NULL OR usd_rate > 0),

    -- USD karşılığı DB tarafından hesaplanır, uygulama yazamaz.
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

CREATE INDEX IF NOT EXISTS land_investments_land_contact_idx
  ON public.land_investments (land_contact_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 3. Eski tek-tutar verisini taşı, sonra eski kolonları kaldır
-- ────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'land_contacts'
      AND column_name = 'paid_amount'
  ) THEN
    INSERT INTO public.land_investments (land_contact_id, amount_try, usd_rate, payment_date, description)
    SELECT id, paid_amount, NULL, COALESCE(created_at::date, CURRENT_DATE),
           'Eski kayıttan aktarılan toplam ödeme (kur bilinmiyor)'
    FROM public.land_contacts
    WHERE COALESCE(paid_amount, 0) > 0;
  END IF;
END $$;

ALTER TABLE public.land_contacts
  DROP COLUMN IF EXISTS investment_amount,
  DROP COLUMN IF EXISTS paid_amount,
  DROP COLUMN IF EXISTS remaining_amount;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. land_sales: arsa satışı (arsa başına en fazla bir satış)
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.land_sales (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    land_id uuid NOT NULL UNIQUE REFERENCES public.lands(id) ON DELETE CASCADE,

    sale_price_try numeric(15,2) NOT NULL CHECK (sale_price_try > 0),

    usd_rate numeric(15,4) CHECK (usd_rate IS NULL OR usd_rate > 0),

    sale_price_usd numeric(15,2) GENERATED ALWAYS AS (
      CASE WHEN usd_rate IS NULL OR usd_rate = 0
           THEN NULL
           ELSE round(sale_price_try / usd_rate, 2)
      END
    ) STORED,

    sale_date date NOT NULL DEFAULT CURRENT_DATE,

    -- Alıcı da bir cari olarak seçilebilir (opsiyonel)
    buyer_contact_id uuid REFERENCES public.contacts(id) ON DELETE SET NULL,

    description text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS land_sales_land_idx ON public.land_sales (land_id);
CREATE INDEX IF NOT EXISTS land_sales_buyer_idx ON public.land_sales (buyer_contact_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 5. land_sale_distributions: satış tutarının yüzdelik dağıtımı
--    Yüzdeyi kullanıcı girer, TL tutarını trigger hesaplar.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.land_sale_distributions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    land_sale_id uuid NOT NULL REFERENCES public.land_sales(id) ON DELETE CASCADE,
    land_contact_id uuid NOT NULL REFERENCES public.land_contacts(id) ON DELETE RESTRICT,

    percentage numeric(5,2) NOT NULL CHECK (percentage >= 0 AND percentage <= 100),

    -- Trigger doldurur: sale_price_try * percentage / 100
    amount_try numeric(15,2) NOT NULL DEFAULT 0,

    notes text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),

    UNIQUE (land_sale_id, land_contact_id)
);

CREATE INDEX IF NOT EXISTS land_sale_distributions_sale_idx
  ON public.land_sale_distributions (land_sale_id);
CREATE INDEX IF NOT EXISTS land_sale_distributions_land_contact_idx
  ON public.land_sale_distributions (land_contact_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 6. Trigger'lar
-- ────────────────────────────────────────────────────────────────────────────

-- 6a. Dağıtım tutarını hesapla (insert veya yüzde değişikliğinde)
CREATE OR REPLACE FUNCTION public.fn_calc_distribution_amount()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  SELECT round(s.sale_price_try * NEW.percentage / 100.0, 2)
    INTO NEW.amount_try
    FROM public.land_sales s
   WHERE s.id = NEW.land_sale_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calc_distribution_amount ON public.land_sale_distributions;
CREATE TRIGGER trg_calc_distribution_amount
  BEFORE INSERT OR UPDATE OF percentage, land_sale_id
  ON public.land_sale_distributions
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_calc_distribution_amount();

-- 6b. Satış fiyatı değişirse tüm dağıtım tutarlarını yeniden hesapla
CREATE OR REPLACE FUNCTION public.fn_recalc_distributions_on_sale_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.land_sale_distributions d
     SET amount_try = round(NEW.sale_price_try * d.percentage / 100.0, 2),
         updated_at = now()
   WHERE d.land_sale_id = NEW.id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_recalc_distributions ON public.land_sales;
CREATE TRIGGER trg_recalc_distributions
  AFTER UPDATE OF sale_price_try
  ON public.land_sales
  FOR EACH ROW
  WHEN (OLD.sale_price_try IS DISTINCT FROM NEW.sale_price_try)
  EXECUTE FUNCTION public.fn_recalc_distributions_on_sale_update();

-- 6c. Yüzde toplamı 100'ü aşamaz (satış bazında).
--     Statement sonunda çalışan constraint trigger: aynı statement içinde
--     birden çok satır eklense bile toplamı bir kez, bütün olarak kontrol eder.
CREATE OR REPLACE FUNCTION public.fn_check_distribution_total()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_total numeric;
  v_sale_id uuid;
BEGIN
  v_sale_id := COALESCE(NEW.land_sale_id, OLD.land_sale_id);

  SELECT COALESCE(SUM(percentage), 0)
    INTO v_total
    FROM public.land_sale_distributions
   WHERE land_sale_id = v_sale_id;

  IF v_total > 100.0 THEN
    RAISE EXCEPTION 'Dağıtım yüzdelerinin toplamı %% 100''ü aşamaz (şu an: %)', v_total;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_distribution_total ON public.land_sale_distributions;
CREATE CONSTRAINT TRIGGER trg_check_distribution_total
  AFTER INSERT OR UPDATE OF percentage
  ON public.land_sale_distributions
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_check_distribution_total();

-- 6d. Satış kaydı eklenince arsa 'sold', satış silinirse 'purchased' olur
CREATE OR REPLACE FUNCTION public.fn_sync_land_status_on_sale()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.lands SET status = 'sold', updated_at = now() WHERE id = NEW.land_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.lands SET status = 'purchased', updated_at = now() WHERE id = OLD.land_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_land_status ON public.land_sales;
CREATE TRIGGER trg_sync_land_status
  AFTER INSERT OR DELETE
  ON public.land_sales
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_land_status_on_sale();


-- ────────────────────────────────────────────────────────────────────────────
-- 7. RLS -- sahiplik zinciri: tablo -> ... -> lands.user_id
--    (rls_policies.sql'deki land_contacts deseniyle aynı yaklaşım)
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.land_investments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "land_investments_own" ON public.land_investments;
CREATE POLICY "land_investments_own" ON public.land_investments
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
        FROM public.land_contacts lc
        JOIN public.lands l ON l.id = lc.land_id
       WHERE lc.id = land_contact_id
         AND l.user_id = (select auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
        FROM public.land_contacts lc
        JOIN public.lands l ON l.id = lc.land_id
       WHERE lc.id = land_contact_id
         AND l.user_id = (select auth.uid())
    )
  );

ALTER TABLE public.land_sales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "land_sales_own" ON public.land_sales;
CREATE POLICY "land_sales_own" ON public.land_sales
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.lands WHERE id = land_id AND user_id = (select auth.uid()))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.lands WHERE id = land_id AND user_id = (select auth.uid()))
    AND (
      buyer_contact_id IS NULL
      OR EXISTS (SELECT 1 FROM public.contacts WHERE id = buyer_contact_id AND user_id = (select auth.uid()))
    )
  );

ALTER TABLE public.land_sale_distributions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "land_sale_distributions_own" ON public.land_sale_distributions;
CREATE POLICY "land_sale_distributions_own" ON public.land_sale_distributions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
        FROM public.land_sales s
        JOIN public.lands l ON l.id = s.land_id
       WHERE s.id = land_sale_id
         AND l.user_id = (select auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
        FROM public.land_sales s
        JOIN public.lands l ON l.id = s.land_id
       WHERE s.id = land_sale_id
         AND l.user_id = (select auth.uid())
    )
    AND EXISTS (
      SELECT 1
        FROM public.land_contacts lc
        JOIN public.lands l2 ON l2.id = lc.land_id
       WHERE lc.id = land_contact_id
         AND l2.user_id = (select auth.uid())
    )
  );


-- ────────────────────────────────────────────────────────────────────────────
-- 8. GRANT'ler (grants.sql ile aynı mantık: tablo erişimi + RLS satır filtresi)
-- ────────────────────────────────────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON public.land_investments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.land_sales TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.land_sale_distributions TO authenticated;
