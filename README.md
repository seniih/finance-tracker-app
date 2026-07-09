# TrendArsa Muhasebe

**Arsa yatırımı odaklı finans ve muhasebe takip uygulaması.** Kar merkezi → proje → arsa (ürün) + yatırımcı (sermaye) → satış zincirini uçtan uca yönetir; kasa/banka hesaplarını çift taraflı kayıt (ledger) mantığıyla izler.

![Flutter](https://img.shields.io/badge/Flutter-Web%20%7C%20macOS-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%5E3.11-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20Auth%20%2B%20RLS-3FCF8E?logo=supabase&logoColor=white)
![Netlify](https://img.shields.io/badge/Deploy-Netlify-00C7B7?logo=netlify&logoColor=white)

---

## Özellikler

- **Kar merkezi, proje ve arsa yönetimi** — kar merkezleri altında projeler, projeler altında arsa blokları (ürünler); alan/alış fiyatı/durum (alındı → satışta → satıldı) takibi
- **Yatırımcı sistemi** — proje başına yatırımcılar; tarih ve USD kuru bazlı satır satır sermaye ödeme kayıtları (USD karşılığı veritabanında otomatik hesaplanır); ortaklık oranı sermayeden türetilir
- **Alış (maliyet) takibi** — projeye yapılan her harcama (arsa alımı, tapu, komisyon...) 'Alış' işlemi olarak kasadan düşer; proje maliyeti bu işlemlerin toplamıdır
- **Satış ve dağıtım** — satış geliri seçilen kasaya girer (satış + kasa girişi atomik RPC); kullanıcı kar payını yüzde olarak girer, kalan tutar yatırımcılara sermaye oranlarına göre DB trigger'larıyla otomatik dağıtılır ve cari bakiyelerinde BORÇ olarak izlenir (uygulama dağıtım tablosuna yazamaz)
- **Çift taraflı muhasebe** — her işlem debit/credit ledger satırlarıyla kaydedilir; hesap bakiyeleri `account_balances` view'inden gerçek zamanlı türetilir
- **İşlem türleri** — gelir/gider, hesaplar arası transfer, yatırım giriş/çıkışı, alış, satış; işlem + ledger yazımı atomik RPC ile tek Postgres transaction'ında yapılır
- **Cari yönetimi** — cari türleri, devir (açılış) bakiyesi, işlem bazlı borç/alacak takibi
- **Kategoriler** — hiyerarşik (üst/alt) gelir-gider kategorileri

## Mimari

```
Flutter (Web / macOS)
   └── supabase_flutter SDK ── Supabase
                                 ├── Auth   (e-posta + şifre)
                                 ├── Postgres
                                 │     ├── RLS  → tek güvenlik katmanı (backend yok)
                                 │     ├── RPC  → atomik işlem + ledger yazımı
                                 │     ├── View → account_balances (security_invoker)
                                 │     └── Trigger → satış dağıtımı, arsa durumu
                                 └── PostgREST API
```

Ayrı bir backend **yoktur**; istemci doğrudan Supabase'e bağlanır. Bu nedenle tüm yetkilendirme ve veri bütünlüğü kuralları veritabanı seviyesinde (RLS + trigger + RPC) uygulanır. Her tablo satır bazında kullanıcıya izole edilmiştir; çapraz kullanıcı erişimi FK sahiplik kontrolleri dahil policy'lerle kapatılmıştır.

| Katman | Konum |
|---|---|
| UI ekranları | `lib/screens/` |
| Veri modelleri | `lib/models/` |
| Veri erişim servisi | `lib/services/supabase_database_service.dart` |
| DB şeması ve politikalar | `supabase/migrations/` |

## Kurulum

### Gereksinimler

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart ^3.11)
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- Bir Supabase projesi

### 1. Depoyu klonlayın

```bash
git clone <repo-url>
cd finance_tracker
flutter pub get
```

### 2. Yapılandırma dosyasını oluşturun

Proje kökünde `config.json` oluşturun (şablon: [`config.example.json`](config.example.json)):

```json
{
  "SUPABASE_URL": "https://PROJE-REF.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_..."
}
```

> `config.json` bilinçli olarak `.gitignore`'dadır ve depoya girmez. Değerleri Supabase Dashboard → Project Settings → API'den alın.

### 3. Veritabanı migration'larını uygulayın

```bash
supabase link --project-ref PROJE-REF
supabase db push
```

Migration'lar sıralı ve ileri yönlüdür (forward-only); şema, RLS politikaları, grant'ler, view/trigger/RPC'ler ve güvenlik sıkılaştırmaları bu dizinden yönetilir: [`supabase/migrations/`](supabase/migrations/)

### 4. Çalıştırın

```bash
flutter run -d chrome --dart-define-from-file=config.json   # Web
flutter run -d macos  --dart-define-from-file=config.json   # macOS
```

`--dart-define` verilmezse uygulama `config.json`'ı asset olarak okur; ikisi de çalışır.

## Dağıtım (Netlify)

Depo, Netlify ile sürekli dağıtıma hazırdır — yapılandırma [`netlify.toml`](netlify.toml) ve [`netlify_build.sh`](netlify_build.sh) dosyalarındadır. Build betiği Flutter SDK'yı kurar, `config.json`'ı ortam değişkenlerinden üretir ve `build/web` çıktısını yayınlar.

1. Netlify'da **Import from GitHub** ile depoyu bağlayın (Base/Functions directory boş kalır).
2. **Site settings → Environment variables** altına ekleyin:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. Supabase Dashboard → **Authentication → URL Configuration**: Site URL ve Redirect URLs'i Netlify adresinizle güncelleyin.

## Güvenlik

- **RLS her tabloda aktif** — sahiplik `user_id = auth.uid()` ile, ilişkili tablolarda FK sahiplik kontrolleri `WITH CHECK` içinde doğrulanır
- **Atomik RPC'ler** `SECURITY INVOKER` çalışır; `user_id` istemciden alınmaz, `auth.uid()`'den yazılır
- **`anon` rolünün tüm yetkileri kapalıdır** — giriş yapmadan hiçbir tablo/view/RPC'ye erişilemez
- **Tüm fonksiyonlarda `search_path` sabitlenmiştir** (search path zehirlenmesine karşı)
- `account_balances` view'i `security_invoker = true` ile RLS'e tabidir
- İstemciye giden tek kimlik bilgisi **publishable anon key**'dir; tasarımı gereği kamuya açıktır, gizli anahtarlar (service role) hiçbir yerde kullanılmaz

Ayrıntılar için: [`supabase/migrations/20260709120000_security_hardening.sql`](supabase/migrations/20260709120000_security_hardening.sql)

## Veritabanı Şeması (özet)

| Tablo | Amaç |
|---|---|
| `profiles` | Kullanıcı/şirket profili |
| `accounts` | Kasa, banka, kredi kartı, ortak cari hesapları |
| `contacts` / `contact_types` | Cariler ve türleri (devir bakiyesi dahil) |
| `profit_centers` | Kar merkezleri (projeleri gruplar) |
| `projects` / `lands` | Projeler (kar merkezine bağlı) ve arsa blokları (ürünler) |
| `project_investors` | Proje–yatırımcı ilişkisi |
| `project_investments` | Sermaye ödemeleri (TL + kur + otomatik USD) |
| `land_sales` / `land_sale_distributions` | Satış kaydı (% kar payı, kasa işlemi bağı) ve sermaye oranlı otomatik dağıtım (= yatırımcı borçları) |
| `categories` | Hiyerarşik gelir/gider kategorileri |
| `transactions` / `ledger_entries` | İşlemler ve çift taraflı muhasebe kayıtları |

## Lisans

Bu proje özel (proprietary) bir projedir; tüm hakları saklıdır.
