#!/usr/bin/env bash
# Deploy Fernecito USUARIOS (Flutter web -> Vercel PWA)
# Subdominio: https://appusuarios.fernecitoapp.com
# Uso: ./deploy.sh
set -euo pipefail

cd "$(dirname "$0")"

echo "==> [1/3] flutter build web --release --base-href /"
flutter build web --release --base-href /

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
vercel deploy --prod --yes

echo ""
echo "OK -> https://appusuarios.fernecitoapp.com"
