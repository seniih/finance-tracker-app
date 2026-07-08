-- ============================================================================
-- Atomik İşlem Kaydı (transactions + ledger_entries tek transaction'da)
--
-- SORUN: Uygulama şimdiye kadar bir işlemi iki ayrı istekle kaydediyordu:
--   1) INSERT INTO transactions  2) INSERT INTO ledger_entries
-- İkinci adım başarısız olursa (ağ kopması, RLS, validasyon...) ortada
-- ledger'ı olmayan bir işlem kalıyordu -- yani işlem listede görünüyor ama
-- hiçbir kasanın bakiyesini etkilemiyordu. Güncellemede durum daha da
-- kötüydü: eski ledger satırları silindikten sonra yenilerinin insert'i
-- başarısız olursa işlem tamamen "bakiyesiz" kalıyordu. Muhasebe verisinde
-- bu kabul edilemez -- bu migration iki RPC fonksiyonuyla her iki akışı da
-- tek bir Postgres transaction'ına taşıyor (fonksiyon gövdesi atomiktir:
-- herhangi bir adım hata verirse tamamı geri alınır).
--
-- AYRICA (savunma katmanı): ledger yazılan her hesabın para birimi, işlemin
-- para birimiyle aynı olmak ZORUNDA. account_balances view'i hesap bakiyesini
-- ledger tutarlarını para birimine bakmadan toplayarak hesapladığından,
-- TRY hesabına USD tutarlı bir ledger yazmak bakiyeyi sessizce bozar.
-- Bu kural artık DB seviyesinde de denetleniyor (UI'daki kontrolün yanında).
--
-- GÜVENLİK: Fonksiyonlar SECURITY INVOKER (varsayılan) -- çağıran
-- kullanıcının yetkileriyle çalışır, yani mevcut RLS policy'leri
-- (transactions_own, ledger_entries_own, accounts_own) aynen uygulanır.
-- user_id istemciden alınmaz, auth.uid()'den yazılır; güncellemede de
-- WHERE user_id = auth.uid() ile sahiplik ayrıca doğrulanır.
--
-- ESKİ user_id BUG'I: Güncelleme akışı istemciden user_id = '' (geçersiz
-- uuid) gönderiyordu ve her işlem düzenlemesi "invalid input syntax for
-- type uuid" hatasıyla patlıyordu. RPC user_id'ye hiç dokunmadığından bu
-- hata sınıfı tamamen ortadan kalkıyor.
--
-- NULL ALANLAR: update fonksiyonu tüm opsiyonel kolonları (description,
-- contact_id, category_id...) parametreden gelen değerle AÇIKÇA yazar --
-- böylece kullanıcı düzenlemede bir alanı boşalttığında değer gerçekten
-- NULL'a çekilir (eski akışta "if (x != null)" yüzünden temizlenemiyordu).
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- Ortak doğrulama: ledger listesi geçerli mi?
--   * en az bir satır olmalı (ledger'sız işlem bakiye etkilemez -- yasak)
--   * entry_type 'debit'/'credit' olmalı, tutar pozitif olmalı
--   * hesap çağıran kullanıcıya ait olmalı VE para birimi işleminkiyle
--     aynı olmalı (bakiye bozulmasına karşı ana koruma)
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_validate_ledgers(p_ledgers jsonb, p_currency text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_ledger jsonb;
  v_account_currency text;
BEGIN
  IF p_ledgers IS NULL OR jsonb_typeof(p_ledgers) <> 'array' OR jsonb_array_length(p_ledgers) = 0 THEN
    RAISE EXCEPTION 'İşlem en az bir kasa/hesap hareketi (ledger) içermelidir.';
  END IF;

  FOR v_ledger IN SELECT * FROM jsonb_array_elements(p_ledgers) LOOP
    IF (v_ledger->>'entry_type') NOT IN ('debit', 'credit') THEN
      RAISE EXCEPTION 'Geçersiz hareket tipi: %', v_ledger->>'entry_type';
    END IF;
    IF COALESCE((v_ledger->>'amount')::numeric, 0) <= 0 THEN
      RAISE EXCEPTION 'Hareket tutarı pozitif olmalıdır.';
    END IF;
    IF (v_ledger->>'account_id') IS NULL THEN
      RAISE EXCEPTION 'Hareket için hesap/kasa seçilmelidir.';
    END IF;

    -- Hesap sahiplik + para birimi kontrolü (RLS zaten satırı filtreler ama
    -- açık bir Türkçe hata mesajı verebilmek için burada da bakıyoruz).
    SELECT currency INTO v_account_currency
      FROM public.accounts
     WHERE id = (v_ledger->>'account_id')::uuid
       AND user_id = (SELECT auth.uid());

    IF v_account_currency IS NULL THEN
      RAISE EXCEPTION 'Hesap bulunamadı veya bu hesaba erişim yetkiniz yok.';
    END IF;
    IF v_account_currency <> p_currency THEN
      RAISE EXCEPTION 'Para birimi uyuşmazlığı: işlem % ama seçilen hesap % cinsinden. Hesabın para birimiyle aynı olmalı.',
        p_currency, v_account_currency;
    END IF;
  END LOOP;
END;
$$;


-- ────────────────────────────────────────────────────────────────────────────
-- Yeni işlem + ledger satırları (atomik). Yeni işlemin id'sini döner.
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_transaction_with_ledgers(
  p_transaction_type text,
  p_amount numeric,
  p_currency text,
  p_exchange_rate numeric,
  p_transaction_date timestamptz,
  p_description text,
  p_project_id uuid,
  p_land_id uuid,
  p_contact_id uuid,
  p_account_id uuid,
  p_to_account_id uuid,
  p_category_id uuid,
  p_ledgers jsonb
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF COALESCE(p_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'İşlem tutarı pozitif olmalıdır.';
  END IF;

  PERFORM public.fn_validate_ledgers(p_ledgers, p_currency);

  INSERT INTO public.transactions (
    user_id, transaction_type, amount, currency, exchange_rate,
    transaction_date, description,
    project_id, land_id, contact_id, account_id, to_account_id, category_id
  ) VALUES (
    (SELECT auth.uid()), p_transaction_type, p_amount, p_currency, COALESCE(p_exchange_rate, 1),
    COALESCE(p_transaction_date, now()), p_description,
    p_project_id, p_land_id, p_contact_id, p_account_id, p_to_account_id, p_category_id
  )
  RETURNING id INTO v_id;

  INSERT INTO public.ledger_entries (transaction_id, account_id, entry_type, amount)
  SELECT v_id,
         (l->>'account_id')::uuid,
         l->>'entry_type',
         (l->>'amount')::numeric
    FROM jsonb_array_elements(p_ledgers) AS l;

  RETURN v_id;
END;
$$;


-- ────────────────────────────────────────────────────────────────────────────
-- İşlem güncelleme + ledger'ları yeniden kurma (atomik).
-- Hesap/tutar/yön değişmiş olabileceğinden eski ledger satırları silinip
-- güncel listeden yeniden oluşturulur -- hepsi tek transaction içinde.
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_transaction_with_ledgers(
  p_id uuid,
  p_transaction_type text,
  p_amount numeric,
  p_currency text,
  p_exchange_rate numeric,
  p_transaction_date timestamptz,
  p_description text,
  p_project_id uuid,
  p_land_id uuid,
  p_contact_id uuid,
  p_account_id uuid,
  p_to_account_id uuid,
  p_category_id uuid,
  p_ledgers jsonb
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF COALESCE(p_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'İşlem tutarı pozitif olmalıdır.';
  END IF;

  PERFORM public.fn_validate_ledgers(p_ledgers, p_currency);

  UPDATE public.transactions SET
    transaction_type = p_transaction_type,
    amount           = p_amount,
    currency         = p_currency,
    exchange_rate    = COALESCE(p_exchange_rate, 1),
    transaction_date = COALESCE(p_transaction_date, transaction_date),
    description      = p_description,   -- NULL gelirse alan gerçekten temizlenir
    project_id       = p_project_id,
    land_id          = p_land_id,
    contact_id       = p_contact_id,
    account_id       = p_account_id,
    to_account_id    = p_to_account_id,
    category_id      = p_category_id,
    updated_at       = now()
  WHERE id = p_id
    AND user_id = (SELECT auth.uid());

  IF NOT FOUND THEN
    RAISE EXCEPTION 'İşlem bulunamadı veya bu işlemi düzenleme yetkiniz yok.';
  END IF;

  DELETE FROM public.ledger_entries WHERE transaction_id = p_id;

  INSERT INTO public.ledger_entries (transaction_id, account_id, entry_type, amount)
  SELECT p_id,
         (l->>'account_id')::uuid,
         l->>'entry_type',
         (l->>'amount')::numeric
    FROM jsonb_array_elements(p_ledgers) AS l;
END;
$$;


-- ────────────────────────────────────────────────────────────────────────────
-- Yetkiler: yalnızca giriş yapmış kullanıcılar çağırabilir.
-- ────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.fn_validate_ledgers(jsonb, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_transaction_with_ledgers(text, numeric, text, numeric, timestamptz, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_transaction_with_ledgers(uuid, text, numeric, text, numeric, timestamptz, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb) FROM PUBLIC;

-- fn_validate_ledgers, SECURITY INVOKER fonksiyonların içinden çağrıldığı
-- için çağıran rolün (authenticated) bu fonksiyonda da EXECUTE yetkisi
-- olmalı -- aksi halde RPC'ler "permission denied" ile başarısız olur.
-- Fonksiyon salt-okunur bir doğrulama olduğundan bu güvenli.
GRANT EXECUTE ON FUNCTION public.fn_validate_ledgers(jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_transaction_with_ledgers(text, numeric, text, numeric, timestamptz, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_transaction_with_ledgers(uuid, text, numeric, text, numeric, timestamptz, text, uuid, uuid, uuid, uuid, uuid, uuid, jsonb) TO authenticated;
