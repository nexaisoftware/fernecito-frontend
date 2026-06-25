#!/usr/bin/env bash
# Genera un APK de RELEASE para PROBAR en un celu real ANTES de subir el AAB.
# Mismo modo que el AAB (release + keys), pero instalable directo. Si esto anda
# en el celu (Baloo, Supabase, todo), el AAB también va a andar.
# Uso: ./build_apk_release.sh   (luego instalá el .apk en el celu)
set -euo pipefail
cd "$(dirname "$0")"
flutter build apk --release --dart-define-from-file=.env "$@"
echo ""
echo "✅ APK release listo:  build/app/outputs/flutter-apk/app-release.apk"
echo "   Instalalo en el celu:  flutter install --release --dart-define-from-file=.env"
