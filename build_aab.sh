#!/usr/bin/env bash
# Genera el AAB de RELEASE para subir a Google Play, con las keys de Supabase
# inyectadas desde .env (--dart-define). Esto evita el bug de "Supabase no
# inicializa" en release. Uso: ./build_aab.sh
set -euo pipefail
cd "$(dirname "$0")"
flutter build appbundle --release --dart-define-from-file=.env "$@"
echo ""
echo "✅ AAB listo:  build/app/outputs/bundle/release/app-release.aab"
echo "   Subilo a Play Console → Prueba cerrada (segmento Alpha) → Crear versión."
