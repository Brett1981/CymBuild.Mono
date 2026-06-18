#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_ENVIRONMENT:?SOURCE_ENVIRONMENT is required}"
: "${TARGET_ENVIRONMENT:?TARGET_ENVIRONMENT is required}"
: "${SOURCE_SERVER_NAME:?SOURCE_SERVER_NAME is required}"
: "${SOURCE_DATABASE_NAME:?SOURCE_DATABASE_NAME is required}"
: "${TARGET_SERVER_NAME:?TARGET_SERVER_NAME is required}"
: "${TARGET_DATABASE_NAME:?TARGET_DATABASE_NAME is required}"
: "${ALLOW_UPDATES:=1}"
: "${REQUIRE_NO_VALIDATION_ISSUES:=1}"

mkdir -p artifacts

./ci/scripts/sqlcmd.sh \
  -i database/metadata/10_metadata_stage_validate_preview.sql \
  -v SourceEnvironment="$SOURCE_ENVIRONMENT" TargetEnvironment="$TARGET_ENVIRONMENT" SourceServerName="$SOURCE_SERVER_NAME" SourceDatabaseName="$SOURCE_DATABASE_NAME" TargetServerName="$TARGET_SERVER_NAME" TargetDatabaseName="$TARGET_DATABASE_NAME" AllowUpdates="$ALLOW_UPDATES" RequireNoValidationIssues="$REQUIRE_NO_VALIDATION_ISSUES" \
  | tee artifacts/metadata_preview.log

RUN_GUID="$(grep -oE 'CI_RUN_GUID=[0-9A-Fa-f-]+' artifacts/metadata_preview.log | tail -1 | cut -d= -f2)"

if [ -z "$RUN_GUID" ]; then
  echo "Could not capture CI_RUN_GUID from preview output." >&2
  exit 1
fi

{
  echo "RUN_GUID=$RUN_GUID"
  echo "SOURCE_ENVIRONMENT=$SOURCE_ENVIRONMENT"
  echo "TARGET_ENVIRONMENT=$TARGET_ENVIRONMENT"
  echo "SOURCE_SERVER_NAME=$SOURCE_SERVER_NAME"
  echo "SOURCE_DATABASE_NAME=$SOURCE_DATABASE_NAME"
  echo "TARGET_SERVER_NAME=$TARGET_SERVER_NAME"
  echo "TARGET_DATABASE_NAME=$TARGET_DATABASE_NAME"
  echo "ALLOW_UPDATES=$ALLOW_UPDATES"
  echo "REQUIRE_NO_VALIDATION_ISSUES=$REQUIRE_NO_VALIDATION_ISSUES"
} > artifacts/metadata-run.env

echo "Captured metadata RunGuid: $RUN_GUID"
