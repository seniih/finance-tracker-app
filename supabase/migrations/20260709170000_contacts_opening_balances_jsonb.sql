-- ============================================================================
-- Cari Açılış Bakiyesi: Çoklu Para Birimi Desteği
--
-- Mevcut tek-bakiye yaklaşımı (opening_balance + opening_balance_currency)
-- yerine, birden fazla para biriminde devir bakiyesi tutabilmek için JSONB
-- sütununa geçiliyor.
--
-- Format: {"TRY": 5000, "USD": -200}
--   pozitif = cari bana borçlu, negatif = ben cariye borçluyum
-- ============================================================================

-- 1) Yeni JSONB sütunu ekle
ALTER TABLE public.contacts
  ADD COLUMN IF NOT EXISTS opening_balances jsonb NOT NULL DEFAULT '{}';

-- 2) Mevcut verileri yeni sütuna migrate et
UPDATE public.contacts
SET opening_balances = jsonb_build_object(opening_balance_currency, opening_balance)
WHERE opening_balance != 0;

-- 3) Eski sütunları kaldır
ALTER TABLE public.contacts
  DROP COLUMN IF EXISTS opening_balance,
  DROP COLUMN IF EXISTS opening_balance_currency;
