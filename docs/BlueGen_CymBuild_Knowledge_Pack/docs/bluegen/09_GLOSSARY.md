# CymBuild Glossary

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

## DataObject
The platform identity row in `SCore.DataObjects` for a business or metadata entity. It must be created atomically at insert with the correct `EntityTypeId`.

## DataObjectTransition
Audited workflow/status transition. The latest active transition is the current state; status is never updated directly.

## EntityType / EntityProperty / EntityPropertyGroup / EntityQuery
Metadata definitions for an entity, its fields, form grouping, and SQL-backed operations/data sources.

## GridDefinition / GridViewDefinition / GridViewColumnDefinition
The parent, view, and column metadata hierarchy. Apply in Grid → View → Columns order.

## FormHelper
The client wrapper layer between Blazor PWA and gRPC. UI components must use it rather than direct API clients.

## Metadata Migration Run
A persistent `SMigration.Metadata_Run` lifecycle that stages, validates, maps identities, records ignores/overrides/selections, previews apply, applies and audits metadata.

## Metadata Manifest
A source-controlled ValidateOnly/governance representation, currently especially important for grid families and allowlists. In 26.3 it is not the sole metadata migration mechanism.

## Identity Map
Cross-environment mapping from staged source GUID/identity context to target records. Missing mappings require review, ignore, or explicit override.

## Schema Migration Run
A persistent comparison, selection, validation, acceptance and audit record in `SMigration.Schema_Run`.

## Deployment Plan
The selected schema differences returned by `SMigration.SchemaDeploymentPlan_Get`. If no explicit selection exists, all deployable differences form the default plan.

## Schema Deployment Runner
`tools/SchemaDeployment/Invoke-CymBuildSchemaDeployment.ps1`. R27 executes accepted plans outside the browser using source-controlled SQL and controlled permissions.

## PreDeploymentScript / PostDeploymentScript
Controlled SQL lifecycle procedures used to suspend and restore schema-bound dependencies/constraints around deployment. Post-deployment is skipped for `CymBuild_Dev` by the R27 runner.

## IntegrationOutbox
`SCore.IntegrationOutbox`, used to queue auditable, idempotent integration events for workers.

## Invoice Schedule
Business intent for future invoice generation.

## InvoiceScheduleTriggerInstances
Idempotent execution ledger for schedule triggers; prevents duplicate automation effects.

## RIBA Stage
Dynamic project/fee stage. Do not assume only hard-coded RIBA0–RIBA7 values.

## Telerik Removal
Migration to shared CymBuild-native/V2 controls while preserving behavior. New Telerik usage requires explicit approval.
