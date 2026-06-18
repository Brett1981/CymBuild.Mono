# CymBuild Metadata Migration CI Pack

This pack turns the proven metadata deployment flow into a Bitbucket Pipeline-ready structure.

## Deployment flow

The intended flow is:

1. Deploy SMigration metadata schema and procs.
2. Seed metadata registry.
3. Create metadata run.
4. Stage metadata.
5. Validate.
6. Build identity map.
7. Manual apply approval.
8. Apply exact approved RunGuid.
9. Run post-apply verification.

This preserves the CymBuild rule that metadata is source-controlled and the database is only a deployment target.

## Repository layout

```text
database/
  smigration/
    SMigration.Metadata.Schema.sql
  metadata/
    10_metadata_stage_validate_preview.sql
    20_metadata_apply_existing_validated_run.sql
    21_metadata_stage_validate_apply.sql
    30_metadata_post_apply_verify.sql

ci/
  scripts/
    sqlcmd.sh
    deploy-metadata-schema.sh
    run-metadata-preview.sh
    run-metadata-apply.sh
    run-metadata-verify.sh
    run-metadata-stage-validate-apply.sh

bitbucket-pipelines.yml
```

## Required Bitbucket deployment variables

Configure these as secured deployment variables for each Bitbucket deployment environment:

```text
SQL_SERVER
SQL_DATABASE
SQL_USER
SQL_PASSWORD
```

`SQL_SERVER` / `SQL_DATABASE` are the connection used by sqlcmd. For metadata migration this should usually be the **target** database.

## Custom pipeline variables

```text
SOURCE_ENVIRONMENT
TARGET_ENVIRONMENT
SOURCE_SERVER_NAME
SOURCE_DATABASE_NAME
TARGET_SERVER_NAME
TARGET_DATABASE_NAME
ALLOW_UPDATES
REQUIRE_NO_VALIDATION_ISSUES
FORCE_APPLY
REQUIRE_NO_DIFFS
RUN_GUID
```

## Same-server vs cross-server staging

The SQL-only runner uses:

```sql
SMigration.MetadataStage_Run
```

That stored procedure reads the source database using the supplied `SourceDatabaseName`. This works when the target SQL session can see the source database, for example DEV → QA on the same SQL Server.

For cross-server staging without linked server, use CymBuild's API/UI two-connection staging path. Then run the pipeline apply step using the approved `RUN_GUID`.

## Environment policy

```text
DEV:
  schema deploy + preview + apply allowed

QA/UAT:
  schema deploy + preview automatic
  apply manual only

LIVE:
  schema deploy controlled
  preview required
  apply exact approved RunGuid only
  ForceApply = 1 required by SMigration.MetadataApply_Run
  no direct/manual metadata edits
```

## Important CymBuild rules retained

- No direct metadata DB edits.
- No manual DB promotion.
- No source numeric ID copying.
- Guid/identity-map based apply.
- DataObjects-compliant metadata inserts.
- Idempotent registry/apply behaviour.
- Stage/Diff normalises environment-only ID differences while preserving full audit payloads.

## Recommended usage

For same-server DEV → QA:

```text
metadata-dev-qa
```

For cross-server DEV/QA → UAT/LIVE:

1. Stage + validate in CymBuild Metadata Migration UI/API two-connection path.
2. Approve the resulting RunGuid.
3. Run `metadata-apply-existing-run` with that RunGuid against the target database.
4. Run `metadata-verify` where the SQL target can stage from the source, or verify through the UI/API two-connection path.
