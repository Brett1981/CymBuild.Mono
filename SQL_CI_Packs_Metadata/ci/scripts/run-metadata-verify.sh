#!/usr/bin/env bash
set -euo pipefail

if [ -f artifacts/metadata-run.env ]; then
  # shellcheck disable=SC1091
  source artifacts/metadata-run.env
fi

: "${SOURCE_ENVIRONMENT:?SOURCE_ENVIRONMENT is required}"
: "${TARGET_ENVIRONMENT:?TARGET_ENVIRONMENT is required}"
: "${SOURCE_SERVER_NAME:?SOURCE_SERVER_NAME is required}"
: "${SOURCE_DATABASE_NAME:?SOURCE_DATABASE_NAME is required}"
: "${TARGET_SERVER_NAME:?TARGET_SERVER_NAME is required}"
: "${TARGET_DATABASE_NAME:?TARGET_DATABASE_NAME is required}"
: "${REQUIRE_NO_DIFFS:=1}"

mkdir -p artifacts

./ci/scripts/sqlcmd.sh \
  -i database/metadata/30_metadata_post_apply_verify.sql \
  -v SourceEnvironment="$SOURCE_ENVIRONMENT" TargetEnvironment="$TARGET_ENVIRONMENT" SourceServerName="$SOURCE_SERVER_NAME" SourceDatabaseName="$SOURCE_DATABASE_NAME" TargetServerName="$TARGET_SERVER_NAME" TargetDatabaseName="$TARGET_DATABASE_NAME" RequireNoDiffs="$REQUIRE_NO_DIFFS" \
  | tee artifacts/metadata_post_apply_verify.log
