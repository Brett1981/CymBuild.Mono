# CymBuild 26.3 CI/CD Baseline Reconciliation

## Document control

| Field | Value |
|---|---|
| Repository | `https://bitbucket.org/esgdevelopers/cymbuild_monorepo.git` |
| Branch | `feature/SB_Kubenetes` |
| Commit | `1b6061621b4c25731955979b0085a3e0928fdacb` |
| Commit date | `2026-08-06T14:28:00Z` |
| Commit subject | `Merged main into feature/SB_Kubenetes` |
| Release baseline | CymBuild 26.3 |
| Source archive used for independent inspection | `CymBuild.Monorepo(20260806-143554).zip` |
| Archive SHA-256 | `0c7bb39371ef01f1b870848d1ada2176a5aa0540552667291200110cb4e0577e` |
| Reconciliation date | 6 August 2026 |
| Status | Current source baseline for WP0, subject to the open decisions recorded below |

## 1. Purpose and authority

This document reconciles the current `feature/SB_Kubenetes` source with the earlier CymBuild 26.3/R27 knowledge and the proposed CI/CD and Kubernetes plan.

The Git checkout at the commit above is the source authority. The supplied ZIP is supporting inspection evidence only and does not contain the repository's main `.git` history.

This document is not a replacement for source code, source-controlled SQL, the schema workbench, the metadata migration workbench or deployment audit records. Where documentation and executable source disagree, the executable source must be reviewed and the documentation corrected before promotion.

## 2. Non-negotiable CymBuild architecture

The approved runtime flow remains:

```text
Blazor PWA -> API_Client/FormHelper -> gRPC API -> EF/repository -> SQL Server
```

The following requirements remain mandatory:

- The PWA must not call SQL Server, Sage, other external systems or arbitrary application APIs directly.
- Business logic must not be placed in Razor/UI components.
- Every major entity insert must atomically create its matching `SCore.DataObjects` row with the stable Guid, EntityTypeId, RowStatus and concurrency values.
- Insert-then-update identity patterns are prohibited.
- Business workflow status must never be updated directly. Use `SCore.DataObjectTransitionUpsert`; the latest transition is the current state.
- Integration events must be written through `SCore.IntegrationOutbox` and processed by controlled workers/services.
- Schema is source-controlled SQL. Metadata is source-controlled and deployed through the governed run-based SMigration process. Databases are deployment targets only.
- No manual production database promotion, direct metadata edits or migrations during API startup.
- SQL must be idempotent, schema-qualified and explicit. Do not use `SELECT *`.
- Active-row filtered indexes use the exact predicate `WHERE [RowStatus] <> 0 AND [RowStatus] <> 254`.
- Metadata-driven UI remains the default. Prefer `V2FormRenderer`, `V2FieldEditor` and `FilteredDynamicGridViewV2`; do not introduce new Telerik dependencies unless explicitly approved.

These are approved platform requirements. The inspected source did not identify an intentional replacement for them. Any implementation exception found during full analysis must be treated as a defect or formally reviewed deviation rather than silently normalised.

## 3. Source state versus deployed state

Two different baselines must be retained:

| Baseline | Position |
|---|---|
| Current source-controlled schema bootstrap | CYB-361 R39 (`Initialize-CymBuildSchemaMigration.ps1`) |
| Current source-controlled schema deployment runner | CYB-361 R40 (`Invoke-CymBuildSchemaDeployment.ps1`) |
| Last independently verified shared-environment deployment baseline | CymBuild 26.3 / CYB-361 R27, unless later deployment evidence is supplied |

The presence of R39/R40 source does not prove that those revisions have already been deployed successfully to QA, UAT or LIVE. The first shared-environment CI/CD rehearsal must therefore prove the R40 upgrade path from the actual target state and retain the comparison, plan, source hashes, execution logs and verification evidence.

Historical run Guids are audit evidence only. They must never be reused for a new deployment.

## 4. Current schema migration tooling

### 4.1 R39 persistent exclusions

R39 introduces source-authoritative, persistent schema exclusions. The exclusion policy propagates through the controlled chain:

```text
DEV source -> QA target -> UAT target -> LIVE target
```

The policy includes exclusion and unexclude tombstones. Excluded objects are omitted from comparison, selection, validation, accepted plans and `SMigration.SchemaDeploymentPlan_Get`.

Every exclusion record must have its matching `SCore.DataObjects` row. Unexclude is a soft delete through `SCore.DeleteDataObject`; re-exclusion reactivates the stable record rather than creating a duplicate.

Authoritative documentation: `tools/SchemaDeployment/SchemaExclusions.md`.

### 4.2 R40 constraint deployment

R40 makes foreign key, check, default, primary-key and unique constraints first-class governed schema objects.

The accepted plan contains a `CYB_CONSTRAINT_V2` declarative snapshot, not captured executable DDL. Generated source files are written beneath:

```text
Database/CymBuild_DB/Schema/Constraints
```

Changed constraints use three controlled phases:

1. `*.prepare.sql` - remove the target constraint before dependent structural work.
2. `*.preflight.sql` - perform read-only shape and data viability checks.
3. `*.sql` - recreate the accepted source definition after non-constraint work.

Foreign-key and check constraints use the documented `WITH NOCHECK` historical-data policy. Primary-key and unique constraints require successful read-only NULL/duplicate preflight because SQL Server cannot create them with `WITH NOCHECK`.

Target-only constraint removal is destructive-risk and is never part of the default plan. It requires explicit selection, validation and acceptance.

Authoritative documentation: `tools/SchemaDeployment/ConstraintDeployment.md`.

### 4.3 Source materialisation and promotion

The R40 dry run can materialise missing canonical source SQL for supported programmable objects and constraints from the accepted declarative snapshot. If an apply attempt creates new canonical files, no target deployment starts; the files must be reviewed, committed and dry-run again.

Later-environment promotion must use committed immutable repository files and `-SkipSourceMaterialization` so QA/UAT/LIVE cannot create new release source during deployment.

### 4.4 Still unsupported without dedicated source-controlled handling

- Existing table, table type or sequence changes without a reviewed migration.
- Standalone index changes without a dedicated migration or approved future extractor.
- Any dedicated migration whose approved source hash no longer matches the staged comparison.
- Any constraint whose accepted definition is not valid `CYB_CONSTRAINT_V2`.

## 5. Sage integration correction

### 5.1 Active integration

CymBuild must never call Sage directly. The active external Sage integration boundary is the approved **Sage Wrapper service**.

The current API source contains a dedicated HTTP gateway for the Sage REST wrapper:

```text
services/Concursus.API/Services/Finance/SageSalesOrderGateway.cs
```

The current orchestration service explicitly describes approved transaction submission to the Sage REST wrapper:

```text
services/Concursus.API/Services/Finance/TransactionToSageSubmissionService.cs
```

CymBuild remains responsible for deterministic payload creation, eligibility checks, idempotency, claim handling, success/failure persistence, audit and controlled retries. The Wrapper owns the external Sage-facing service boundary.

### 5.2 Retained but not deployed

The following source is retained for history/reference and must not be included in the current CymBuild image matrix, Kubernetes manifests or environment rollout:

- `services/Sage200Microservice/`
- `services/SageAPI_TEMP_DISABLED/`

The Sage Wrapper is an external dependency unless ownership and source-control evidence later proves that this CymBuild repository is responsible for deploying it.

## 6. Runtime and project classification

The main solution currently includes 21 real projects: 13 production projects and 8 test projects. The approved build inventory must be explicit rather than assuming every `.csproj` in the repository is deployed.

Current target-framework position:

- Main CymBuild, Outlook and test projects: `.NET 10`.
- `PostCodeLookup`: `.NET 9`; it already has a separate delivery path and is treated as an external/separately delivered dependency unless formally brought into this pipeline.
- `Sage200Microservice.*`: `.NET 9`; retained but excluded from the current active build/deployment scope.

Files outside the principal solution are not automatically defects. Architecture tests should validate the approved component inventory and deployment boundaries, not require inactive or independently delivered projects to be added to `CymBuild.Monorepo.sln`.

## 7. Database and module observations

The current source contains substantial `SAi`, `SCrm`, `SOffice`, `SAlert` and `SMonitor` schema areas in addition to the established core, job, finance, SOP, product and UI schemas.

These areas must remain governed by the same DataObjects, workflow, source-controlled SQL and metadata rules. New feature depth does not create an exception to the platform architecture.

### 7.1 SOffice migration-history table

`Database/CymBuild_DB/Schema/Tables/SOffice.__EFMigrationsHistory.sql` proves that EF migration history exists in the source-controlled schema. It does not prove that automatic EF migration remains an approved deployment mechanism.

No `Database.Migrate()` or `MigrateAsync()` call was found in the active Outlook source during this reconciliation. Therefore:

- SOffice schema remains under the controlled source-SQL deployment process.
- Do not introduce automatic EF migrations at API/worker startup.
- Treat `SOffice.__EFMigrationsHistory` as historical/compatibility state unless a formal exception is approved.
- Any remaining standalone Outlook SQL or migration mechanism must be inventoried and reconciled into the governed deployment process.

The inactive Sage200Microservice contains `Database.MigrateAsync()` in its own data seeder. This does not affect the current deployment because that service is explicitly excluded, but it must not be copied into active CymBuild deployment patterns.

## 8. Test baseline

The repository now contains eight solution-wired test projects, including architecture tests, database integration tests and focused tests for shared, EF, API Client, UI component and API behaviour.

This is material progress from the earlier two-project test baseline. It does not remove the need to confirm the full build/test result at this exact commit or to add the remaining migration, container, Kubernetes and end-to-end coverage required by the CI/CD plan.

The immediate CI/CD baseline must capture:

- `dotnet restore` and Release build result for the authoritative solution.
- All test results, including SQL integration evidence.
- Existing warnings/failures clearly separated from CI/CD-introduced regressions.
- Architecture boundary, DataObjects, workflow transition and outbox idempotency gates.
- Schema/metadata idempotency and repeated-apply tests.

## 9. Source hygiene and security

Before the repository is connected to a shared runner, complete a controlled WP1 review for:

- credentials, API keys, certificates, PFX files and client-side secrets;
- `.env` files and nested repository metadata;
- generated `bin`, `obj`, `.vs`, TestResults and deployment artifacts;
- `_patch_backups` and other material that must not enter Docker build contexts;
- placeholder Docker/Kubernetes files and deployment scripts retained by inactive services;
- duplicate root project/stub files whose purpose is not part of the approved build.

Deleting a secret from the current file is not sufficient where it has been exposed. The credential/certificate must be rotated through the owning platform process.

No source-hygiene action may remove active behaviour or historical evidence without an approved retention decision. Use `.gitignore`, `.dockerignore`, repository history controls and explicit archival rather than ad hoc deletion.

## 10. Documentation drift resolved by this baseline

This reconciliation establishes the following corrections:

- The exact branch is `feature/SB_Kubenetes`, not the informal `SB_kubenetes` label.
- The exact source commit is `1b6061621b4c25731955979b0085a3e0928fdacb`.
- The active schema source is R39 bootstrap plus R40 runner, not R38.
- R27 remains the last independently verified deployed baseline until newer deployment evidence is supplied.
- The active Sage integration is the Wrapper service, not Sage200Microservice.
- The legacy Sage projects remain in source but are excluded from current deployment.
- SOffice is not granted an automatic EF-migration exception.
- Pipeline stages numbered 0 through 14 total 15 stages.

## 11. Open decisions that still gate implementation

The following decisions remain open and must be assigned to named owners:

1. Confirm whether R39/R40 has been executed successfully against any shared environment and obtain the run evidence.
2. Confirm the approved Kubernetes packaging/deployment standard: Kustomize, Helm, Rancher Fleet or another controlled mechanism.
3. Confirm Bitbucket runner operating system, network routes, registry trust and least-privilege Kubernetes credentials.
4. Confirm namespace names, Rancher projects and RBAC boundaries for QA, UAT and LIVE.
5. Confirm the approved Secret mechanism and rotation ownership.
6. Confirm SQL authentication/networking for schema and metadata Jobs.
7. Complete API-hosted-worker inventory and decide which workers become independent Deployments before API scaling.
8. Confirm the PWA hosting, authentication redirect and service-worker cache model.
9. Confirm Kafka topics, users, ACLs, authentication and operational ownership.
10. Confirm Ingress/KEMP/DNS/TLS ownership and host/path design.
11. Confirm observability endpoints, dashboard ownership and alert routing.
12. Confirm UAT/LIVE approvals, rollback compatibility rules and emergency recovery ownership.

## 12. WP0 exit position

WP0 is complete only when:

- this baseline is committed against the identified branch/commit lineage;
- the schema README and CI/CD plan are reconciled to R39/R40 and the Sage Wrapper;
- the root analysis draft is archived/removed from the working tree without losing content;
- the exact build/test result for the commit is retained;
- R40 shared-environment deployment evidence is either supplied or explicitly recorded as not yet proven;
- the component inventory and worker-concurrency decisions are accepted.

The next engineering work package is runtime classification and safe worker decomposition. Production Dockerfiles and Kubernetes scaling must not be finalised before that decision prevents duplicate invoice, outbox or Sage submission processing.
