# Jira Implementation History

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.


This file gives BlueGen memory of important CymBuild Jira work. It should be updated after each resolved Jira.

## CYB-101 — WorkflowGetNextStatus

### Problem
Workflow next-status dropdowns needed to respect business rules and avoid invalid statuses.

### Key rules
- Latest transition is current state.
- Use workflow metadata.
- Super User override may expose all transitions if explicitly required.
- Hide invalid sent/accepted-style statuses where there are no active quote items.

### BlueGen guidance
Do not fix next-status issues in the UI. Diagnose `DataObjects`, current transition, workflow status, transitions, and dropdown source.

## CYB-197 — Sage inbound document status

### Problem
Inbound Sage processing could fail where no active Sage inbound document status row existed for a CymBuild document GUID.

### BlueGen guidance
Check source CymBuild document, active status row, integration state, worker state, and idempotency. Existing failed messages may require replay after code deployment.

## CYB-222 — Outlook publish prompt

### Problem
Add optional prompt on compose/forward/send to remind users to publish emails to CymBuild.

### Key rules
- Feature toggle controls behaviour.
- Existing behaviour unchanged by default.
- Confirm action should open filing/publish panel.
- Decline should continue without filing.

## CYB-225 — Outlook filing visibility

### Problem
Users needed clearer visibility of incoming/outgoing email and selected folder before confirmation.

### Key rules
- Preserve filing behaviour.
- Show selected folder/path before confirm.
- Do not hard-code SharePoint business rules in UI.

## CYB-270 — Invoice schedule amount calculation

### Problem
Invoice Schedule amount displayed incorrectly because logic used a single column for all trigger types.

### Key rule
Amount/value must be derived according to schedule type: monthly, percentage, or activity/milestone.

## CYB-287 — RIBA stage support for invoice schedules

### Problem
Monthly and percentage invoice schedules needed optional RIBA stage support.

### Key rules
- RIBA stage optional.
- Existing schedules continue unchanged.
- Schedule-generated invoice requests/items should carry stage attribution where configured.
- Fee drawdown should support stage-level attribution.

## CYB-339 — BRAC quote/job fee carry-through

### Problem
Quote item net/stage information needed to carry into job fee drawdown correctly.

### Key rules
- User-created/custom RIBA stages must be supported.
- Avoid hard-coded RIBA0–RIBA7 assumptions where dynamic stages exist.
- Fee grid should report agreed, invoiced, paid, and remaining accurately.

## CYB-340 — Data and security classifications

### Problem
Add Data Classification and Security Classification to project-related records.

### Key rules
- Fields apply to Quotes, Jobs, and Client Projects.
- Quote selections can flow to Job and Client Project.
- Dropdowns should be metadata-driven.
- Existing records must continue working.

## Future update template

```text
## CYB-000 — Title

### Problem

### Root cause

### Changed files / SQL objects

### Metadata changes

### Final behaviour

### Testing notes

### Known limitations

### BlueGen guidance
```

## CYB-361 / CYB-362 — Schema and Metadata Migration Workbenches (26.3)

### Final 26.3 behavior

- Schema and metadata migration use persistent `SMigration` runs.
- Schema selection is lightweight and persistent; no explicit selection means all deployable differences.
- Schema validation operates on the selected/default deployment plan.
- The workbench records acceptance but does not execute browser DDL.
- `Invoke-CymBuildSchemaDeployment.ps1` R27 consumes the accepted plan outside CymBuild under controlled permissions.
- The runner uses source-controlled SQL only, runs `SCore.PreDeploymentScript` and `SCore.PostDeploymentScript`, writes DataObjects-compliant audit, blocks LIVE-like targets without explicit authorization, and supports explicit failed-run retry.
- R27 dynamically preserves approved nullability-change dependencies while retaining strict guards for unsupported schema-bound or specialist objects.
- Metadata migration follows Create Run → Stage → Validate → Identity Map → Review/Ignore/Override → Selection → Apply Preview → Apply → Audit.
- Metadata manifests remain ValidateOnly/governance support rather than the sole migration engine.

### Verified deployment

The 26.3 QA run `B92EC354-5517-4DA3-9FFE-CBC40455ABFA` completed with six supported objects and status `DeploymentApplied` using R27. This is release evidence, not a reusable run GUID for other environments.

### BlueGen guidance

Do not recommend direct production fixes, manual metadata promotion, browser DDL, captured source-database DDL, or `-AllowPartial` when a complete accepted plan is intended.
