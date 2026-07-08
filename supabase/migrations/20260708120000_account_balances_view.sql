-- ============================================================================
-- Hesap Bakiyeleri View'i (account_balances)
--
-- Sorun: Flutter tarafı şimdiye kadar sadece accounts.opening_balance
-- (açılış bakiyesi) gösteriyordu. Gerçek/güncel bakiye hiçbir yerde
-- hesaplanmıyordu -- oysa Account modelinde bunun için zaten bir
-- `current_balance` alanı ayrılmıştı (bkz. lib/models/account.dart).
--
-- Bu view, her hesabın güncel bakiyesini tek sorguda döner:
--   current_balance = opening_balance + SUM(debit) - SUM(credit)
--     debit  -> hesaba para giren taraf (gelir, transfer girişi, yatırım girişi)
--     credit -> hesaptan para çıkan taraf (gider, transfer çıkışı, yatırım çıkışı)
-- (bkz. lib/screens/transactions/forms/*.dart -- her form ledger_entries'i
--  bu debit/credit mantığıyla oluşturuyor.)
--
-- WITH (security_invoker = true):
-- Bu olmadan view, onu oluşturan rolün (genelde owner/postgres) izinleriyle
-- çalışır ve accounts/ledger_entries üzerindeki RLS policy'lerini bypass
-- edebilir -- bu da bir kullanıcının başka bir kullanıcının bakiyelerini
-- görebilmesi anlamına gelir. security_invoker = true ile view, sorguyu
-- yapan kullanıcının izinleriyle çalışır, böylece mevcut RLS policy'leri
-- ("accounts_own", "ledger_entries_own") view üzerinden de uygulanır.
-- Not: security_invoker Postgres 15+ gerektirir (Supabase projeleri bunu
-- karşılar).
--
-- a.* + GROUP BY a.id: accounts.id primary key olduğu için a tablosunun
-- diğer tüm kolonları a.id'ye fonksiyonel olarak bağımlıdır, bu yüzden
-- GROUP BY a.id yeterlidir (PostgreSQL 9.1+ bunu destekler).
-- ============================================================================

CREATE OR REPLACE VIEW public.account_balances
WITH (security_invoker = true) AS
SELECT
  a.*,
  a.opening_balance
    + COALESCE(SUM(CASE WHEN le.entry_type = 'debit' THEN le.amount END), 0)
    - COALESCE(SUM(CASE WHEN le.entry_type = 'credit' THEN le.amount END), 0)
    AS current_balance
FROM public.accounts a
LEFT JOIN public.ledger_entries le ON le.account_id = a.id
GROUP BY a.id;

GRANT SELECT ON public.account_balances TO authenticated;


-- ============================================================================
-- KONTROL SORGUSU
-- Görünümün RLS'e saygı duyduğunu doğrulamak için iki farklı kullanıcı
-- context'inde çalıştırıp sonuçların birbirine karışmadığını kontrol edin:
-- ============================================================================
-- SELECT id, name, opening_balance, current_balance FROM public.account_balances;
