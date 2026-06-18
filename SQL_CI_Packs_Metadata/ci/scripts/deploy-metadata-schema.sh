#!/usr/bin/env bash
set -euo pipefail

mkdir -p artifacts

./ci/scripts/sqlcmd.sh \
  -i database/smigration/SMigration.Metadata.Schema.sql \
  | tee artifacts/metadata_schema_deploy.log
