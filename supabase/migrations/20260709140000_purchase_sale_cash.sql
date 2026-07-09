-- ============================================================================
-- Alış / Satış akışları + kasa entegrasyonu
--
-- Alış: projeye yapılan HER TÜR harcama (arsa alımı, tapu, komisyon,
--   inşaat...) bir 'purchase' işlemi olur. Kasadan çıkar (credit ledger),
--   proje maliyeti = projenin purchase işlemlerinin toplamı. Arsa ayrımı
--   yapılmaz (kullanıcı kararı: "alışlar... hepsi projenin maliyeti").
--
-- Satış: arsa satışında satış tutarı SEÇİLEN KASAYA girer ('sale' işlemi,
--   debit ledger). Kullanıcı kar payını artık TL değil YÜZDE olarak girer;
--   TL karşılığı DB hesaplar. Kalan tutar yatırımcılara sermaye oranlı
--   dağıtılır (önceki migration'daki fn_distribute_land_sale) ve bu dağıtım
--   satırları yatırımcılara BORÇ olarak cari bakiyesine yansıtılır
--   (investor_sale_debts view'i üzerinden, uygulama tarafında).
--
-- Tasarım kararları:
-- 1) Kar payı yüzde olarak saklanır (owner_profit_pct); TL karşılığı
--    (owner_profit_try) GENERATED kolon -- satış fiyatı güncellenirse TL
--    kar payı otomatik güncellenir, çelişki imkansız (tek doğruluk kaynağı).
--    Dağıtım fonksiyonu owner_profit_try okuduğundan değişiklik gerektirmez.
-- 2) Satış + kasa işlemi TEK Postgres transaction'ında yazılır
--    (create_land_sale_with_cash RPC) -- atomic_transaction_rpc ile aynı
--    gerekçe: yarım kayıt (kasasız satış / satışsız kasa girişi) olamaz.
--    İşlem tutarı TL olduğundan seçilen kasa TRY olmalı; kontrolü mevcut
--    fn_validate_ledgers yapar (anlaşılır Türkçe hatayla).
-- 3) Satış silinince bağlı kasa işlemi de trigger'la silinir (satış geliri
--    kasada "hayalet" kalamaz). Kasa işlemi geçmiş ekranından tek başına
--    silinirse land_sales.transaction_id SET NULL olur -- satış kaydı
--    kalır ama kasa bağı kopar (bilinçli: satışı silmek ayrı bir karardır).
-- 4) Yatırımcı borçları için ayrı tablo YOK: borç = dağıtım satırının
--    kendisi (tek doğruluk kaynağı). investor_sale_debts view'i cari başına
--    toplam borcu döner; yatırımcıya yapılan ödemeler mevcut Ödeme (gider)
--    işlemiyle girilir ve cari bakiyesinde borcu düşer.
-- 5) Eski land_sales satırları (varsa) TL kar payı ile girilmişti; yüzdeye
--    çevrilemeyeceğinden ve korunacak veri olmadığı onaylandığından silinir.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. Yeni işlem tipleri: purchase (Alış) ve sale (Satış)
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.transactions
  DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_transaction_type_check
    CHECK (transaction_type IN ('standard', 'transfer', 'investment_in', 'investment_out', 'purchase', 'sale'));


-- ────────────────────────────────────────────────────────────────────────────
-- 2. land_sales: kar payı yüzdeye geçiyor + kasa işlemi bağı
-- ────────────────────────────────────────────────────────────────────────────
DELETE FROM public.land_sales;  -- eski TL kar paylı kayıtlar (bkz. karar #5)

-- Trigger UPDATE OF owner_profit_try ile bu kolona bağımlı; kolon
-- düşürülmeden önce kaldırılmalı (aşağıda yeni tanımıyla yeniden kurulur).
DROP TRIGGER IF EXISTS trg_distribute_on_sale ON public.land_sales;

ALTER TABLE public.land_sales
  DROP CONSTRAINT IF EXISTS land_sales_owner_profit_lte_price;

ALTER TABLE public.land_sales
  DROP COLUMN IF EXISTS owner_profit_try;

ALTER TABLE public.land_sales
  ADD COLUMN owner_profit_pct numeric(5,2) NOT NULL DEFAULT 0
    CHECK (owner_profit_pct >= 0 AND owner_profit_pct <= 100);

-- TL karşılığı DB hesaplar; fn_distribute_land_sale bu kolonu okumaya
-- devam eder (satış - owner_profit_try sermaye oranlı dağıtılır).
ALTER TABLE public.land_sales
  ADD COLUMN owner_profit_try numeric(15,2) GENERATED ALWAYS AS (
    round(sale_price_try * owner_profit_pct / 100.0, 2)
  ) STORED;

ALTER TABLE public.land_sales
  ADD COLUMN transaction_id uuid REFERENCES public.transactions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS land_sales_transaction_idx ON public.land_sales (transaction_id);

-- Dağıtım trigger'ını yeniden kur: artık yüzde değişimini dinler
-- (owner_profit_try GENERATED olduğundan UPDATE OF listesinde kullanılamaz;
--  eski tanım yukarıda, kolon düşürülmeden önce kaldırıldı).
CREATE TRIGGER trg_distribute_on_sale
  AFTER INSERT OR UPDATE OF sale_price_try, owner_profit_pct
  ON public.land_sales
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_distribute_on_sale();


-- ────────────────────────────────────────────────────────────────────────────
-- 3. Atomik satış + kasa girişi RPC
--    SECURITY INVOKER: RLS aynen uygulanır; user_id auth.uid()'den.
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_land_sale_with_cash(
  p_land_id uuid,
  p_sale_price_try numeric,
  p_usd_rate numeric,
  p_owner_profit_pct numeric,
  p_sale_date date,
  p_buyer_contact_id uuid,
  p_account_id uuid,
  p_description text
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_project_id uuid;
  v_trx_id uuid;
  v_sale_id uuid;
BEGIN
  IF COALESCE(p_sale_price_try, 0) <= 0 THEN
    RAISE EXCEPTION 'Satış tutarı pozitif olmalıdır.';
  END IF;
  IF p_account_id IS NULL THEN
    RAISE EXCEPTION 'Satış geliri için bir kasa/hesap seçilmelidir.';
  END IF;

  -- Arsa sahiplik kontrolü (RLS de filtreler; açık mesaj için bakıyoruz)
  SELECT project_id INTO v_project_id
    FROM public.lands
   WHERE id = p_land_id AND user_id = (SELECT auth.uid());
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Arsa bulunamadı veya erişim yetkiniz yok.';
  END IF;

  -- Kasa girişi: satış tutarı kasaya debit yazılır. Para birimi TL --
  -- kasa TRY değilse fn_validate_ledgers anlaşılır hatayla durdurur.
  v_trx_id := public.create_transaction_with_ledgers(
    'sale',
    p_sale_price_try,
    'TRY',
    NULL,
    COALESCE(p_sale_date, CURRENT_DATE)::timestamptz,
    p_description,
    v_project_id,
    p_land_id,
    p_buyer_contact_id,
    p_account_id,
    NULL,
    NULL,
    jsonb_build_array(jsonb_build_object(
      'account_id', p_account_id,
      'entry_type', 'debit',
      'amount', p_sale_price_try
    ))
  );

  -- Satış kaydı: trigger'lar dağıtımı hesaplar ve arsayı 'sold' yapar.
  INSERT INTO public.land_sales
        (land_id, sale_price_try, usd_rate, owner_profit_pct, sale_date,
         buyer_contact_id, description, transaction_id)
  VALUES (p_land_id, p_sale_price_try, p_usd_rate, COALESCE(p_owner_profit_pct, 0),
          COALESCE(p_sale_date, CURRENT_DATE), p_buyer_contact_id, p_description, v_trx_id)
  RETURNING id INTO v_sale_id;

  RETURN v_sale_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_land_sale_with_cash(uuid, numeric, numeric, numeric, date, uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_land_sale_with_cash(uuid, numeric, numeric, numeric, date, uuid, uuid, text) TO authenticated;
ALTER FUNCTION public.create_land_sale_with_cash(uuid, numeric, numeric, numeric, date, uuid, uuid, text) SET search_path = '';


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Satış silinince bağlı kasa işlemi de silinsin
--    SECURITY INVOKER: kullanıcı kendi işlemini silebilir (RLS).
--    ledger_entries ON DELETE CASCADE ile temizlenir.
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_trg_delete_sale_cash()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF OLD.transaction_id IS NOT NULL THEN
    DELETE FROM public.transactions WHERE id = OLD.transaction_id;
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_delete_sale_cash ON public.land_sales;
CREATE TRIGGER trg_delete_sale_cash
  AFTER DELETE
  ON public.land_sales
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_delete_sale_cash();


-- ────────────────────────────────────────────────────────────────────────────
-- 5. investor_sale_debts: cari başına toplam satış dağıtım borcu (TL)
--    Borcun kaynağı dağıtım satırlarıdır (ayrı borç tablosu yok -- tek
--    doğruluk kaynağı). security_invoker: RLS policy'leri view üzerinden
--    de uygulanır (account_balances ile aynı önlem).
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.investor_sale_debts
WITH (security_invoker = true) AS
SELECT
  pi.contact_id,
  SUM(d.amount_try) AS total_debt_try
FROM public.land_sale_distributions d
JOIN public.project_investors pi ON pi.id = d.project_investor_id
GROUP BY pi.contact_id;

GRANT SELECT ON public.investor_sale_debts TO authenticated;
