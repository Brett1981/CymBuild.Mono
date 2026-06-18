#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_ENVIRONMENT:?SOURCE_ENVIRONMENT is required}"
: "${TARGET_ENVIRONMENT:?TARGET_ENVIRONMENT is required}"
: "${SOURCE_SERVER_NAME:?SOURCE_SERVER_NAME is required}"
: "${SOURCE_DATABASE_NAME:?SOURCE_DATABASE_NAME is required}"
: "${TARGET_SERVER_NAME:?TARGET_SERVER_NAME is required}"
: "${TARGET_DATABASE_NAME:?TARGET_DATABASE_NAME is required}"
: "${FORCE_APPLY:=0}"

mkdir -p artifacts

./ci/scripts/sqlcmd.sh \
  -i database/metadata/21_metadata_stage_validate_apply.sql \
  -v SourceEnvironment="$SOURCE_ENVIRONMENT" TargetEnvironment="$TARGET_ENVIRONMENT" SourceServerName="$SOURCE_SERVER_NAME" SourceDatabaseName="$SOURCE_DATABASE_NAME" TargetServerName="$TARGET_SERVER_NAME" TargetDatabaseName="$TARGET_DATABASE_NAME" ForceApply="$FORCE_APPLY" \
  | tee artifacts/metadata_stage_validate_apply.log

RUN_GUID="$(grep -oE 'CI_RUN_GUID=[0-9A-Fa-f-]+' artifacts/metadata_stage_validate_apply.log | tail -1 | cut -d= -f2 || true)"

if [ -n "$RUN_GUID" ]; then
  echo "RUN_GUID=$RUN_GUID" > artifacts/metadata-run.env
  echo "Captured metadata RunGuid: $RUN_GUID"
fi
