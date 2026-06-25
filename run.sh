#!/usr/bin/env bash
# Corre la app de USUARIOS (fernecito_frontend) en debug, inyectando las keys
# de Supabase desde .env. Uso: ./run.sh   (acepta flags extra: ./run.sh -d <id>)
set -euo pipefail
cd "$(dirname "$0")"
exec flutter run --dart-define-from-file=.env "$@"
