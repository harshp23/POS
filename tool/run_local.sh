#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PROVIYAA_ENV_FILE:-$ROOT/.env.local}"

if [[ ! -f "$ENV_FILE" ]]; then
  printf 'Missing %s\nCopy .env.local.example to .env.local and fill local-safe values.\n' "$ENV_FILE" >&2
  exit 1
fi

args=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  if [[ "$line" != *=* ]]; then
    printf 'Invalid env line (expected KEY=VALUE): %s\n' "${line%%$'\r'}" >&2
    exit 1
  fi
  key="${line%%=*}"
  value="${line#*=}"
  value="${value%$'\r'}"
  case "$key" in
    APP_ENV|DATA_MODE|PROVIYAA_API_BASE_URL|SYNC_ENABLED)
      args+=("--dart-define=${key}=${value}") ;;
    SUPABASE_URL|SUPABASE_PUBLISHABLE_KEY)
      # Supabase settings belong to the backend (backend/.env); the app
      # talks only to PROVIYAA_API_BASE_URL.
      printf 'Ignoring %s (backend-only setting)\n' "$key" >&2 ;;
    *)
      printf 'Refusing unsupported or secret env key: %s\n' "$key" >&2
      exit 1 ;;
  esac
done < "$ENV_FILE"

cd "$ROOT"
exec flutter run "${args[@]}" "$@"
