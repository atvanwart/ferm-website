#!/usr/bin/env bash
set -euo pipefail

# RB.2 Admin helpers

load_admin_creds() {
  ADMIN_USER="$(node -e "require('dotenv').config({path:'.env'}); process.stdout.write(process.env.ADMIN_USER||'')" || true)"
  ADMIN_PASS="$(node -e "require('dotenv').config({path:'.env'}); process.stdout.write(process.env.ADMIN_PASS||'')" || true)"
  [ -n "${ADMIN_USER}" ] || die "ADMIN_USER missing in .env"
  [ -n "${ADMIN_PASS}" ] || die "ADMIN_PASS missing in .env"
}

admin_curl() {
  load_admin_creds
  curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" "$@"
}
