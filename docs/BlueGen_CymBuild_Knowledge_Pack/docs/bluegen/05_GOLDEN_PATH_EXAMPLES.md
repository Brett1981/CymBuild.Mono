# Golden Path Examples

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

## Example 1 — Add a field to an existing entity

```text
Source-controlled schema → Read object → Upsert → EF/API/FormHelper if required
→ SMigration metadata run → Metadata-driven UI
```

1. Inspect the current table/read/upsert schema.
2. Add an idempotent, data-preserving schema migration.
3. Use explicit columns in every changed SQL object.
4. Update upsert/read contracts while preserving backward compatibility.
5. Create the business row and matching `SCore.DataObjects` row atomically when a new entity is involved.
6. Stage and validate the metadata run.
7. Build/review the identity map and save intended selections.
8. Review Apply Preview, then apply selected/all valid rows.
9. Verify PWA behavior through FormHelper.

Never add the field only in Razor, hard-code a metadata-backed control, or make a populated column `NOT NULL` without a guarded migration.

## Example 2 — Add a dropdown field

```text
Lookup/entity query → EntityProperty/DropDown metadata → Read/upsert SQL → V2FieldEditor
```

1. Confirm the lookup source and active filter uses `RowStatus <> 0 AND RowStatus <> 254`.
2. Add or update the dropdown/entity-query metadata.
3. Pass stable GUIDs across environment boundaries and resolve numeric IDs server-side.
4. Keep values and dependency filtering out of Razor.

## Example 3 — Add a grid column

```text
SQL source → GridDefinition → GridViewDefinition → GridViewColumnDefinition
→ FilteredDynamicGridViewV2
```

Add the SQL alias first, then apply metadata in dependency order. Validate duplicates, label, order, width, formatting, visibility, sorting, filtering, and export behavior.

## Example 4 — Add workflow behavior

```text
Workflow metadata → DataObjectTransitionUpsert → latest active transition = current state
```

Confirm the `DataObjects` row and `EntityTypeId`, validate allowed transitions, and use `SCore.DataObjectTransitionUpsert`. Never update an entity status column directly.

## Example 5 — Add an integration event

```text
Business action → IntegrationOutbox → controlled worker/microservice
→ external system → audit/diagnostics/retry
```

Use a stable idempotency key, store diagnostic context, and make retries safe. CymBuild must never call Sage directly; use the controlled Sage microservice boundary.

## Example 6 — Convert Telerik UI

```text
Feature inventory → V2/shared component → FormHelper preserved → parity testing
```

Prefer `V2FormRenderer`, `V2FieldEditor`, `FilteredDynamicGridViewV2`, and existing V2 diagnostics/grid patterns. Preserve filters, sorting, paging, export, buttons, row actions, modals, validation, loading/empty/error states, accessibility, and security.

## Example 7 — Promote a schema difference

```text
PWA workbench → FormHelper → gRPC → SMigration persistent plan
→ external R27 runner → source-controlled SQL → audit
```

1. Create and compare a schema run.
2. Save explicit selections, or intentionally use all deployable rows by default.
3. Validate the selected/default plan.
4. Accept the reviewed run.
5. Execute `-WhatIf` outside the browser under a controlled account.
6. Resolve every unsupported item with source-controlled SQL or remove it from the accepted selection.
7. Run `-Apply` without `-AllowPartial` for a complete plan.
8. Verify `PreDeploymentScript`, object deployment, `PostDeploymentScript`, execution log and final run status.

Never deploy captured source-database DDL or grant browser sessions DDL permissions.
