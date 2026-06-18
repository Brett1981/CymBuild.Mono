#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_DATABASE:?SOURCE_DATABASE is required}"
: "${BUSINESS_UNIT_GROUP_GUID:?BUSINESS_UNIT_GROUP_GUID is required}"
: "${ALLOW_WARNINGS:=1}"

mkdir -p artifacts

./ci/scripts/sqlcmd.sh \
  -i database/onboarding/00_identity_seed_preflight.sql \
  | tee artifacts/onboarding_identity_seed_preflight.log

./ci/scripts/sqlcmd.sh \
  -i database/onboarding/10_onboarding_stage_validate_preview.sql \
  -v SourceDatabase="$SOURCE_DATABASE" BusinessUnitGroupGuid="$BUSINESS_UNIT_GROUP_GUID" AllowWarnings="$ALLOW_WARNINGS" \
  | tee artifacts/onboarding_preview.log

RUN_GUID="$(grep -oE 'CI_RUN_GUID=[0-9A-Fa-f-]+' artifacts/onboarding_preview.log | tail -1 | cut -d= -f2)"

if [ -z "$RUN_GUID" ]; then
  echo "Could not capture CI_RUN_GUID from preview output." >&2
  exit 1
fi

{
  echo "RUN_GUID=$RUN_GUID"
  echo "SOURCE_DATABASE=$SOURCE_DATABASE"
  echo "BUSINESS_UNIT_GROUP_GUID=$BUSINESS_UNIT_GROUP_GUID"
  echo "ALLOW_WARNINGS=$ALLOW_WARNINGS"
} > artifacts/onboarding-run.env

echo "Captured onboarding RunGuid: $RUN_GUID"
