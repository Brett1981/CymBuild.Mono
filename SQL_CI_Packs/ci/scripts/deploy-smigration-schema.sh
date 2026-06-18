#!/usr/bin/env bash
set -euo pipefail

mkdir -p artifacts

./ci/scripts/sqlcmd.sh \
  -i database/smigration/SMigration.Schema.sql \
  | tee artifacts/smigration_schema_deploy.log
