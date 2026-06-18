#!/usr/bin/env bash
set -euo pipefail

: "${FORCE_APPLY:=0}"

if [ -f artifacts/metadata-run.env ]; then
  # shellcheck disable=SC1091
  source artifacts/metadata-run.env
fi

: "${RUN_GUID:?RUN_GUID is required. Supply it manually or run preview first and keep artifacts.}"

mkdir -p artifacts

./ci/scripts/sqlcmd.sh \
  -i database/metadata/20_metadata_apply_existing_validated_run.sql \
  -v RunGuid="$RUN_GUID" ForceApply="$FORCE_APPLY" \
  | tee artifacts/metadata_apply.log

echo "Applied metadata RunGuid: $RUN_GUID"
