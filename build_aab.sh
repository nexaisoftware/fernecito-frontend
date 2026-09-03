#!/usr/bin/env bash
# Genera el AAB de RELEASE para Google Play con config publica inyectada por
# --dart-define. Lee .env limpiando CRLF para evitar defines vacias en Android.
set -euo pipefail
cd "$(dirname "$0")"

env_get() {
  awk -F= -v key="$1" '
    $1 == key {
      sub(/^[^=]*=/, "")
      gsub(/\r/, "")
      print
      exit
    }
  ' .env
}

URL_SUPABASE="$(env_get URL_SUPABASE)"
CLAVE_PUBLICA_SUPABASE="$(env_get CLAVE_PUBLICA_SUPABASE)"
URL_SHARE_EVENTO="$(env_get URL_SHARE_EVENTO)"
URL_SHARE_PLAN="$(env_get URL_SHARE_PLAN)"
CARTO_BASEMAPS_KEY="$(env_get CARTO_BASEMAPS_KEY)"

: "${URL_SUPABASE:?Falta URL_SUPABASE en .env}"
: "${CLAVE_PUBLICA_SUPABASE:?Falta CLAVE_PUBLICA_SUPABASE en .env}"
: "${CARTO_BASEMAPS_KEY:?Falta CARTO_BASEMAPS_KEY en .env}"

flutter build appbundle --release \
  --dart-define=URL_SUPABASE="$URL_SUPABASE" \
  --dart-define=CLAVE_PUBLICA_SUPABASE="$CLAVE_PUBLICA_SUPABASE" \
  --dart-define=URL_SHARE_EVENTO="$URL_SHARE_EVENTO" \
  --dart-define=URL_SHARE_PLAN="$URL_SHARE_PLAN" \
  --dart-define=CARTO_BASEMAPS_KEY="$CARTO_BASEMAPS_KEY" \
  "$@"
echo ""
echo "✅ AAB listo:  build/app/outputs/bundle/release/app-release.aab"
echo "   Subilo a Play Console -> Produccion -> Crear/editar version."
