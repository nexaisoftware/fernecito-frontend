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
flutter build web --release --base-href / --no-wasm-dry-run \
  --dart-define=URL_SUPABASE="$URL_SUPABASE" \
  --dart-define=CLAVE_PUBLICA_SUPABASE="$CLAVE_PUBLICA_SUPABASE" \
  --dart-define=URL_SHARE_EVENTO="${URL_SHARE_EVENTO:-}" \
  --dart-define=FIREBASE_WEB_API_KEY="${FIREBASE_WEB_API_KEY:-}" \
  --dart-define=FIREBASE_WEB_APP_ID="${FIREBASE_WEB_APP_ID:-}" \
  --dart-define=FIREBASE_WEB_MESSAGING_SENDER_ID="${FIREBASE_WEB_MESSAGING_SENDER_ID:-}" \
  --dart-define=FIREBASE_WEB_PROJECT_ID="${FIREBASE_WEB_PROJECT_ID:-}" \
  --dart-define=FIREBASE_WEB_AUTH_DOMAIN="${FIREBASE_WEB_AUTH_DOMAIN:-}" \
  --dart-define=FIREBASE_WEB_STORAGE_BUCKET="${FIREBASE_WEB_STORAGE_BUCKET:-}" \
  --dart-define=FCM_WEB_VAPID_KEY="${FCM_WEB_VAPID_KEY:-}"

echo "==> [1b/3] deploy_id en build/web/version.json"
python3 - <<'PY'
import json, os, subprocess, time

path = "build/web/version.json"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

git_ref = (os.environ.get("VERCEL_GIT_COMMIT_SHA") or "").strip()
if not git_ref:
    try:
        git_ref = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        git_ref = "local"

data["deploy_id"] = f"{git_ref[:12]}-{int(time.time())}"
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, separators=(",", ":"))
PY

echo "==> [2/3] preparando Vercel: api + build/web/vercel.json"
mkdir -p build/web/api
cp -R web/api/. build/web/api/
mkdir -p build/web/.well-known
cp -R web/.well-known/. build/web/.well-known/
cp web/firebase-messaging-sw.js build/web/firebase-messaging-sw.js

if [ -n "${FIREBASE_WEB_API_KEY:-}" ] && [ -n "${FIREBASE_WEB_APP_ID:-}" ] && [ -n "${FIREBASE_WEB_MESSAGING_SENDER_ID:-}" ] && [ -n "${FIREBASE_WEB_PROJECT_ID:-}" ]; then
  echo "==> [2a/3] firebase-config-sw.js para push web"
  python3 - <<'PY'
import json, os

cfg = {
    "apiKey": os.environ.get("FIREBASE_WEB_API_KEY", ""),
    "appId": os.environ.get("FIREBASE_WEB_APP_ID", ""),
    "messagingSenderId": os.environ.get("FIREBASE_WEB_MESSAGING_SENDER_ID", ""),
    "projectId": os.environ.get("FIREBASE_WEB_PROJECT_ID", ""),
}
auth_domain = os.environ.get("FIREBASE_WEB_AUTH_DOMAIN", "")
storage_bucket = os.environ.get("FIREBASE_WEB_STORAGE_BUCKET", "")
if auth_domain:
    cfg["authDomain"] = auth_domain
if storage_bucket:
    cfg["storageBucket"] = storage_bucket

with open("build/web/firebase-config-sw.js", "w", encoding="utf-8") as f:
    f.write("self.fernecitoFirebaseConfig = ")
    json.dump(cfg, f, separators=(",", ":"))
    f.write(";\n")
PY
else
  echo "==> [2a/3] push web desactivado: faltan FIREBASE_WEB_*"
  cat > build/web/firebase-config-sw.js <<'JS'
self.fernecitoFirebaseConfig = null;
JS
fi

cat > build/web/vercel.json <<'JSON'
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "cleanUrls": true,
  "rewrites": [
    { "source": "/share-evento", "destination": "/api/share-evento" },
    {
      "source": "/((?!firebase-messaging-sw\\.js|firebase-config-sw\\.js|flutter_service_worker\\.js|flutter_bootstrap\\.js|main\\.dart\\.js|version\\.json|manifest\\.json|favicon\\.png|assets/|icons/|splash/|canvaskit/|api/).*)",
      "destination": "/index.html"
    }
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
      "source": "/(firebase-messaging-sw.js|firebase-config-sw.js)",
      "headers": [
        { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
      ]
    },
    {
      "source": "/flutter_service_worker.js",
      "headers": [
        { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
      ]
    },
    {
      "source": "/(index.html|main.dart.js|flutter_bootstrap.js|flutter.js|version.json)",
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
