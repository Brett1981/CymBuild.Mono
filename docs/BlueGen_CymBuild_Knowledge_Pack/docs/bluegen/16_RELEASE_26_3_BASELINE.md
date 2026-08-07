# CymBuild 26.3 Release Baseline

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

## Verified architecture

```text
Blazor PWA → FormHelper → gRPC API → EF/repository → SQL Server
```

No direct UI API/DB calls and no business logic in UI.

## Schema Migration — CYB-361/CYB-362

The 26.3 Schema Migration workbench persists comparison, selection, validation, acceptance and audit in `SMigration`. List/filter and selection gRPC payloads are lightweight. Full definitions load only for a selected object.

The browser does not deploy. R27 external runner:

- reads the accepted `SchemaDeploymentPlan_Get` plan;
- defaults to dry-run;
- applies only source-controlled SQL;
- handles selected-only/default-all behavior;
- runs pre/post deployment lifecycle;
- supports guarded table alterations and schema-bound dependency lifecycle;
- writes DataObjects-compliant audit;
- blocks LIVE-like targets without `-AllowLive`;
- allows explicit failed-run retry.

Verified QA evidence on 4 August 2026:

```text
Run: B92EC354-5517-4DA3-9FFE-CBC40455ABFA
ReleaseReference: 26.3
Plan rows: 6
Supported rows: 6
Unsupported rows: 0
Final status: DeploymentApplied
```

The run GUID is historical evidence and must not be reused for another target/release.

## Metadata Migration

The main process is SMigration run-based and OnBoarding-aligned:

```text
Create Run → Stage → Validate → Build Identity Map
→ Review / Ignore / Override → Select Records
→ Apply Preview → Apply Selected or All Valid → Audit
```

Manifests remain ValidateOnly/governance support, especially for grids.

## Current strategic UI direction

Prefer metadata-driven V2 components and no new Telerik unless explicitly requested. Preserve current routes and full behavior during conversions.

## Integration direction

Use `SCore.IntegrationOutbox` and controlled workers/microservices. CymBuild never calls Sage directly.

## Known source snapshot discrepancy

The uploaded repository snapshot contains older `PWAVersion`/`EFVersion` values in some `appsettings*.json` files. Those configuration files were outside this documentation ZIP and were not changed. The release label in this pack follows the user-confirmed 26.3 baseline and the verified R27 26.3 deployment evidence. Release packaging should separately reconcile runtime version configuration before promotion. The same applies to the canonical stylesheet naming: current instructions refer to `Concursus.Components.Shared.wwwroot.css.Cymbuild_ui.css`, while the supplied snapshot contains `libs/Concursus.Components.Shared/wwwroot/css/cymbuild-v2.css`.

## Future work, not yet implemented

The proposed Run Deployment button remains Phase 2. It must enqueue work for a controlled worker/service account rather than execute SQL from a browser session.
