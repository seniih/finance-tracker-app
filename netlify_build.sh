#!/usr/bin/env bash
# Netlify build betiği: Flutter kur + config.json üret + web build al.
set -euo pipefail

# 1) Flutter SDK (stable). Netlify imajında Flutter yok, kendimiz çekiyoruz.
if [ ! -d "$HOME/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"
flutter --version

# 2) config.json'ı Netlify env değişkenlerinden üret.
#    Değerler publishable (kamuya açık) tiptir; yine de repo'da tutmuyoruz —
#    tek doğruluk kaynağı Netlify env olsun, key rotasyonu deploy'la çözülsün.
: "${SUPABASE_URL:?SUPABASE_URL env değişkeni tanımlı değil (Netlify site settings)}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY env değişkeni tanımlı değil (Netlify site settings)}"
printf '{"SUPABASE_URL":"%s","SUPABASE_ANON_KEY":"%s"}\n' "$SUPABASE_URL" "$SUPABASE_ANON_KEY" > config.json

# 3) Web build
flutter pub get
flutter build web --release
