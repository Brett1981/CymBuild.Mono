#!/usr/bin/env bash
set -euo pipefail

find_sqlcmd() {
  if command -v sqlcmd >/dev/null 2>&1; then
    command -v sqlcmd
    return 0
  fi

  if [ -x "/opt/mssql-tools18/bin/sqlcmd" ]; then
    echo "/opt/mssql-tools18/bin/sqlcmd"
    return 0
  fi

  if [ -x "/opt/mssql-tools/bin/sqlcmd" ]; then
    echo "/opt/mssql-tools/bin/sqlcmd"
    return 0
  fi

  echo "sqlcmd was not found. Use an image with mssql-tools18 or install SQL Server command-line tools." >&2
  return 1
}

SQLCMD_BIN="$(find_sqlcmd)"

: "${SQL_SERVER:?SQL_SERVER is required}"
: "${SQL_DATABASE:?SQL_DATABASE is required}"
: "${SQL_USER:?SQL_USER is required}"
: "${SQL_PASSWORD:?SQL_PASSWORD is required}"

exec "$SQLCMD_BIN" \
  -S "$SQL_SERVER" \
  -d "$SQL_DATABASE" \
  -U "$SQL_USER" \
  -P "$SQL_PASSWORD" \
  -b \
  -V 16 \
  -C \
  "$@"
