#!/usr/bin/env bash
set -euo pipefail

: "${ALLOW_WARNINGS:=1}"

if [ -f artifacts/onboarding-run.env ]; then
  # shellcheck disable=SC1091
  source artifacts/onboarding-run.env
fi

: "${RUN_GUID:?RUN_GUID is required. Supply it manually or run preview first and keep artifacts.}"

mkdir -p artifacts

./ci/scripts/sqlcmd.sh \
  -i database/onboarding/01_reseed_identity_values.sql \
  | tee artifacts/onboarding_identity_seed_reseed.log

./ci/scripts/sqlcmd.sh \
  -i database/onboarding/20_onboarding_apply_existing_previewed_run.sql \
  -v RunGuid="$RUN_GUID" AllowWarnings="$ALLOW_WARNINGS" \
  | tee artifacts/onboarding_apply.log

echo "Applied onboarding RunGuid: $RUN_GUID"
