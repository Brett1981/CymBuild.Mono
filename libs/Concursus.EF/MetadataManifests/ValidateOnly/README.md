# CymBuild Metadata - ValidateOnly (Stage 1)

Purpose
- Read-only validation of manifest-managed metadata vs a target database.
- Stage 1 scope: GridFamily only (GridDefinitions -> Views -> Columns/Actions/Widgets).

Governance locks (from Phase 2/3 approvals)
- Repo is primary source of truth.
- Live runs ValidateOnly by default.
- Live "Different" is FAIL (forces capture-back/rollback).
- Managed scope is explicit allow-list of GridDefinition GUIDs.
- Prerequisites must pre-exist; any missing reference is FAIL.
- "Unexpected unmanaged rows" is WARN in QA/UAT, INFO in Live (non-blocking).

How to run (example)
dotnet run --project Concursus.EF -- \
  validate-grids \
  --connection "<sql-connection-string>" \
  --manifest "path/to/metadata-manifests/v1/families/grids/grids.json" \
  --allowlist "path/to/metadata-manifests/v1/policies/allowlist.grids.json" \
  --environment "QA" \
  --out "validation-report.json"

Exit codes
- 0 : success (no FAILs)
- 2 : FAIL present
- 4 : invalid input / manifest format error
