# CymBuild Constraint Deployment Contract (CYB-361 R40)

## Purpose

Constraint differences are first-class schema deployment objects. The Development workbench records and accepts the release plan; the manual runner and future CI/CD worker consume the same persisted `SMigration.SchemaDeploymentPlan_Get` result.

The browser does not execute DDL and does not receive deployment credentials.

```text
PWA -> FormHelper -> gRPC API -> SMigration accepted plan
                                  |
                                  +-> controlled PowerShell runner / pipeline worker -> SQL Server
```

## Supported constraint operations

The runner supports source-controlled create, replace and explicitly approved removal for:

- foreign keys;
- check constraints;
- default constraints;
- primary keys;
- unique constraints.

A dry-run materialises deterministic files beneath:

```text
Database/CymBuild_DB/Schema/Constraints
```

A changed constraint is split into phases:

1. `*.prepare.sql` drops the target definition before structural deployment.
2. `*.preflight.sql` validates required tables/columns and key uniqueness without changing data.
3. `*.sql` recreates the source definition after non-constraint schema objects have completed.

Foreign keys are prepared before key constraints. Primary/unique constraints are recreated before foreign keys.

## Existing-data policy

Foreign-key and check constraints are added with `WITH NOCHECK`. Existing rows are not validated or corrected. When the source constraint is enabled, `CHECK CONSTRAINT` enables enforcement for future inserts and updates without making the constraint trusted against historical data. A source-disabled constraint remains disabled.

Primary-key and unique constraints cannot use `WITH NOCHECK`. Their read-only preflight blocks deployment when NULL or duplicate key data would prevent creation. No data is changed automatically.

## Target-only removals

A target-only constraint is marked deployable but destructive-risk. It is never included in the default plan. Removal requires:

- an explicit saved selection;
- validation;
- acceptance with the release plan;
- execution by the controlled runner or pipeline identity.

## Source-control and promotion

The accepted comparison contains a declarative V2 snapshot, not executable database DDL. The dry-run generates or refreshes canonical files and stops an apply when new files were generated. Those files must be reviewed and committed before promotion.

Later-environment deployment should run with source materialisation disabled so QA/UAT/LIVE consume only the immutable reviewed repository artefacts.

## Pipeline sequence

The eventual non-interactive pipeline uses the same contract:

1. bootstrap/refresh SMigration objects idempotently;
2. read the accepted plan;
3. resolve committed source files with source materialisation disabled;
4. run read-only preflights;
5. execute `SCore.PreDeploymentScript`;
6. run strict post-predeployment preflights;
7. execute constraint prepare files;
8. deploy non-constraint schema objects;
9. execute constraint finalisation files;
10. execute `SCore.PostDeploymentScript` after success;
11. write SMigration audit and publish the deployment result.

No interactive prompt, UI session or manual database edit is part of this sequence.
