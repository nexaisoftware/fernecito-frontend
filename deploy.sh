#!/usr/bin/env bash
# Deploy Fernecito USUARIOS (Flutter web -> Vercel PWA)
# Subdominio: https://appusuarios.fernecitoapp.com
# Uso: ./deploy.sh
set -euo pipefail

cd "$(dirname "$0")"

load_env_file() {
  local file="$1"
  while IFS='=' read -r key value || [ -n "$key" ]; do
    key="$(printf '%s' "$key" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$key" in ''|\#*) continue ;; esac
    value="$(printf '%s' "${value:-}" | tr -d '\r')"
    value="${value%\"}"
    value="${value#\"}"
    export "$key=$value"
  done < "$file"
}

if [ -f .env ]; then
  load_env_file .env
fi

: "${URL_SUPABASE:?Falta URL_SUPABASE en fernecito_frontend/.env o entorno}"
: "${CLAVE_PUBLICA_SUPABASE:?Falta CLAVE_PUBLICA_SUPABASE en fernecito_frontend/.env o entorno}"

echo "==> [1/3] flutter build web --release --base-href /"
flutter build web --release --base-href / \
  --dart-define=URL_SUPABASE="$URL_SUPABASE" \
  --dart-define=CLAVE_PUBLICA_SUPABASE="$CLAVE_PUBLICA_SUPABASE" \
  --dart-define=URL_SHARE_EVENTO="${URL_SHARE_EVENTO:-}"

echo "==> [2/3] preparando Vercel: api + build/web/vercel.json"
mkdir -p build/web/api
cp -R web/api/. build/web/api/
mkdir -p build/web/.well-known
cp -R web/.well-known/. build/web/.well-known/

cat > build/web/vercel.json <<'JSON'
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "cleanUrls": true,
  "rewrites": [
    { "source": "/share-evento", "destination": "/api/share-evento" },
    { "source": "/(.*)", "destination": "/index.html" }
  ],
  "headers": [
    {
      "source": "/assets/.env",
      "headers": [
        { "key": "Cache-Control", "value": "no-store" },
        { "key": "X-Robots-Tag", "value": "noindex" }
      ]
    },
    {
      "source": "/flutter_service_worker.js",
      "headers": [
        { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
      ]
    },
    {
      "source": "/.well-known/apple-app-site-association",
      "headers": [
        { "key": "Content-Type", "value": "application/json" },
        { "key": "Cache-Control", "value": "public, max-age=3600" }
      ]
    },
    {
      "source": "/.well-known/assetlinks.json",
      "headers": [
        { "key": "Content-Type", "value": "application/json" },
        { "key": "Cache-Control", "value": "public, max-age=3600" }
      ]
    },
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" }
      ]
    }
  ]
}
JSON

echo "==> [3/3] vercel deploy --prod (proyecto fernecito-usuarios)"
cd build/web
vercel link --project fernecito-usuarios --yes
rm -f .env.local .env .env.production .env.development
vercel deploy --prod --yes

echo ""
echo "OK -> https://appusuarios.fernecitoapp.com"
