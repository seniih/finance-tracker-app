-- ============================================================================
-- Cari Açılış Bakiyesi (contacts.opening_balance / opening_balance_currency)
--
-- İhtiyaç: Yeni bir cari eklerken, uygulamayı kullanmaya başlamadan önce
-- var olan bir borç/alacak durumunu (devir bakiyesi) girebilmek gerekiyor --
-- tıpkı accounts.opening_balance'ın bir kasanın "açılışta" ne kadar parası
-- olduğunu tutması gibi.
--
-- Yöntem: accounts tablosundaki opening_balance / currency deseni buraya da
-- birebir uygulandı (tutarlılık için), TEK farkla: contacts.opening_balance
-- İŞARETLİ (signed) bir değer -- ayrı bir "yön" (borçlu/alacaklı) sütunu
-- eklemedik. Sebep: yön zaten tutarın işaretiyle ifade edilebiliyor ve bu,
-- uygulamanın geri kalanındaki (ContactBalanceCalculator, işlem bazlı borç/
-- alacak hesaplaması) sözleşmeyle birebir aynı: pozitif = cari bana borçlu,
-- negatif = ben cariye borçluyum. Ayrı bir yön sütunu eklemek, "tutar" ve
-- "yön" alanlarının birbiriyle çelişebileceği (örn. yön='borçlu' ama tutar
-- negatif) gereksiz bir tutarsızlık riski yaratırdı -- tek işaretli sütun bu
-- riski ortadan kaldırıyor. UI tarafında kullanıcıya yine de "Cari Bana
-- Borçlu" / "Ben Cariye Borçluyum" şeklinde bir seçim sunuluyor, sadece
-- kaydedilirken tek bir işaretli sayıya çevriliyor.
--
-- Not: Bu devir bakiyesi client tarafında (lib/utils/contact_balance.dart)
-- işlem bazlı borç/alacak hesabına bir "başlangıç değeri" olarak ekleniyor --
-- accounts.opening_balance'ın account_balances view'inde yapıldığı gibi bir
-- SQL view'e gerek yok, çünkü cari borç/alacak zaten tamamen istemci
-- tarafında (TransactionModel listesinden) hesaplanıyor.
-- ============================================================================

ALTER TABLE public.contacts
  ADD COLUMN IF NOT EXISTS opening_balance numeric(15,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS opening_balance_currency text NOT NULL DEFAULT 'TRY';
