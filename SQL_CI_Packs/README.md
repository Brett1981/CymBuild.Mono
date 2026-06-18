# CymBuild Onboarding Migration CI Pack

This pack converts the manually tested onboarding migration into a Bitbucket Pipeline-ready structure.

## Why this structure

The migration is a SQL deployment job, not an API/PWA runtime concern. It should run as:

1. SMigration schema deploy.
2. Stage from source database.
3. Validate staged data.
4. Preview/report/audit.
5. Manual apply approval.
6. Apply exact previewed RunGuid.
7. Post-apply report/audit.

This preserves the CymBuild rule that the database is a deployment target only and avoids manual DB promotion.

## Repository layout

```text
database/
  smigration/
    SMigration.Schema.sql
  onboarding/
    00_identity_seed_preflight.sql
    01_reseed_identity_values.sql
    10_onboarding_stage_validate_preview.sql
    20_onboarding_apply_existing_previewed_run.sql
    21_onboarding_stage_validate_apply.sql
    manual-reference-only.sql

ci/
  scripts/
    sqlcmd.sh
    deploy-smigration-schema.sh
    run-onboarding-preview.sh
    run-onboarding-apply.sh

bitbucket-pipelines.yml
```

## Required Bitbucket deployment variables

Configure these as secured deployment variables per environment:

```text
SQL_SERVER
SQL_DATABASE
SQL_USER
SQL_PASSWORD
```

Provide these when starting the custom pipeline:

```text
SOURCE_DATABASE
BUSINESS_UNIT_GROUP_GUID
ALLOW_WARNINGS
```

For applying a previously staged run directly:

```text
RUN_GUID
ALLOW_WARNINGS
```

## Recommended environment policy

```text
DEV:
  schema deploy + preview + manual apply allowed

QA/UAT:
  schema deploy + preview automatic
  apply manual only

LIVE:
  schema deploy controlled
  preview required
  apply existing approved RunGuid only
  manual approval required
  no ad-hoc direct database edits
```

## Important notes

- `SMigration.OnboardingImport_Apply` owns the transaction and rollback.
- Do not wrap the apply SQL in an outer transaction.
- `IDENTITY_EMAIL_GUID_MISMATCH` is treated as a warning because the apply resolves by trimmed/case-insensitive email address.
- `01_reseed_identity_values.sql` is included because restored/copy databases can have identity metadata behind the actual max ID.
- The reseed script is source-controlled and deterministic, but should still be approval-gated outside DEV.
- The supplied `manual-reference-only.sql` is retained only as a reference for the manually tested flow. Do not use it as the long-term CI entrypoint.

## Pipeline behaviour

The preview step writes:

```text
artifacts/onboarding-run.env
```

containing:

```text
RUN_GUID=<previewed run guid>
```

The apply step consumes the same artifact and applies the exact staged run.
