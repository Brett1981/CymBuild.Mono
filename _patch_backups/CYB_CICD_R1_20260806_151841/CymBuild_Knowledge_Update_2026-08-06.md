# CymBuild Knowledge Base — Delta Update

> **Compares against:** `BlueGen_CymBuild_Knowledge_Pack_26.3-r27.txt` (release 26.3-r27, validated 4 Aug 2026) — already in this project's knowledge.
> **New source:** `CymBuild_Monorepo.zip`, uploaded 6 Aug 2026 — 7,657 files, ~1.4GB uncompressed, no `.git` history included in the archive.
> **Analysis date:** 6 August 2026.
> **Method:** targeted structural analysis — solution file, full database schema inventory, the `_patch_backups` history, and the team's own Aug 5–6 planning documents — rather than line-by-line reading of all ~191,000 lines of source (that figure is the repo's own, from its test-strategy doc, not independently recomputed here). Object/project counts below that are presented as exact were generated directly from the extracted archive. Version framing like "R38" or "R40" is drawn from script docstrings and doc text — strong evidence, but not a git-verified diff, since no commit history was available.

## How to use this document

This is a **delta**, not a replacement. Section 1 confirms what's still true from the R27 baseline. Everything else is new or changed since 4 August 2026. I don't have persistent memory enabled on this account, and the project knowledge files are read-only from my side, so I can't push this into either automatically — add it to the project's knowledge base yourself (or feed it back through whatever pipeline produced the existing pack) to make it stick.

One thing deliberately left out: the archive also contained `bluegen-connection.md`, which documents how your internal BlueGen tool authenticates to its own hosted chat API. That's a pipeline/tooling concern, not CymBuild application knowledge, so it isn't covered below.

---

## 1. Still accurate — confirmed unchanged

No exceptions were found to any of these:

- Mandatory runtime flow: `UI → FormHelper → gRPC API → EF → SQL`.
- Every major entity insert atomically creates its `SCore.DataObjects` row; no insert-then-update identity pattern.
- Status is never updated directly — always `SCore.DataObjectTransitionUpsert`; latest transition is current state.
- Active-row filter convention: `RowStatus <> 0 AND RowStatus <> 254`.
- CymBuild never calls Sage directly — always through the controlled microservice/outbox boundary.
- Metadata migration is run-based (`Create Run → Stage → Validate → Build Identity Map → Review/Ignore/Override → Select Records → Apply Preview → Apply → Audit`); manifests remain ValidateOnly/governance support (still only the `grids` family — see §7.4).
- Environment naming: `DEV → QA → UAT → LIVE`.
- Current UI direction: prefer `V2FormRenderer`, `V2FieldEditor`, `FilteredDynamicGridViewV2`; no new Telerik.

---

## 2. Headline change: schema/metadata tooling has moved from R27 to R40

The `_patch_backups/` folder (timestamped session snapshots, not literal migration files) shows continuous iteration from `CYB361_R22` through `CYB361_R40` between 3–5 August, plus a separate `CYB_TEST_R0`–`R4D` track on 5–6 August for test-infrastructure work.

Concretely, in the live source:

- `tools/SchemaDeployment/Initialize-CymBuildSchemaMigration.ps1` is now the **"CYB-361 R39 controlled Schema Migration workbench and exclusion-policy bootstrap runner."**
- `tools/SchemaDeployment/Invoke-CymBuildSchemaDeployment.ps1` is now the **"CYB-361 R40 manual schema deployment runner."**
- **`tools/SchemaDeployment/README.md` still titles itself "(R27)"** — this is now stale documentation; the constraint-handling section it describes ("standalone constraints and indexes without a dedicated migration" = unsupported) has been superseded by R40 (see next point). Worth fixing before anyone relies on it.

### 2.1 R39 — persistent schema exclusions (new)

`tools/SchemaDeployment/SchemaExclusions.md` documents a new persistent exclusion policy for the schema workbench:

- Exclusions are recorded **source-first** and propagate down the environment chain (`DEV source → QA target → UAT target → LIVE target`) on every subsequent Run Compare, including "unexclude" tombstones.
- Excluded objects are omitted from comparisons, selections, validation, and the accepted plan consumed by `SMigration.SchemaDeploymentPlan_Get`.
- New procs: `SMigration.Schema_ExcludedObjects`, `SMigration.SchemaExcludedObject_Apply`, `SMigration.SchemaExcludedObjects_List`.
- Every exclusion row gets a matching `SCore.DataObjects` row; unexclude is a soft delete via `SCore.DeleteDataObject`, and re-excluding reactivates rather than duplicates.

### 2.2 R40 — constraints become first-class deployable objects (new)

`tools/SchemaDeployment/ConstraintDeployment.md` (new file) documents that FK, check, default, primary-key, and unique constraints are now deployed through the same governed plan as other schema objects, using a new **`CYB_CONSTRAINT_V2`** declarative snapshot format (not raw DDL). Key rules:

- A changed constraint splits into three phases: `*.prepare.sql` (drop before structural deployment) → `*.preflight.sql` (validate without changing data) → `*.sql` (recreate after non-constraint objects complete). FKs prepare before key constraints; PK/unique constraints recreate before FKs.
- FK/check constraints are added `WITH NOCHECK` — existing rows aren't retroactively validated. PK/unique constraints cannot use `WITH NOCHECK`; a read-only preflight blocks creation if NULL/duplicate key data exists.
- A target-only constraint is flagged destructive-risk and is **never** in the default plan — removal needs explicit selection, validation, and acceptance.
- Generated files land under `Database/CymBuild_DB/Schema/Constraints` and must be reviewed/committed before promotion; later environments should run with source materialization disabled so they consume only committed files.
- A plan with an old-format constraint definition now throws: *"Constraint definition is not in the CYB_CONSTRAINT_V2 declarative format. Run Stage & Compare again with the R40 API before accepting the plan."*

### 2.3 Where the new CI/CD plan disagrees with the live code

The new CI/CD plan (§3 below) states *"the active schema runner identified in prior analysis is the R38 implementation."* The source in this snapshot is already at **R40**. This is worth flagging to whoever owns that plan — it was already one step behind the code the day it was written, which is a useful signal about how fast this area is moving relative to planning docs.

---

## 3. New: a full CI/CD & Kubernetes delivery plan (proposed, not yet built)

New file: `docs/CymBuild_Final_Proposed_CICD_and_Kubernetes_Plan_2026-08-06.docx`, dated today, status *"Proposed final plan... executable once the decision register is closed."* This is the single biggest new artifact in this snapshot and materially extends any future answer to "what's the CymBuild development/deployment process."

**Delivery platform:** Bitbucket Pipelines → private registry (`docker.socotec.co.uk`) → Rancher-managed RKE2. Local dev standard: Podman for image build/run, Hyper-V Minikube (containerd) for Kubernetes validation.

**Physical environment mapping** (new — previously only logical DEV/QA/UAT/LIVE names were documented):

| Environment | Physical platform | Cluster |
|---|---|---|
| DEV | Local developer workstation | Podman + Hyper-V Minikube/containerd |
| QA | Shared platform DEV | Rancher `soc-rke2-c0` |
| UAT | Shared UAT platform | Rancher `soc-rke2-c2` |
| LIVE | Shared production platform | Rancher `soc-rke2-c1` |

**Core principle:** build once, promote the same immutable image digest through QA → UAT → LIVE; never rebuild per environment; never use `latest` tags.

**Proposed 14-stage pipeline** (condensed — see the source docx for full detail): (0) trigger/ReleaseId → (1) source & architecture validation → (2) restore/compile/static analysis → (3) automated tests → (4) build immutable images → (5) supply-chain scan/SBOM → (6) publish to registry → (7) environment preflight → (8) schema preview/acceptance (Validate/WhatIf) → (9) schema apply & verify → (10) metadata stage/validate/accept/apply/verify → (11) deploy workloads → (12) smoke & integration checks → (13) promote same digests → (14) post-deployment audit.

**Schema/metadata deployment sequence** run as pipeline stages or short-lived Kubernetes Jobs, *never* on API startup — matches and formalizes the existing runner/workbench pattern, now with an explicit lock-acquire/lock-release step wrapping the whole sequence.

**12 work packages (WP0–WP11):** baseline/governance freeze → security & source hygiene → runtime/worker classification → production Dockerfiles → Kubernetes base+overlays → Bitbucket pipeline foundation → schema/metadata pipeline integration → QA deploy/smoke automation → observability/runbooks → UAT promotion → LIVE readiness → BAU/continuous improvement.

**Decision register — 22 open unknowns (U01–U22),** each with an owner and a work package it gates. The most consequential for day-to-day development:

- **U01** Authoritative Git repo/branch/commit — unproven, since the archive has no `.git` history.
- **U10** Confirm R38 (their stated baseline) vs the actual current R40 source, and reconcile stale documentation.
- **U12** Worker decomposition — which hosted services stay bundled with the API vs become independent Deployments (directly relevant to Sage/outbox/invoice-automation workers).
- **U13** PWA hosting model, token-expiry handling, redirect URIs.
- **U14** Runtime support matrix — .NET 10 vs .NET 9 (see §6.2 — this is a real, current split, not hypothetical).
- **U04** Kubernetes packaging standard (Kustomize proposed by default, not yet mandated).

**Explicit "don't start with" list:** no broad rewrite, no direct production DB changes, don't copy the existing placeholder Kubernetes files as-is, don't embed secrets, don't run migrations at API startup, don't scale API replicas before hosted-worker concurrency is resolved.

**Known finding carried into the plan:** *"The source archive previously showed secret material, client-side secrets, certificates and generated output that must be removed or rotated before pipeline onboarding."* I did not go hunting through the repo for these myself (and won't reproduce anything of that kind) — this is the team's own documented finding, and WP1 already exists to remediate it. Treat it as an open action item, not a new problem I'm surfacing.

---

## 4. New database subsystems

Current schema totals (counted directly from `Database/CymBuild_DB/Schema/`): **255 tables, 85 views, 388 stored procedures, 311 functions, 3 triggers**, across 13 schemas:

| Schema | Tables | Status |
|---|---:|---|
| `SCore` | 58 | known |
| `SMigration` | 39 | known |
| `SJob` | 39 | known |
| `SFin` | 33 | known |
| `SSop` | 23 | known |
| **`SAi`** | **17** | **new** |
| `SUserInterface` | 15 | known |
| **`SCrm`** | **15** | **new** |
| **`SOffice`** | **11** | **expanded** |
| `dbo` | 2 | known |
| `SProd` | 1 | known |
| **`SMonitor`** | **1** | **new** |
| **`SAlert`** | **1** | **new** |

### 4.1 `SAi` — in-app AI Assistant (new, substantial)

Not a stub — a fully modeled subsystem: `AssistantConversations`, `AssistantMessages`, `AssistantFeedback`, `AssistantBookmarks`, `AssistantUploads`, `AssistantKnowledgeItems`/`...Categories`/`...Tags`/`...Versions`, `AssistantContentGaps`, `AssistantAnalyticsEvents`, `AssistantPlaybooks`/`...Steps`, and `AssistantWorkflowTemplates`/`...Runs`/`...RunSteps` — plus a `vw_AssistantAdminDashboard` view. It has its own gRPC contract (`services/Concursus.API/Protos/assistant_v1.proto`) and its own FormHelper test coverage (`AIAssistantUploadFormHelperTests`).

Notably, several procs (`SAi.Assistant_EnsureGridDefinition`, `...EnsureGridViewDefinition`, `...EnsureGridColumn`, `...EnsureLanguageLabel`, `...EnsureEntityType`) let the assistant idempotently create/ensure its *own* UI metadata — i.e., this feature can provision CymBuild metadata programmatically, which is a new pattern worth understanding before extending it.

This was listed only as aspirational — *"AI-assisted knowledge/help tooling"* — under "Current Strategic Work" in the R27-era pack. It's now a real, mostly-built subsystem.

This is distinct from `CymBuild_AIErrorServiceAPI` (§5.3), which is an unrelated error-reporting-to-Jira service.

### 4.2 `SCrm` — CRM (new, not previously documented at all)

`Accounts`, `Contacts`, `ContactDetails`, `ContactTitles`, `ContactPositions`, `ContactDetailTypes`, `Addresses`, `AccountAddresses`, `AccountContacts`, `AccountStatus`, `AccountMemos`, `AccountMergeBatch`, `AccountProjectDirectoryRoles`, `Counties`, `Countries`. The R27 pack's module list (Jobs, Enquiries, Quotes, Invoice Schedules, Finance, Sage, SharePoint/Outlook, workflow, dashboards, classifications) should now explicitly include CRM/account management.

### 4.3 `SOffice` — Outlook/Office integration (expanded, with an architectural exception)

`OutlookEmails`, `OutlookEmailConversations`, `OutlookEmailFromAddresses`, `OutlookEmailMailboxes`, `OutlookCalendarEvents`, `OutlookMsalTokenCache` (confirms MSAL/Azure AD-based auth), `TargetObjects`, `DataProtectionKeys`, `Preferences`, `EntityTypes`.

**Worth flagging:** this schema includes `SOffice.__EFMigrationsHistory` — meaning the Outlook/Office tables appear to be managed through standard **EF Core Migrations**, not the platform's `SMigration` schema-comparison mechanism used everywhere else. That's a genuine deviation from the "database is a deployment target only, no direct EF migrations" rule stated for the rest of the platform, and probably deserves an explicit exception note rather than being discovered by accident later.

### 4.4 `SAlert` and `SMonitor` (new, minor)

`SAlert.Notifications` (generic notification table) and `SMonitor.WaitStatsExclusions` (SQL Server wait-stats monitoring exclusion list — DBA/performance tooling, not business data).

---

## 5. New and restructured services

Top-level `services/` now contains: `Concursus.API`, `Sage200Microservice`, `CymBuild_AIErrorServiceAPI`, `PostCodeLookup`, `CymBuild_Outlook_API`, `CymBuild_Outlook_Service`, and `SageAPI_TEMP_DISABLED` (still present, still inactive per the existing pack — see §7.3).

### 5.1 `PostCodeLookup` (new)

Standalone ASP.NET Core service — `Controllers`, `Services`, `DTOs`, `POCO`, `Data/Entities`, and `Integrations/IdealPostcode` (a named external postcode-lookup provider). Has its own `Dockerfile`. Targets **.NET 9**, not .NET 10 (see §6.2).

### 5.2 `Sage200Microservice` — now three projects (was documented as one boundary)

Split into `Sage200Microservice.API`, `Sage200Microservice.Services`, `Sage200Microservice.Data`. All three target **.NET 9**. Only `.API` has a `Dockerfile`.

### 5.3 `CymBuild_AIErrorServiceAPI` (new)

Per its own test coverage, this converts errors into Jira tickets (Markdown-to-ADF conversion, Jira mapping, AI-assisted parsing/retry handling). Has both a `Dockerfile` and a `k8s/deployment.yaml` — i.e., someone has already taken a first pass at containerizing this one, which the CI/CD plan characterizes as placeholder-quality (see §3's secrets caveat — I didn't open these files further).

### 5.4 Outlook subsystem — now five projects (was one integration line item)

`CymBuild_Outlook_Common` (lib), `CymBuild_Outlook` (in `libs/CymBuild_Outlook Manifest/` — looks like the Office add-in manifest/packaging project), `CymBuild_Outlook_Addin` (app), `CymBuild_Outlook_API` (service — `EmailFilingService.cs`, `SharepointHelper.cs`), `CymBuild_Outlook_Service` (service — background `Worker.cs`). This is a much richer breakdown than "SharePoint/Outlook filing" as a single bullet.

### 5.5 `SageAPI_TEMP_DISABLED` still carries deployment scaffolding

Still marked inactive, but it still has its own `Dockerfile` and a `k8s/` folder (`README.md` + `deploy.sh`). Dead code that still ships deployment tooling is exactly the kind of thing WP1 (source hygiene) in the CI/CD plan should sweep up.

---

## 6. Solution and repository structure

### 6.1 Project inventory reconciled against the new test-strategy doc

`CymBuild.Monorepo.sln` currently wires up **21 real projects** (9 other entries are solution folders, not projects): 13 production + **8 test projects** (up from 2 — see §7). Outside the `.sln` entirely: `PostCodeLookup` and all three `Sage200Microservice.*` projects — 4 more production projects that exist in source but aren't part of the authoritative build. 13 + 4 = **17 production projects**, which matches the new `CymBuild_Test_Strategy_2026-08-05.md`'s own count exactly.

### 6.2 Target framework split (confirmed directly in every `.csproj`)

Everything is **.NET 10** — `Concursus.*`, `CymBuild_AIErrorServiceAPI`, the whole Outlook subsystem, and every new test project — **except** `PostCodeLookup` and all three `Sage200Microservice.*` projects, which remain on **.NET 9**. This is real, not hypothetical, and is exactly what the CI/CD plan's U14 unknown is asking to resolve before base images are locked.

### 6.3 Minor repo hygiene notes

- A duplicate `Concursus.Metadata.Tools.csproj` sits at the repo root, separate from the canonical `apps/Concursus.Metadata.Tools/Concursus.Metadata.Tools.csproj` that's actually wired into the solution.
- A stray root-level `Program.cs` (an empty `Class1` stub) doesn't correspond to any real project entry point.
- Neither is harmful, but both are the kind of thing a source-hygiene pass (WP1) would remove.

---

## 7. Test infrastructure: from 2 projects to 8

`CymBuild_Test_Strategy_2026-08-05.md` (new) assessed the repo as having only `apps/Concursus.PWA.Tests` (~41 cases) and `tests/Concursus.API.Tests` (~7 cases) — **32 test methods, ~48 executed cases total** — against ~191k lines of production source, and laid out a prioritized R0–R7 plan to fix that.

As of this snapshot, six new test projects already exist and contain real, substantive tests (not just scaffolding) — this work is clearly already underway, not just planned:

| Project | Covers |
|---|---|
| `CymBuild.Architecture.Tests` | Project-reference boundaries (`PWA → Components.Shared → API.Client`), solution completeness |
| `CymBuild.Database.IntegrationTests` | `SCore.DataObjects` invariants, workflow transitions, `SCore.IntegrationOutbox` persistence, schema contracts |
| `Concursus.EF.Tests` | `GridInternalsComparer`, metadata validation report logic |
| `Concursus.Components.Shared.Tests` | `V2FormRenderer`, `V2FieldEditor`, `V2DropdownLoader`, `ViewDefinitionBuilder` |
| `Concursus.API.Client.Tests` | FormHelper areas incl. `AIAssistantUpload`, `AddressLookup`, `UniversalSearch`, `Documents` |
| `Concursus.Common.Shared.Tests` | Finance read-models, string/collection helpers |

`Concursus.API.Tests` itself grew substantially — new coverage for `TransactionToSageEligibilityValidator`, `TransactionToSageSubmissionService`, `SageInboundPaymentSyncService`, `SageApiOptionsValidator`, invoice automation, and `WorkflowOutboxRepository`.

This maps almost exactly to the R1/R2 priorities in the new test-strategy doc — worth confirming with the team whether this is finished R1/R2 work or still in progress, since some proposed projects (`Concursus.API.IntegrationTests`, `CymBuild.Migration.IntegrationTests`, `SchemaDeployment.Pester`, `CymBuild.EndToEnd.Tests`) don't exist yet.

---

## 8. New workflow/notification/outbox procedures

Beyond the existing `DataObjectTransitionUpsert` pattern, the schema now includes a fuller CRUD surface for workflow *definitions* themselves, plus notification groups and more granular outbox enqueue helpers:

- `SCore.WorkflowUpsert` / `WorkflowDelete`
- `SCore.WorkflowStatusUpsert` / `WorkflowStatusDelete`
- `SCore.WorkflowTransitionUpsert` / `WorkflowTransitionDelete`
- `SCore.WorkflowStatusNotificationGroupsUpsert` / `...Delete` — workflow status changes can now trigger notifications to configured groups.
- `SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification`, `SCore.IntegrationOutbox_EnqueueJobCreatedFromProposal`, `SFin.TransactionBatchTransition_EnqueueOutbox` — more specific, named outbox-enqueue entry points rather than one generic path.

---

## 9. Documentation drift found (worth fixing at the source)

- `tools/SchemaDeployment/README.md` titles itself **"(R27)"** while the script it documents is R40 and the constraint-support section it describes is superseded by `ConstraintDeployment.md`.
- The R27-era knowledge pack itself already flagged a stylesheet naming mismatch (`Concursus.Components.Shared.wwwroot.css.Cymbuild_ui.css` in instructions vs `cymbuild-v2.css` in the actual snapshot) and older `PWAVersion`/`EFVersion` strings in some `appsettings*.json` — both still unresolved as of this snapshot; not re-verified in detail here, just noting they weren't called out as fixed anywhere in the new material.
- The new CI/CD plan's own stated baseline (R38) is already behind the live source (R40) — see §2.3.

---

## 10. Suggested additions to the developer checklist

On top of the existing checklist, this snapshot suggests adding:

- Does a new/changed constraint use the `CYB_CONSTRAINT_V2` format, and has Stage & Compare been re-run under the R40 API before acceptance?
- If touching `SOffice`, does the change need to go through EF Core Migrations instead of `SMigration` — and is that intentional?
- Does a new hosted worker risk duplicate processing if the API scales to multiple replicas (per CI/CD plan §3.1 — no worker should silently ride along on every API replica)?
- If adding a new production project, is it wired into `CymBuild.Monorepo.sln` (four currently aren't)?
- Does the project target the platform-standard **.NET 10**, or does it have a documented reason to stay on .NET 9 (currently only Sage200Microservice and PostCodeLookup do)?

---

## 11. Open questions worth raising with the team

- Confirm whether the exact Bitbucket commit this archive corresponds to is known (U01) — no `.git` history shipped with it, so provenance is currently just "the latest upload."
- Confirm whether R39/R40 have been through any environment deployment yet, or exist only as source + local `_patch_backups` so far — the last *independently verified deployed* baseline the team's own docs cite is still R27.
- Confirm ownership/timeline for the CI/CD plan's 22-item decision register (U01–U22), since several (U10, U12, U13, U14) directly affect how services should be structured going forward.
